package com.weijx.fzu_assistant;

import android.accessibilityservice.AccessibilityService;
import android.accessibilityservice.AccessibilityServiceInfo;
import android.app.Activity;
import android.app.Instrumentation;
import android.app.UiAutomation;
import android.app.UiModeManager;
import android.app.WallpaperManager;
import android.appwidget.AppWidgetHost;
import android.appwidget.AppWidgetHostView;
import android.appwidget.AppWidgetManager;
import android.appwidget.AppWidgetProviderInfo;
import android.content.ComponentName;
import android.content.Context;
import android.content.ContextWrapper;
import android.content.SharedPreferences;
import android.content.res.Configuration;
import android.content.res.ColorStateList;
import android.graphics.Bitmap;
import android.graphics.BitmapFactory;
import android.graphics.Canvas;
import android.graphics.Color;
import android.graphics.Paint;
import android.graphics.PorterDuff;
import android.graphics.PorterDuffColorFilter;
import android.graphics.Rect;
import android.graphics.drawable.BitmapDrawable;
import android.os.Build;
import android.os.Bundle;
import android.os.ParcelFileDescriptor;
import android.os.SystemClock;
import android.provider.Settings;
import android.util.SparseIntArray;
import android.util.SizeF;
import android.util.Log;
import android.view.View;
import android.view.InputDevice;
import android.view.MotionEvent;
import android.view.accessibility.AccessibilityNodeInfo;
import android.widget.ImageView;
import android.widget.RemoteViews;
import android.widget.TextView;
import java.io.ByteArrayOutputStream;
import java.io.File;
import java.io.FileInputStream;
import java.io.FileOutputStream;
import java.io.InputStream;
import java.nio.charset.StandardCharsets;
import java.security.MessageDigest;
import java.util.ArrayList;
import java.util.Arrays;
import java.util.Calendar;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Locale;
import java.util.Map;
import java.util.Objects;
import java.util.TimeZone;
import java.util.UUID;
import java.util.concurrent.Callable;
import java.util.concurrent.atomic.AtomicReference;
import org.json.JSONArray;
import org.json.JSONObject;

/**
 * Emulator-only, real AppWidgetHost / Pixel Launcher / wallpaper integration.
 *
 * Use the existing runner; no test dependencies, extra runner or production permissions:
 * adb -s emulator-5554 shell am instrument -w \
 *   -e suite widgetColors -e emulatorOnly true \
 *   -e wallpaperA /data/local/tmp/fzu-widget-wallpaper-a.jpg \
 *   -e wallpaperB /data/local/tmp/fzu-widget-wallpaper-b.jpg \
 *   -e launcherIds 4,5,6 \
 *   com.weijx.fzu_assistant.dev.test/com.weijx.fzu_assistant.CalendarSyncInstrumentation
 *
 * launcherIds are compact,square,timetable, already on Launcher home-screen pages.
 * At most six pages are scanned for each real-wallpaper/mode capture.
 * The parent pushes the supplied images. Images never become repository assets.
 * Every asynchronous condition has a 30-second deadline; a timeout is a failure,
 * including when a fixed system palette prevents wallpaper-derived accent changes.
 *
 * Two independent checks are deliberately reported separately:
 *  - a real bound host retains the ORIGINAL RemoteViews, then setColorResources
 *    reinflates its masks A -> B -> A without publishing fresh RemoteViews;
 *  - actual wallpaper / night-mode changes must recolor the existing Launcher
 *    widgets. No refresh, updateAll, launcher restart or color setter is sent to
 *    Launcher between those captures.
 */
final class WidgetColorsRuntimeTest {
    private static final long TIMEOUT_MS = 30_000;
    private static final String LOG_TAG = "FzuWidgetColorsQA";
    private static final int MAX_IMAGE_BYTES = 32 * 1024 * 1024;
    private static final String WALLPAPER_A = "/data/local/tmp/fzu-widget-wallpaper-a.jpg";
    private static final String WALLPAPER_B = "/data/local/tmp/fzu-widget-wallpaper-b.jpg";
    private static final String OVERLAY_SETTING = "theme_customization_overlay_packages";
    private static final String[] VARIANTS = {"compact", "square", "timetable"};
    private static final int[] WIDTHS = {220, 210, 360};
    private static final int[] HEIGHTS = {92, 210, 360};
    private static final int[] TONES = {0, 10, 50, 100, 200, 300, 400, 500, 600, 700, 800, 900, 1000};
    private static final String[] FAMILIES = {"accent1", "accent2", "accent3", "neutral1", "neutral2"};

    private final Instrumentation instrumentation;
    private final Bundle arguments;
    private final JSONObject result = new JSONObject();
    private final JSONArray stages = new JSONArray();
    private final List<String> cleanupFailures = new ArrayList<>();
    private final int[] ids = new int[3];
    private final RecordingHostView[] views = new RecordingHostView[3];
    private final List<Bitmap> images = new ArrayList<>();
    private Context target;
    private Context isolated;
    private UiAutomation automation;
    private WallpaperManager wallpapers;
    private UiModeManager uiMode;
    private AppWidgetManager manager;
    private AppWidgetHost host;
    private File artifacts;
    private File homeBackup;
    private File lockBackup;
    private String preferencePrefix;
    private SharedPreferences livePreferences;
    private String oldSnapshot;
    private boolean hadSnapshot;
    private boolean snapshotTouched;
    private boolean wallpaperTouched;
    private boolean modeTouched;
    private boolean launcherTouched;
    private boolean permissionAdopted;
    private boolean hostOwned;
    private int originalNightMode = -1;
    private int originalNightConfiguration;
    private String originalOverlay;
    private Palette originalPalette;
    private int[] launcherIds;
    private int assertions;
    private int failureAssertionNumber;
    private String lastAssertion;
    private String failureAssertion;
    private String currentStage = "preflight";

    WidgetColorsRuntimeTest(Instrumentation instrumentation, Bundle arguments) {
        this.instrumentation = instrumentation;
        this.arguments = arguments;
    }

    void run() {
        Throwable failure = null;
        try {
            prepare();
            exercise();
        } catch (Throwable error) {
            failure = error;
            failureAssertionNumber = assertions;
            failureAssertion = lastAssertion;
            Log.e(LOG_TAG, "stage=" + currentStage + ", assertion=" + assertions +
                ", check=" + lastAssertion, error);
            if (target != null) {
                try {
                    Palette fresh = Palette.read(target);
                    Palette application = new Palette(target);
                    result.put("failureResourceObservation", new JSONObject()
                        .put("fresh", fresh.json()).put("application", application.json())
                        .put("applicationMatchesFresh", application.sameSystemColors(fresh))
                        .put("applicationDifferences", fresh.differences(application)));
                } catch (Throwable diagnosticError) {
                    Log.e(LOG_TAG, "Cannot record pre-cleanup resource diagnostics", diagnosticError);
                }
            }
            if (automation != null && artifacts != null) {
                try {
                    Bitmap screen = screenshot();
                    if (screen != null) {
                        try { save(screen, "failure-screen.png"); } finally { screen.recycle(); }
                    }
                } catch (Exception ignored) {
                    // Preserve the original assertion and still restore state.
                }
            }
        } finally {
            cleanup();
        }
        try {
            result.put("suite", "widgetColors");
            result.put("assertions", assertions);
            result.put("failureAssertionNumber", failureAssertionNumber);
            result.put("failureAssertion", failureAssertion);
            result.put("stages", stages);
            result.put("lastStage", currentStage);
            result.put("cleanup", cleanupFailures.isEmpty());
            result.put("cleanupFailures", new JSONArray(cleanupFailures));
            result.put("passed", failure == null && cleanupFailures.isEmpty());
            if (failure != null) {
                result.put("failure", failure.toString());
                result.put("failureStackTrace", Log.getStackTraceString(failure));
            }
            if (artifacts != null) {
                result.put("artifacts", artifacts.getAbsolutePath());
                write(new File(artifacts, "result.json"),
                    result.toString(2).getBytes(StandardCharsets.UTF_8));
            }
        } catch (Exception error) {
            if (failure == null) failure = error;
            try {
                result.put("passed", false).put("failure", failure.toString())
                    .put("failureStackTrace", Log.getStackTraceString(failure));
            } catch (Exception ignored) {
                // finish() still reports failure if writing the artifact failed.
            }
        }
        Bundle bundle = new Bundle();
        bundle.putInt("tests", 1);
        bundle.putInt("assertions", assertions);
        bundle.putString("widgetColorsJson", result.toString());
        bundle.putString("stream", "\n" +
            (failure == null && cleanupFailures.isEmpty() ? "PASS" : "FAIL") +
            ": widgetColors " + result + "\n");
        instrumentation.finish(failure == null && cleanupFailures.isEmpty()
            ? Activity.RESULT_OK : Activity.RESULT_CANCELED, bundle);
    }

