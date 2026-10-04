#!/usr/bin/env bash
set -euo pipefail

# Run from the repository root after flutter build linux --release.
repo_root=$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)
cd "$repo_root"
version=$(sed -n 's/^version:[[:space:]]*//p' pubspec.yaml | head -1 | cut -d+ -f1 | tr -d '[:space:]')
dpkg --validate-version "$version"
architecture=$(dpkg --print-architecture)
if [[ "$architecture" != amd64 ]]; then
  echo "The Linux bundle currently supports amd64 only." >&2
  exit 1
fi

bundle="$repo_root/build/linux/x64/release/bundle"
test -x "$bundle/fzu_assistant"
test -d "$bundle/data/flutter_assets"
test -f "$bundle/lib/libflutter_linux_gtk.so"
output_dir="$repo_root/build/linux-packages"
mkdir -p "$output_dir"
work_dir=$(mktemp -d)
trap 'rm -rf -- "$work_dir"' EXIT
package_root="$work_dir/debian/fzu-assistant"
app_dir="$package_root/usr/lib/fzu-assistant"
mkdir -p "$app_dir" "$package_root/DEBIAN" \
  "$package_root/usr/bin" "$package_root/usr/share/applications" \
  "$package_root/usr/share/icons/hicolor/scalable/apps"
cp -a "$bundle/." "$app_dir/"
install -m 644 installer/linux/fzu-assistant.desktop \
  "$package_root/usr/share/applications/fzu-assistant.desktop"
install -m 644 assets/icon/icon_windows.svg \
  "$package_root/usr/share/icons/hicolor/scalable/apps/fzu-assistant.svg"
cat > "$package_root/usr/bin/fzu-assistant" <<'EOF'
#!/bin/sh
exec /usr/lib/fzu-assistant/fzu_assistant "$@"
EOF
chmod 755 "$package_root/usr/bin/fzu-assistant"
desktop-file-validate "$package_root/usr/share/applications/fzu-assistant.desktop"

# Scan plugins too: checking only the runner misses libraries loaded by Flutter.
# Keep the bundle in a package build tree so dpkg excludes private bundled libs
# without suppressing missing dependency information for system libraries.
cat > "$work_dir/debian/control" <<'EOF'
Source: fzu-assistant
Section: education
Priority: optional
Maintainer: weijianxian <weijianxian@users.noreply.github.com>
Build-Depends: libwpewebkit-2.0-dev (>= 2.50)

Package: fzu-assistant
Architecture: amd64
Description: Fuzhou University campus assistant
EOF
elf_args=("-e$app_dir/fzu_assistant")
while IFS= read -r -d '' library; do
  elf_args+=("-e$library")
done < <(find "$app_dir/lib" -type f -name '*.so*' -print0)
dependencies=$(
  cd "$work_dir"
  dpkg-shlibdeps -O -xfzu-assistant "-S$package_root" \
    "-l$app_dir/lib" "${elf_args[@]}"
)
dependencies=$(printf '%s\n' "$dependencies" | sed -n 's/^shlibs:Depends=//p')
test -n "$dependencies"
installed_size=$(du -sk "$package_root/usr" | cut -f1)
cat > "$package_root/DEBIAN/control" <<EOF
Package: fzu-assistant
Version: $version
Architecture: $architecture
Section: education
Priority: optional
Maintainer: weijianxian <weijianxian@users.noreply.github.com>
Homepage: https://github.com/weijianxian/fzu_assistant
Installed-Size: $installed_size
Depends: $dependencies
Recommends: default-dbus-session-bus, gnome-keyring
Description: Fuzhou University campus assistant
 View course schedules, grades, exams and academic calendars.
EOF
chmod 755 "$package_root/DEBIAN"
chmod 644 "$package_root/DEBIAN/control"
deb="$output_dir/FZU-assistant-v${version}-linux-x86_64.deb"
dpkg-deb --root-owner-group --build "$package_root" "$deb"
dpkg-deb --info "$deb"
dpkg-deb --contents "$deb"