    private void prepare() throws Exception {
        check("true".equals(arguments.getString("emulatorOnly")),
            "Explicit -e emulatorOnly true is required");
        check(Build.VERSION.SDK_INT >= 31, "Wallpaper/host color suite requires Android 12+");
        target = instrumentation.getTargetContext();
        automation = instrumentation.getUiAutomation();
        check("1".equals(shellText("getprop ro.kernel.qemu").trim()),
            "Refusing to mutate wallpaper or widgets on a non-QEMU device");
        check(WALLPAPER_A.equals(arguments.getString("wallpaperA")) &&
            WALLPAPER_B.equals(arguments.getString("wallpaperB")),
            "Pass the fixed /data/local/tmp/fzu-widget-wallpaper-a.jpg and -b.jpg paths");
        launcherIds = parseLauncherIds(arguments.getString("launcherIds"));
        manager = AppWidgetManager.getInstance(target);
        for (int i = 0; i < 3; i++) {
            AppWidgetProviderInfo info = manager.getAppWidgetInfo(launcherIds[i]);
            check(info != null && info.provider.equals(component(i)),
                "launcherIds must identify existing compact,square,timetable widgets");
        }
        automation.adoptShellPermissionIdentity(
            "android.permission.BIND_APPWIDGET",
            "android.permission.SET_WALLPAPER",
            "android.permission.READ_WALLPAPER_INTERNAL",
            "android.permission.MANAGE_EXTERNAL_STORAGE",
            "android.permission.MODIFY_DAY_NIGHT_MODE",
            "android.permission.WRITE_SECURE_SETTINGS");
        permissionAdopted = true;
        wallpapers = WallpaperManager.getInstance(target);
        uiMode = target.getSystemService(UiModeManager.class);
        check(wallpapers.isWallpaperSupported() && wallpapers.isSetWallpaperAllowed(),
            "System wallpaper changes must be allowed on the emulator");
        check(wallpapers.getWallpaperInfo() == null &&
            (Build.VERSION.SDK_INT < 34 ||
                wallpapers.getWallpaperInfo(WallpaperManager.FLAG_LOCK) == null),
            "Use static emulator wallpapers so the original state can be restored");
        originalNightMode = uiMode.getNightMode();
        originalNightConfiguration = target.getResources().getConfiguration().uiMode &
            Configuration.UI_MODE_NIGHT_MASK;
        check(originalNightMode == UiModeManager.MODE_NIGHT_NO ||
            originalNightMode == UiModeManager.MODE_NIGHT_YES ||
            originalNightMode == UiModeManager.MODE_NIGHT_AUTO,
            "Use no/yes/auto night mode; this suite does not replace custom schedules");
        originalOverlay = Settings.Secure.getString(target.getContentResolver(), OVERLAY_SETTING);
        originalPalette = stablePalette();
        result.put("originalPalette", originalPalette.json());
        result.put("originalPaletteAfterPermissionAdoption", true);
        result.put("originalApplicationPalette", new Palette(target).json());

        String nonce = UUID.randomUUID().toString().replace("-", "");
        File external = target.getExternalFilesDir(null);
        check(external != null, "External files directory must be available for PNG artifacts");
        artifacts = new File(external, "widget-colors-" + nonce);
        check(artifacts.mkdir(), "Create a unique artifact directory");
        homeBackup = backupWallpaper(WallpaperManager.FLAG_SYSTEM, "original-home");
        lockBackup = backupWallpaper(WallpaperManager.FLAG_LOCK, "original-lock");
        // Decode both inputs before the first mutation. PFD is a shell pipe;
        // the tested application never needs a storage/read-media permission.
        images.add(readWallpaper(WALLPAPER_A));
        images.add(readWallpaper(WALLPAPER_B));
        check(!digest(images.get(0)).equals(digest(images.get(1))),
            "Wallpaper A and B must contain different pixels");

        preferencePrefix = "widget_colors_qa_" + nonce + "_";
        isolated = new ContextWrapper(target) {
            @Override public SharedPreferences getSharedPreferences(String name, int mode) {
                return target.getSharedPreferences(preferencePrefix + name, mode);
            }
            @Override public Context getApplicationContext() { return this; }
        };
        String snapshot = snapshot();
        check(isolated.getSharedPreferences("next_course_widget", Context.MODE_PRIVATE)
            .edit().putString("snapshot", snapshot).commit(), "Save independent synthetic snapshot");
        livePreferences = target.getSharedPreferences("next_course_widget", Context.MODE_PRIVATE);
        hadSnapshot = livePreferences.contains("snapshot");
        oldSnapshot = livePreferences.getString("snapshot", null);
        // Only this one key is temporarily shared with real receiver callbacks.
        // Flutter preferences, credentials and background-scheduler state are untouched.
        snapshotTouched = true;
        check(livePreferences.edit().putString("snapshot", snapshot).commit(),
            "Temporarily publish the test snapshot for real system callbacks");

        AccessibilityServiceInfo accessibility = automation.getServiceInfo();
        check(accessibility != null, "UiAutomation accessibility connection must be ready");
        accessibility.flags |= AccessibilityServiceInfo.FLAG_REPORT_VIEW_IDS |
            AccessibilityServiceInfo.FLAG_INCLUDE_NOT_IMPORTANT_VIEWS;
        automation.setServiceInfo(accessibility);
        check(automation.performGlobalAction(AccessibilityService.GLOBAL_ACTION_HOME),
            "Show the existing Pixel Launcher home page");
        await("Pixel Launcher home screen", () -> launcherBounds() != null);
        createHost();
    }

    private void exercise() throws Exception {
        phase("wallpaper-A-light");
        setNight(false);
        setWallpaper(0);
        await("Wallpaper A system palette settled", () -> wallpaperColorsReady());
        Palette a = stablePalette();
        onMain(() -> {
            for (int i = 0; i < 3; i++) {
                provider(i).onUpdate(isolated, manager, new int[]{ids[i]});
                // Seed Launcher ONCE. Later wallpaper/mode checks never invoke a
                // provider, updateAll, refresh PendingIntent or launcher color API.
                launcherTouched = true;
                provider(i).onUpdate(isolated, manager, new int[]{launcherIds[i]});
            }
            return null;
        });
        await("Three real host views show the synthetic courses", () -> onMain(() -> {
            for (int i = 0; i < 3; i++) {
                if (views[i].retained == null || !containsFixture(views[i], i)) return false;
            }
            return true;
        }));
        onMain(() -> {
            for (RecordingHostView view : views) view.frozen = true;
            return null;
        });
        captureHost("a-light", a);
        captureLauncher("a-light", a);

        phase("wallpaper-B-light");
        setWallpaper(1);
        await("Wallpaper B changes actual system accent",
            () -> wallpaperColorsReady() &&
                Palette.read(target).systemAccent != a.systemAccent);
        Palette b = stablePalette();
        check(a.primaryContainer != b.primaryContainer &&
            a.secondaryContainer != b.secondaryContainer,
            "The real wallpapers produce distinct primary AND secondary course containers");
        // Launcher is captured before our isolated host receives an explicit
        // color mapping, so the manual host check cannot masquerade as automatic refresh.
        captureLauncher("b-light", b);
        captureHost("b-light", b);

        phase("retained-RemoteViews-A-B-A");
        captureHost("replay-a-light", a);
        captureHost("replay-b-light", b);
        captureHost("replay-a-again-light", a);
        result.put("retainedRemoteViewsRecolored", true);

        phase("wallpaper-B-dark");
        setNight(true);
        Palette bDark = stablePalette();
        check(bDark.background != b.background && bDark.primary != b.primary &&
            bDark.primaryContainer != b.primaryContainer,
            "Night mode switches surface, text and course-container roles");
        captureLauncher("b-dark", bDark);
        captureHost("b-dark", bDark);

        phase("wallpaper-A-dark");
        setWallpaper(0);
        await("Wallpaper A changes system accent again",
            () -> wallpaperColorsReady() &&
                Palette.read(target).systemAccent != b.systemAccent);
        Palette aDark = stablePalette();
        captureLauncher("a-dark", aDark);
        captureHost("a-dark", aDark);

        phase("wallpaper-A-light-again");
        setNight(false);
        Palette aAgain = stablePalette();
        captureLauncher("a-again-light", aAgain);
        captureHost("a-again-light", aAgain);
        check(a.sameSystemColors(aAgain), "Returning A -> B -> A restores the system palette");
        result.put("realWallpaperAccentChanged", true);
        result.put("launcherAutomaticallyRecolored", true);
        result.put("lightDarkSynchronized", true);
    }

    private void createHost() throws Exception {
        // Match a real launcher's cross-package inflation path. RemoteViews
        // reuses the supplied resource Context when its package is the provider
        // package; merely creating another same-package Context still exercises
        // that shortcut. The test APK supplies the host View Context, while the
        // target Context below continues to own the Binder host registration.
        Context hostContext = instrumentation.getContext();
        check(!hostContext.getPackageName().equals(target.getPackageName()),
            "The host View belongs to the separate instrumentation APK");
        check(hostContext.getResources() != target.getResources(),
            "Host and provider Application resources are separate");
        result.put("hostContext", new JSONObject().put("package", hostContext.getPackageName())
            .put("targetPackage", target.getPackageName())
            .put("hostResources", System.identityHashCode(hostContext.getResources()))
            .put("targetResources", System.identityHashCode(target.getResources())));
        onMain(() -> {
            // Never use the Launcher's host ID (1024), deleteAllHosts, or an
            // existing host. A random unused host owns only these allocated IDs.
            for (int attempt = 0; attempt < 8; attempt++) {
                int hostId = 0x465a0000 | (UUID.randomUUID().hashCode() & 0xffff);
                host = new AppWidgetHost(target, hostId) {
                    @Override protected AppWidgetHostView onCreateView(
                        Context context, int id, AppWidgetProviderInfo info
                    ) {
                        return new RecordingHostView(context);
                    }
                };
                if (host.getAppWidgetIds().length == 0) {
                    hostOwned = true;
                    break;
                }
            }
            check(hostOwned, "Reserve a previously unused private AppWidgetHost ID");
            for (int i = 0; i < 3; i++) {
                ids[i] = host.allocateAppWidgetId();
                check(ids[i] > 0, "Allocate " + VARIANTS[i] + " widget ID");
                Bundle options = new Bundle();
                options.putInt(AppWidgetManager.OPTION_APPWIDGET_MIN_WIDTH, WIDTHS[i]);
                options.putInt(AppWidgetManager.OPTION_APPWIDGET_MAX_WIDTH, WIDTHS[i]);
                options.putInt(AppWidgetManager.OPTION_APPWIDGET_MIN_HEIGHT, HEIGHTS[i]);
                options.putInt(AppWidgetManager.OPTION_APPWIDGET_MAX_HEIGHT, HEIGHTS[i]);
                options.putInt(AppWidgetManager.OPTION_APPWIDGET_HOST_CATEGORY,
                    AppWidgetProviderInfo.WIDGET_CATEGORY_HOME_SCREEN);
                options.putParcelableArrayList(AppWidgetManager.OPTION_APPWIDGET_SIZES,
                    new ArrayList<>(List.of(new SizeF(WIDTHS[i], HEIGHTS[i]))));
                check(manager.bindAppWidgetIdIfAllowed(ids[i], component(i), options),
                    "Actually bind " + VARIANTS[i] + "; shell BIND_APPWIDGET is required");
                AppWidgetProviderInfo info = manager.getAppWidgetInfo(ids[i]);
                check(info != null && info.provider.equals(component(i)),
                    "System service confirms the " + VARIANTS[i] + " binding");
                views[i] = (RecordingHostView) host.createView(hostContext, ids[i], info);
                check(views[i] != null, "Create " + VARIANTS[i] + " real host view");
            }
            host.startListening();
            return null;
        });
    }

    private void captureHost(String label, Palette palette) throws Exception {
        JSONArray entries = new JSONArray();
        result.put("lastHostPalette", palette.json());
        Palette freshBefore = Palette.read(target);
        Palette applicationBefore = new Palette(target);
        for (int i = 0; i < 3; i++) {
            final int variant = i;
            JSONObject entry = onMain(() -> {
                RecordingHostView view = views[variant];
                RemoteViews retained = view.retained;
                int received = view.received;
                // reset is necessary when only uiMode changes: identical maps
                // otherwise make setColorResources intentionally a no-op.
                view.resetColorResources();
                view.setColorResources(palette.mapping);
                check(view.retained == retained && view.received == received,
                    VARIANTS[variant] + " recolors without another RemoteViews update");
                check(containsFixture(view, variant), "Retained fixture stays visible");
                View content = view.findViewById(R.id.widget_container);
                check(content != null &&
                    target.getPackageName().equals(content.getContext().getPackageName()) &&
                    content.getResources() != target.getResources() &&
                    content.getResources() != view.getResources(),
                    VARIANTS[variant] + " remote provider resources are separate from " +
                        "target Application and test APK host resources");
                Palette freshAfterOverride = Palette.read(target);
                Palette applicationAfterOverride = new Palette(target);
                result.put("lastHostIsolation", new JSONObject().put("label", label)
                    .put("variant", VARIANTS[variant])
                    .put("remoteResources", System.identityHashCode(content.getResources()))
                    .put("targetResources", System.identityHashCode(target.getResources()))
                    .put("hostResources", System.identityHashCode(view.getResources()))
                    .put("freshDifferences", freshBefore.differences(freshAfterOverride))
                    .put("applicationDifferences",
                        applicationBefore.differences(applicationAfterOverride)));
                check(freshBefore.sameSystemColors(freshAfterOverride) &&
                    freshBefore.background == freshAfterOverride.background &&
                    applicationBefore.sameSystemColors(applicationAfterOverride) &&
                    applicationBefore.background == applicationAfterOverride.background,
                    label + " " + VARIANTS[variant] +
                        " host color overrides preserve global and Application palettes");
                Bitmap bitmap = render(view, WIDTHS[variant], HEIGHTS[variant]);
                try {
                    check(count(bitmap, palette.background) >= 40,
                        label + " " + VARIANTS[variant] + " surface uses the host palette");
                    TextView heading = view.findViewById(R.id.widget_heading);
                    int expectedHeading = variant == 2 ? palette.primary : palette.accent;
                    check(heading != null && heading.getCurrentTextColor() == expectedHeading,
                        label + " " + VARIANTS[variant] + " text uses its semantic color");
                    JSONObject item = new JSONObject()
                        .put("variant", VARIANTS[variant])
                        .put("heading", hex(heading.getCurrentTextColor()))
                        .put("sha256", digest(bitmap))
                        .put("receivedRemoteViews", received);
                    save(bitmap, "host-" + label + "-" + VARIANTS[variant] + ".png");
                    if (variant == 2) {
                        View grid = view.findViewById(R.id.widget_timetable_grid);
                        check(grid != null && grid.getWidth() > 0 && grid.getHeight() > 0,
                            "Layered timetable grid is actually laid out");
                        Bitmap pixels = renderSized(grid);
                        try {
                            // Save before assertions so a failing role remains inspectable.
                            save(pixels, "host-" + label + "-grid.png");
                            checkMaskTintsAndComposite(grid, pixels, palette, label);
                            item.put("gridSha256", digest(pixels));
                        } finally {
                            pixels.recycle();
                        }
                    }
                    return item;
                } finally {
                    bitmap.recycle();
                }
            });
            entries.put(entry);
        }
        stages.put(new JSONObject().put("kind", "retainedHost").put("label", label)
            .put("palette", palette.json()).put("widgets", entries));
        Palette freshAfter = Palette.read(target);
        Palette applicationAfter = new Palette(target);
        result.put("lastHostResourceObservation", new JSONObject()
            .put("freshBefore", freshBefore.json()).put("freshAfter", freshAfter.json())
            .put("applicationBefore", applicationBefore.json())
            .put("applicationAfter", applicationAfter.json())
            .put("applicationMatchesFresh", applicationAfter.sameSystemColors(freshAfter)));
        status("retainedHost " + label + " passed");
    }

    private void captureLauncher(String label, Palette palette) throws Exception {
        JSONObject captured = new JSONObject();
        long deadline = SystemClock.elapsedRealtime() + TIMEOUT_MS;
        showHome();
        try {
            for (int page = 0; page < 6 && captured.length() < 3; page++) {
                final int pageNumber = page;
                awaitUntil("Launcher automatically uses " + label + " colors, page " + page,
                    deadline, () -> {
                    Map<String, Rect> bounds = launcherBounds();
                    if (bounds == null) return false;
                    boolean uncollected = false;
                    for (String variant : VARIANTS) {
                        if (bounds.containsKey(variant) && !captured.has(variant)) uncollected = true;
                    }
                    if (!uncollected) return true;
                    Bitmap screen = screenshot();
                    if (screen == null) return false;
                    JSONObject foundOnPage = new JSONObject();
                    JSONObject observations = new JSONObject().put("label", label).put("page", pageNumber);
                    try {
                        for (int i = 0; i < 3; i++) {
                            String variant = VARIANTS[i];
                            Rect area = bounds.get(variant);
                            if (captured.has(variant) || area == null) continue;
                            if (!inside(screen, area)) return false;
                            Bitmap crop = crop(screen, area);
                            try {
                                int heading = i == 2 ? palette.primary : palette.accent;
                                int surfaces = count(crop, palette.background);
                                int headings = countBlendedTint(crop, heading, palette.background);
                                observations.put(variant, new JSONObject()
                                    .put("surfacePixels", surfaces).put("headingPixels", headings));
                                result.put("lastLauncherObservation", observations);
                                if (surfaces < 40 || headings < 8) return false;
                                JSONObject entry = new JSONObject().put("page", pageNumber)
                                    .put("bounds", rectJson(area)).put("sha256", digest(crop));
                                if (i == 2) {
                                    Rect gridArea = bounds.get("grid");
                                    if (!inside(screen, gridArea)) return false;
                                    Bitmap grid = crop(screen, gridArea);
                                    try {
                                        observations.put("grid", new JSONObject()
                                            .put("primaryContainerPixels", count(grid, palette.primaryContainer))
                                            .put("secondaryContainerPixels", count(grid, palette.secondaryContainer))
                                            .put("primaryTextPixels", countBlendedTint(grid,
                                                palette.onPrimaryContainer, palette.primaryContainer))
                                            .put("secondaryTextPixels", countBlendedTint(grid,
                                                palette.onSecondaryContainer, palette.secondaryContainer))
                                            .put("todaySurfacePixels", count(grid, palette.todaySurface))
                                            .put("primaryLabelPixels", countBlendedTint(grid,
                                                palette.primary, palette.background))
                                            .put("secondaryLabelPixels", countBlendedTint(grid,
                                                palette.secondary, palette.background))
                                            .put("accentLabelPixels", countBlendedTint(grid,
                                                palette.accent, palette.todaySurface)));
                                        if (!courseLayersMatch(grid, palette)) return false;
                                        entry.put("gridSha256", digest(grid));
                                        save(grid, "launcher-" + label + "-grid.png");
                                    } finally {
                                        grid.recycle();
                                    }
                                }
                                save(crop, "launcher-" + label + "-" + variant + ".png");
                                foundOnPage.put(variant, entry);
                            } finally {
                                crop.recycle();
                            }
                        }
                        save(screen, "launcher-" + label + "-page-" + pageNumber + ".png");
                        for (String variant : VARIANTS) {
                            if (foundOnPage.has(variant)) captured.put(variant, foundOnPage.get(variant));
                        }
                        return true;
                    } finally {
                        screen.recycle();
                    }
                });
                if (captured.length() < 3) swipePage(true);
            }
            check(captured.length() == 3,
                "Find all three Launcher widgets within six pages for " + label +
                    "; captured=" + captured.names());
        } finally {
            showHome();
        }
        stages.put(new JSONObject().put("kind", "realLauncher").put("label", label)
            .put("palette", palette.json()).put("widgets", captured));
        status("realLauncher " + label + " passed");
    }

    private void showHome() throws Exception {
        check(automation.performGlobalAction(AccessibilityService.GLOBAL_ACTION_HOME),
            "Return to Launcher");
        await("Launcher visible", () -> launcherBounds() != null);
        // Pixel Launcher uses a second HOME to select its default page. This
        // navigates only; no widget is removed, rebound or recreated.
        automation.performGlobalAction(AccessibilityService.GLOBAL_ACTION_HOME);
        SystemClock.sleep(250);
    }

    private void swipePage(boolean forward) {
        float width = target.getResources().getDisplayMetrics().widthPixels;
        float y = target.getResources().getDisplayMetrics().heightPixels * 0.55f;
        float from = width * (forward ? 0.85f : 0.15f);
        float to = width * (forward ? 0.15f : 0.85f);
        long downTime = SystemClock.uptimeMillis();
        for (int step = 0; step <= 12; step++) {
            int action = step == 0 ? MotionEvent.ACTION_DOWN :
                step == 12 ? MotionEvent.ACTION_UP : MotionEvent.ACTION_MOVE;
            MotionEvent event = MotionEvent.obtain(downTime, SystemClock.uptimeMillis(), action,
                from + (to - from) * step / 12, y, 0);
            event.setSource(InputDevice.SOURCE_TOUCHSCREEN);
            try {
                if (!automation.injectInputEvent(event, true)) {
                    throw new AssertionError("Launcher page-swipe injection failed");
                }
            } finally {
                event.recycle();
            }
            if (step < 12) SystemClock.sleep(20);
        }
        // Let the bounded page animation finish before sampling accessibility
        // bounds. Pixel correctness itself is polled, never assumed from a delay.
        SystemClock.sleep(350);
    }

    private void checkMaskTintsAndComposite(
        View grid, Bitmap actual, Palette palette, String label
    ) throws Exception {
        int[] layerIds = {
            R.id.widget_grid_today_surface, R.id.widget_grid_outline,
            R.id.widget_grid_primary_container, R.id.widget_grid_secondary_container,
            R.id.widget_grid_surface, R.id.widget_grid_primary, R.id.widget_grid_secondary,
            R.id.widget_grid_accent, R.id.widget_grid_on_primary_container,
            R.id.widget_grid_on_secondary_container,
        };
        int[] colors = {
            palette.todaySurface, palette.outline, palette.primaryContainer,
            palette.secondaryContainer, palette.background, palette.primary, palette.secondary,
            palette.accent, palette.onPrimaryContainer, palette.onSecondaryContainer,
        };
        JSONArray diagnostics = new JSONArray();
        result.put("lastMaskDiagnostics", diagnostics);
        Bitmap reference = Bitmap.createBitmap(actual.getWidth(), actual.getHeight(),
            Bitmap.Config.ARGB_8888);
        try {
            Canvas canvas = new Canvas(reference);
            for (int i = 0; i < layerIds.length; i++) {
                ImageView layer = grid.findViewById(layerIds[i]);
                String name = target.getResources().getResourceEntryName(layerIds[i]);
                ColorStateList tint = layer == null ? null : layer.getImageTintList();
                Bitmap source = layer != null && layer.getDrawable() instanceof BitmapDrawable
                    ? ((BitmapDrawable) layer.getDrawable()).getBitmap() : null;
                JSONObject item = new JSONObject().put("role", name)
                    .put("expectedTint", hex(colors[i]))
                    .put("actualTint", tint == null ? JSONObject.NULL :
                        hex(tint.getColorForState(layer.getDrawableState(), tint.getDefaultColor())))
                    .put("config", source == null ? JSONObject.NULL : String.valueOf(source.getConfig()))
                    .put("exactCompositePixels", count(actual, colors[i]));
                diagnostics.put(item);
                check(layer != null && tint != null &&
                    tint.getColorForState(layer.getDrawableState(), tint.getDefaultColor()) == colors[i],
                    label + " " + name + " resolves the host's semantic tint");
                check(source != null && source.getConfig() == Bitmap.Config.ALPHA_8,
                    label + " " + name + " retains an actual ALPHA_8 mask through Binder");
                int[] mask = new int[source.getWidth() * source.getHeight()];
                source.getPixels(mask, 0, source.getWidth(), 0, 0, source.getWidth(), source.getHeight());
                int covered = 0;
                int opaque = 0;
                for (int pixel : mask) {
                    if ((pixel >>> 24) > 0) covered++;
                    if ((pixel >>> 24) == 255) opaque++;
                }
                item.put("sourceWidth", source.getWidth()).put("sourceHeight", source.getHeight())
                    .put("coveredAlphaPixels", covered).put("opaqueAlphaPixels", opaque);
                // This nonempty-week fixture intentionally leaves only the
                // empty-week message surface mask empty.
                check(covered > 0 || layerIds[i] == R.id.widget_grid_surface,
                    label + " " + name + " contains real alpha coverage");

                Bitmap coverage;
                try {
                    // Extract the actual view's scaled coverage independently
                    // of its production tint, preserving ImageView's matrix.
                    layer.setImageTintList(ColorStateList.valueOf(Color.WHITE));
                    coverage = renderSized(layer);
                } finally {
                    layer.setImageTintList(tint);
                }
                try {
                    Paint paint = new Paint();
                    paint.setColorFilter(new PorterDuffColorFilter(colors[i], PorterDuff.Mode.SRC_IN));
                    canvas.drawBitmap(coverage, layer.getLeft(), layer.getTop(), paint);
                } finally {
                    coverage.recycle();
                }
            }
            save(reference, "host-" + label + "-grid-reference.png");
            int[] observed = new int[actual.getWidth()];
            int[] expected = new int[actual.getWidth()];
            int mismatches = 0;
            int maximumDelta = 0;
            for (int y = 0; y < actual.getHeight(); y++) {
                actual.getPixels(observed, 0, observed.length, 0, y, observed.length, 1);
                reference.getPixels(expected, 0, expected.length, 0, y, expected.length, 1);
                for (int x = 0; x < observed.length; x++) {
                    int delta = premultipliedDelta(observed[x], expected[x]);
                    maximumDelta = Math.max(maximumDelta, delta);
                    if (delta > 2) mismatches++;
                }
            }
            result.put("lastGridComposite", new JSONObject().put("label", label)
                .put("mismatchedPixels", mismatches).put("maxPremultipliedChannelDelta", maximumDelta)
                .put("roundingTolerance", 2));
            // Tinting then scaling and scaling alpha then tinting can differ by
            // 1-2 channel units from 8-bit rounding. Every pixel is compared;
            // opaque-text existence is not an Android rendering requirement.
            check(mismatches == 0, label + " all grid pixels match the actual alpha masks " +
                "composited with exact expected role colors; mismatches=" + mismatches +
                ", maxDelta=" + maximumDelta);
        } finally {
            reference.recycle();
        }
    }

    private boolean courseLayersMatch(Bitmap bitmap, Palette palette) {
        return count(bitmap, palette.primaryContainer) >= 20 &&
            count(bitmap, palette.secondaryContainer) >= 20 &&
            countBlendedTint(bitmap, palette.onPrimaryContainer, palette.primaryContainer) >= 6 &&
            countBlendedTint(bitmap, palette.onSecondaryContainer, palette.secondaryContainer) >= 6 &&
            count(bitmap, palette.todaySurface) >= 20 &&
            countBlendedTint(bitmap, palette.secondary, palette.background) >= 6 &&
            countBlendedTint(bitmap, palette.primary, palette.background) >= 6 &&
            countBlendedTint(bitmap, palette.accent, palette.todaySurface) >= 6;
    }

    private Map<String, Rect> launcherBounds() {
        AccessibilityNodeInfo root = automation.getRootInActiveWindow();
        if (root == null) return null;
        try {
            if (!"com.google.android.apps.nexuslauncher".contentEquals(
                root.getPackageName() == null ? "" : root.getPackageName())) return null;
            List<AccessibilityNodeInfo> containers = root.findAccessibilityNodeInfosByViewId(
                target.getResources().getResourceName(R.id.widget_container));
            Map<String, Rect> found = new LinkedHashMap<>();
            try {
                for (AccessibilityNodeInfo node : containers) {
                    Rect area = new Rect();
                    node.getBoundsInScreen(area);
                    if (!node.isVisibleToUser() || area.isEmpty()) continue;
                    List<AccessibilityNodeInfo> grids = node.findAccessibilityNodeInfosByViewId(
                        target.getResources().getResourceName(R.id.widget_timetable_grid));
                    try {
                        if (!grids.isEmpty()) {
                            Rect grid = new Rect();
                            grids.get(0).getBoundsInScreen(grid);
                            found.put("timetable", area);
                            found.put("grid", grid);
                        } else {
                            found.put(area.width() > area.height() * 1.7
                                ? "compact" : "square", area);
                        }
                    } finally {
                        for (AccessibilityNodeInfo grid : grids) grid.recycle();
                    }
                }
            } finally {
                for (AccessibilityNodeInfo node : containers) node.recycle();
            }
            return found;
        } finally {
            root.recycle();
        }
    }

    private void setNight(boolean dark) throws Exception {
        modeTouched = true;
        uiMode.setNightMode(dark ? UiModeManager.MODE_NIGHT_YES : UiModeManager.MODE_NIGHT_NO);
        await("System night configuration becomes " + (dark ? "dark" : "light"),
            () -> (target.getResources().getConfiguration().uiMode &
                Configuration.UI_MODE_NIGHT_MASK) ==
                (dark ? Configuration.UI_MODE_NIGHT_YES : Configuration.UI_MODE_NIGHT_NO));
    }

    private void setWallpaper(int index) throws Exception {
        wallpaperTouched = true;
        int id = wallpapers.setBitmap(images.get(index), null, false, WallpaperManager.FLAG_SYSTEM);
        check(id > 0, "Wallpaper " + (index == 0 ? "A" : "B") + " is accepted by Android");
        await("System reports the newly set wallpaper ID",
            () -> wallpapers.getWallpaperId(WallpaperManager.FLAG_SYSTEM) == id);
    }

    private boolean wallpaperColorsReady() {
        return wallpapers.getWallpaperColors(WallpaperManager.FLAG_SYSTEM) != null;
    }

    private Palette stablePalette() throws Exception {
        AtomicReference<Palette> last = new AtomicReference<>();
        long[] since = {0};
        await("System color resources become stable", () -> {
            Palette current = Palette.read(target);
            if (last.get() == null || !current.sameSystemColors(last.get()) ||
                current.background != last.get().background) {
                last.set(current);
                since[0] = SystemClock.elapsedRealtime();
            }
            return SystemClock.elapsedRealtime() - since[0] >= 750;
        });
        return last.get();
    }

    private File backupWallpaper(int which, String name) throws Exception {
        ParcelFileDescriptor descriptor = wallpapers.getWallpaperFile(which);
        if (descriptor == null) return null; // Default home / shared lock screen.
        File backup = new File(target.getCacheDir(),
            "widget-colors-" + UUID.randomUUID() + "-" + name);
        try (InputStream input = new ParcelFileDescriptor.AutoCloseInputStream(descriptor)) {
            write(backup, readBounded(input));
        } catch (Throwable error) {
            backup.delete();
            throw error;
        }
        return backup;
    }

    private Bitmap readWallpaper(String path) throws Exception {
        // The caller checked exact A/B paths above; no arbitrary shell fragment.
        byte[] bytes;
        try (InputStream input = new ParcelFileDescriptor.AutoCloseInputStream(
            automation.executeShellCommand("cat " + path))) {
            bytes = readBounded(input);
        }
        BitmapFactory.Options options = new BitmapFactory.Options();
        options.inJustDecodeBounds = true;
        BitmapFactory.decodeByteArray(bytes, 0, bytes.length, options);
        check(options.outWidth > 0 && options.outHeight > 0 &&
            (long) options.outWidth * options.outHeight <= 60_000_000,
            "Input is a bounded, decodable wallpaper image");
        options.inJustDecodeBounds = false;
        options.inSampleSize = 1;
        while (Math.max(options.outWidth, options.outHeight) / options.inSampleSize > 2400) {
            options.inSampleSize *= 2;
        }
        options.inPreferredConfig = Bitmap.Config.ARGB_8888;
        Bitmap bitmap = BitmapFactory.decodeByteArray(bytes, 0, bytes.length, options);
        check(bitmap != null, "Decode the supplied wallpaper");
        return bitmap;
    }

    private String snapshot() throws Exception {
        Calendar beijing = Calendar.getInstance(TimeZone.getTimeZone("Asia/Shanghai"), Locale.ROOT);
        long now = System.currentTimeMillis();
        beijing.setTimeInMillis(now);
        beijing.set(Calendar.HOUR_OF_DAY, 0);
        beijing.set(Calendar.MINUTE, 0);
        beijing.set(Calendar.SECOND, 0);
        beijing.set(Calendar.MILLISECOND, 0);
        beijing.add(Calendar.DAY_OF_MONTH, -((beijing.get(Calendar.DAY_OF_WEEK) + 5) % 7));
        long monday = beijing.getTimeInMillis();
        JSONArray days = new JSONArray();
        for (int i = 0; i < 14; i++) {
            long start = monday + i * 86_400_000L;
            JSONArray courses = new JSONArray();
            for (int j = 0; j < 2; j++) {
                long courseStart = start + (8 + j * 5) * 3_600_000L;
                courses.put(new JSONObject().put("name", "QA Color " + j)
                    .put("location", "QA Room " + j).put("start", courseStart)
                    .put("end", courseStart + 90 * 60_000L)
                    .put("startClass", 1 + j * 4).put("endClass", 2 + j * 4).put("week", 9));
            }
            days.put(new JSONObject().put("start", start).put("known", true)
                .put("week", 9).put("courses", courses));
        }
        return new JSONObject().put("version", 1).put("signedIn", true).put("locale", "en")
            .put("generatedAt", now).put("sourceUpdatedAt", now).put("days", days).toString();
    }

    private void cleanup() {
        // Attempt every independent restoration even if a preceding one failed.
        if (snapshotTouched) cleanupStep("restore snapshot key", () -> {
            SharedPreferences.Editor editor = livePreferences.edit();
            if (hadSnapshot) editor.putString("snapshot", oldSnapshot); else editor.remove("snapshot");
            check(editor.commit(), "Restore the original snapshot key");
            return null;
        });
        if (hostOwned) cleanupStep("stop the private host listener", () -> onMain(() -> {
            host.stopListening();
            return null;
        }));
        if (hostOwned) cleanupStep("delete only the private host", () -> onMain(() -> {
            host.deleteHost();
            check(host.getAppWidgetIds().length == 0, "All private widget bindings removed");
            return null;
        }));
        boolean homeRestored = true;
        boolean lockRestored = true;
        boolean paletteRestored = true;
        if (wallpaperTouched) {
            homeRestored = cleanupStep("restore home wallpaper", () -> {
                restoreWallpaper(homeBackup, WallpaperManager.FLAG_SYSTEM);
                return null;
            });
            lockRestored = cleanupStep("restore lock wallpaper / shared-home relationship", () -> {
                restoreWallpaper(lockBackup, WallpaperManager.FLAG_LOCK);
                return null;
            });
            cleanupStep("restore wallpaper theme setting", () -> {
                check(Settings.Secure.putString(target.getContentResolver(), OVERLAY_SETTING,
                    originalOverlay), "Restore the exact previous wallpaper overlay setting");
                return null;
            });
        }
        if (modeTouched) cleanupStep("restore night mode", () -> {
            uiMode.setNightMode(originalNightMode);
            await("Original night-mode setting restored",
                () -> uiMode.getNightMode() == originalNightMode &&
                    (target.getResources().getConfiguration().uiMode &
                        Configuration.UI_MODE_NIGHT_MASK) == originalNightConfiguration);
            return null;
        });
        if (wallpaperTouched) paletteRestored = cleanupStep("restore system palette", () -> {
            await("Original system palette restored",
                () -> Palette.read(target).sameSystemColors(originalPalette));
            result.put("restoredPalette", Palette.read(target).json());
            return null;
        });
        if (wallpaperTouched) cleanupStep("verify exact theme setting", () -> {
            // SystemUI can persist its extracted seed asynchronously. Restore
            // the original setting once extraction/restoration has settled.
            if (!Objects.equals(originalOverlay, Settings.Secure.getString(
                target.getContentResolver(), OVERLAY_SETTING))) {
                check(Settings.Secure.putString(target.getContentResolver(), OVERLAY_SETTING,
                    originalOverlay), "Restore the pre-test theme setting after extraction");
            }
            check(Objects.equals(originalOverlay, Settings.Secure.getString(
                target.getContentResolver(), OVERLAY_SETTING)), "Verify the exact original theme setting");
            return null;
        });
        if (launcherTouched) cleanupStep("restore existing Launcher widget contents", () -> onMain(() -> {
            for (int i = 0; i < 3; i++) {
                provider(i).onUpdate(target, manager, new int[]{launcherIds[i]});
            }
            return null;
        }));
        if (preferencePrefix != null) cleanupStep("remove isolated preferences", () -> {
            check(target.deleteSharedPreferences(preferencePrefix + "next_course_widget"),
                "Remove the independent snapshot preference file");
            return null;
        });
        for (Bitmap image : images) image.recycle();
        if (permissionAdopted) {
            cleanupStep("drop shell permission identity", () -> {
                automation.dropShellPermissionIdentity();
                return null;
            });
        }
        for (File backup : new File[]{homeBackup, lockBackup}) {
            if (backup != null &&
                (!paletteRestored || (backup == homeBackup && !homeRestored) ||
                    (backup == lockBackup && !lockRestored))) {
                cleanupFailures.add("Original wallpaper retained for recovery: " + backup.getAbsolutePath());
                continue;
            }
            if (backup != null) cleanupStep("delete private wallpaper backup", () -> {
                check(backup.delete(), "Remove private wallpaper backup " + backup.getName());
                return null;
            });
        }
    }

    private void restoreWallpaper(File backup, int which) throws Exception {
        if (backup == null) {
            wallpapers.clear(which);
        } else {
            try (InputStream input = new FileInputStream(backup)) {
                check(wallpapers.setStream(input, null, false, which) > 0,
                    "Restore the saved wallpaper");
            }
        }
    }

    private boolean cleanupStep(String label, Callable<?> action) {
        try {
            action.call();
            return true;
        } catch (Throwable error) {
            cleanupFailures.add(label + ": " + error);
            Log.e(LOG_TAG, "cleanup: " + label, error);
            try {
                result.put("cleanupStackTrace", Log.getStackTraceString(error));
                if (originalPalette != null && target != null) {
                    Palette fresh = Palette.read(target);
                    result.put("cleanupPaletteObservation", new JSONObject()
                        .put("original", originalPalette.json()).put("fresh", fresh.json())
                        .put("application", new Palette(target).json())
                        .put("systemDifferences", originalPalette.differences(fresh)));
                }
            } catch (Exception diagnosticError) {
                Log.e(LOG_TAG, "Cannot record cleanup diagnostics", diagnosticError);
            }
            return false;
        }
    }

    private void phase(String name) {
        currentStage = name;
        status("starting " + name);
    }

    private void status(String message) {
        Bundle bundle = new Bundle();
        bundle.putString("stream", "\nwidgetColors: " + message + "\n");
        instrumentation.sendStatus(0, bundle);
    }

    private void await(String label, Callable<Boolean> condition) throws Exception {
        awaitUntil(label, SystemClock.elapsedRealtime() + TIMEOUT_MS, condition);
    }

    private void awaitUntil(String label, long deadline, Callable<Boolean> condition) throws Exception {
        do {
            if (condition.call()) return;
            SystemClock.sleep(150);
        } while (SystemClock.elapsedRealtime() < deadline);
        throw new AssertionError("Timeout (30s), stage " + currentStage + ": " + label);
    }

    private <T> T onMain(Callable<T> action) throws Exception {
        AtomicReference<T> value = new AtomicReference<>();
        AtomicReference<Throwable> failure = new AtomicReference<>();
        instrumentation.runOnMainSync(() -> {
            try { value.set(action.call()); } catch (Throwable error) { failure.set(error); }
        });
        if (failure.get() instanceof Exception) throw (Exception) failure.get();
        if (failure.get() instanceof Error) throw (Error) failure.get();
        if (failure.get() != null) throw new AssertionError("Main-thread test failure", failure.get());
        return value.get();
    }

    private void check(boolean condition, String message) {
        assertions++;
        lastAssertion = message;
        if (!condition) throw new AssertionError(message);
    }

    private NextCourseWidgetProvider provider(int variant) {
        if (variant == 0) return new NextCourseCompactWidgetProvider();
        if (variant == 1) return new NextCourseSquareWidgetProvider();
        return new TimetableWidgetProvider();
    }

    private ComponentName component(int variant) {
        return new ComponentName(target, provider(variant).getClass());
    }

    private static int[] parseLauncherIds(String raw) {
        if (raw == null || !raw.matches("[1-9][0-9]*,[1-9][0-9]*,[1-9][0-9]*")) {
            throw new IllegalArgumentException("-e launcherIds requires compact,square,timetable IDs");
        }
        int[] parsed = Arrays.stream(raw.split(",")).mapToInt(Integer::parseInt).toArray();
        if (parsed[0] == parsed[1] || parsed[0] == parsed[2] || parsed[1] == parsed[2]) {
            throw new IllegalArgumentException("launcherIds must be three distinct IDs");
        }
        return parsed;
    }

    private static boolean containsFixture(View root, int variant) {
        if (variant == 2) {
            View grid = root.findViewById(R.id.widget_timetable_grid);
            return grid != null && grid.getVisibility() == View.VISIBLE &&
                grid.getContentDescription() != null &&
                grid.getContentDescription().toString().contains("QA Color 0");
        }
        TextView course = root.findViewById(R.id.widget_course);
        return course != null && course.getText().toString().startsWith("QA Color ");
    }

    private static Bitmap render(View view, int widthDp, int heightDp) {
        float density = view.getResources().getDisplayMetrics().density;
        int width = Math.round(widthDp * density);
        int height = Math.round(heightDp * density);
        view.measure(View.MeasureSpec.makeMeasureSpec(width, View.MeasureSpec.EXACTLY),
            View.MeasureSpec.makeMeasureSpec(height, View.MeasureSpec.EXACTLY));
        view.layout(0, 0, width, height);
        return renderSized(view);
    }

    private static Bitmap renderSized(View view) {
        Bitmap bitmap = Bitmap.createBitmap(view.getWidth(), view.getHeight(), Bitmap.Config.ARGB_8888);
        view.draw(new Canvas(bitmap));
        return bitmap;
    }

    private static boolean inside(Bitmap bitmap, Rect area) {
        return area != null && !area.isEmpty() && area.left >= 0 && area.top >= 0 &&
            area.right <= bitmap.getWidth() && area.bottom <= bitmap.getHeight();
    }

    private static Bitmap crop(Bitmap bitmap, Rect area) {
        return Bitmap.createBitmap(bitmap, area.left, area.top, area.width(), area.height());
    }

    private static int count(Bitmap bitmap, int color) {
        int[] row = new int[bitmap.getWidth()];
        int count = 0;
        for (int y = 0; y < bitmap.getHeight(); y++) {
            bitmap.getPixels(row, 0, row.length, 0, y, row.length, 1);
            for (int pixel : row) if (pixel == color) count++;
        }
        return count;
    }

    private static int premultipliedDelta(int actual, int expected) {
        int a = actual >>> 24;
        int b = expected >>> 24;
        int maximum = Math.abs(a - b);
        for (int shift = 16; shift >= 0; shift -= 8) {
            int observed = (((actual >>> shift) & 255) * a + 127) / 255;
            int wanted = (((expected >>> shift) & 255) * b + 127) / 255;
            maximum = Math.max(maximum, Math.abs(observed - wanted));
        }
        return maximum;
    }

    private static int countBlendedTint(Bitmap bitmap, int foreground, int background) {
        int[] row = new int[bitmap.getWidth()];
        int strongest = 0;
        int distance = 0;
        for (int shift = 16; shift >= 0; shift -= 8) {
            int contrast = Math.abs(((foreground >>> shift) & 255) - ((background >>> shift) & 255));
            if (contrast > distance) { distance = contrast; strongest = shift; }
        }
        if (distance < 8) return 0;
        int count = 0;
        for (int y = 0; y < bitmap.getHeight(); y++) {
            bitmap.getPixels(row, 0, row.length, 0, y, row.length, 1);
            for (int pixel : row) {
                // A screenshot is opaque: require the pixel to lie on the
                // expected foreground/background alpha-compositing line.
                double alpha = (double) (((pixel >>> strongest) & 255) -
                    ((background >>> strongest) & 255)) /
                    (((foreground >>> strongest) & 255) - ((background >>> strongest) & 255));
                if (alpha < 0.25 || alpha > 1.01) continue;
                boolean matches = true;
                for (int shift = 16; shift >= 0; shift -= 8) {
                    double wanted = ((background >>> shift) & 255) * (1 - alpha) +
                        ((foreground >>> shift) & 255) * alpha;
                    if (Math.abs(((pixel >>> shift) & 255) - wanted) > 2) matches = false;
                }
                if (matches) count++;
            }
        }
        return count;
    }

    private static JSONArray rectJson(Rect rect) {
        return new JSONArray(List.of(rect.left, rect.top, rect.right, rect.bottom));
    }

    private static String digest(Bitmap bitmap) throws Exception {
        MessageDigest digest = MessageDigest.getInstance("SHA-256");
        int[] row = new int[bitmap.getWidth()];
        for (int y = 0; y < bitmap.getHeight(); y++) {
            bitmap.getPixels(row, 0, row.length, 0, y, row.length, 1);
            for (int pixel : row) {
                digest.update((byte) (pixel >>> 24));
                digest.update((byte) (pixel >>> 16));
                digest.update((byte) (pixel >>> 8));
                digest.update((byte) pixel);
            }
        }
        StringBuilder hex = new StringBuilder();
        for (byte value : digest.digest()) hex.append(String.format(Locale.ROOT, "%02x", value & 255));
        return hex.toString();
    }

    private static String hex(int color) {
        return String.format(Locale.ROOT, "#%08x", color);
    }

    private void save(Bitmap bitmap, String name) throws Exception {
        try (FileOutputStream stream = new FileOutputStream(new File(artifacts, name))) {
            if (!bitmap.compress(Bitmap.CompressFormat.PNG, 100, stream)) {
                throw new AssertionError("Cannot save PNG artifact " + name);
            }
        }
    }

    private Bitmap screenshot() {
        Bitmap raw = automation.takeScreenshot();
        if (raw == null) return null;
        try {
            // Some Android builds return a hardware-backed screenshot. Pixel
            // assertions require a software bitmap rather than getPixels(HARDWARE).
            return raw.copy(Bitmap.Config.ARGB_8888, false);
        } finally {
            raw.recycle();
        }
    }

    private String shellText(String command) throws Exception {
        try (InputStream input = new ParcelFileDescriptor.AutoCloseInputStream(
            automation.executeShellCommand(command))) {
            return new String(readBounded(input), StandardCharsets.UTF_8);
        }
    }

    private static byte[] readBounded(InputStream input) throws Exception {
        ByteArrayOutputStream output = new ByteArrayOutputStream();
        byte[] buffer = new byte[16 * 1024];
        int length;
        while ((length = input.read(buffer)) != -1) {
            if (output.size() + length > MAX_IMAGE_BYTES) {
                throw new IllegalArgumentException("Wallpaper input/backup exceeds 32 MB");
            }
            output.write(buffer, 0, length);
        }
        return output.toByteArray();
    }

    private static void write(File file, byte[] data) throws Exception {
        try (FileOutputStream output = new FileOutputStream(file)) { output.write(data); }
    }

    private static final class RecordingHostView extends AppWidgetHostView {
        RemoteViews retained;
        boolean frozen;
        int received;

        RecordingHostView(Context context) { super(context); }

        @Override public void updateAppWidget(RemoteViews remoteViews) {
            if (remoteViews != null) received++;
            // Once primed, exercise exactly the original RemoteViews even if an
            // unrelated system update arrives. Real Launcher remains unfrozen.
            if (!frozen) {
                retained = remoteViews;
                super.updateAppWidget(remoteViews);
            }
        }
    }

    private static final class Palette {
        final SparseIntArray mapping = new SparseIntArray();
        final int resourceIdentity;
        final int nightConfiguration;
        final int systemAccent;
        final int background;
        final int primary;
        final int secondary;
        final int accent;
        final int primaryContainer;
        final int secondaryContainer;
        final int onPrimaryContainer;
        final int onSecondaryContainer;
        final int todaySurface;
        final int outline;

        static Palette read(Context target) {
            // Do not inherit Application Resources loaders from a host replay.
            // Public createPackageContext obtains unmodified package resources,
            // with current system overlays and an unpinned uiMode.
            try {
                return new Palette(target.createPackageContext(
                    target.getPackageName(), Context.CONTEXT_RESTRICTED));
            } catch (android.content.pm.PackageManager.NameNotFoundException error) {
                throw new IllegalStateException("Cannot observe the installed package palette", error);
            }
        }

        private Palette(Context context) {
            resourceIdentity = System.identityHashCode(context.getResources());
            nightConfiguration = context.getResources().getConfiguration().uiMode &
                Configuration.UI_MODE_NIGHT_MASK;
            for (String family : FAMILIES) {
                for (int tone : TONES) {
                    int id = context.getResources().getIdentifier("system_" + family + "_" + tone,
                        "color", "android");
                    if (id == 0) throw new AssertionError("Missing Android system palette resource");
                    mapping.put(id, context.getColor(id));
                }
            }
            systemAccent = context.getColor(android.R.color.system_accent1_600);
            background = context.getColor(R.color.widget_background);
            primary = context.getColor(R.color.widget_primary);
            secondary = context.getColor(R.color.widget_secondary);
            accent = context.getColor(R.color.widget_accent);
            primaryContainer = context.getColor(R.color.widget_primary_container);
            secondaryContainer = context.getColor(R.color.widget_secondary_container);
            onPrimaryContainer = context.getColor(R.color.widget_on_primary_container);
            onSecondaryContainer = context.getColor(R.color.widget_on_secondary_container);
            todaySurface = context.getColor(R.color.widget_today_surface);
            outline = context.getColor(R.color.widget_outline);
        }

        boolean sameSystemColors(Palette other) {
            if (mapping.size() != other.mapping.size()) return false;
            for (int i = 0; i < mapping.size(); i++) {
                if (mapping.keyAt(i) != other.mapping.keyAt(i) ||
                    mapping.valueAt(i) != other.mapping.valueAt(i)) return false;
            }
            return true;
        }

        JSONObject json() throws Exception {
            return new JSONObject().put("resourceIdentity", resourceIdentity)
                .put("nightConfiguration", nightConfiguration)
                .put("systemAccent600", hex(systemAccent))
                .put("background", hex(background)).put("primary", hex(primary))
                .put("secondary", hex(secondary)).put("accent", hex(accent))
                .put("primaryContainer", hex(primaryContainer))
                .put("secondaryContainer", hex(secondaryContainer))
                .put("onPrimaryContainer", hex(onPrimaryContainer))
                .put("onSecondaryContainer", hex(onSecondaryContainer))
                .put("todaySurface", hex(todaySurface)).put("outline", hex(outline));
        }

        JSONObject differences(Palette actual) throws Exception {
            JSONObject differences = new JSONObject();
            for (int i = 0; i < mapping.size(); i++) {
                int expected = mapping.valueAt(i);
                int observed = actual.mapping.get(mapping.keyAt(i));
                if (expected != observed) differences.put(String.valueOf(mapping.keyAt(i)),
                    new JSONObject().put("expected", hex(expected)).put("actual", hex(observed)));
            }
            return differences;
        }
    }
}
