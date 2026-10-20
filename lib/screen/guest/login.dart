import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:fzu_assistant/common/utils/context_ext.dart';
import 'package:fzu_assistant/common/widget/input/password_field.dart';
import 'package:fzu_assistant/screen/guest/widgets/login_mascot.dart';
import 'package:fzu_assistant/l10n/app_localizations.dart';
import 'package:fzu_assistant/router/app_routes.dart';
import 'package:fzu_assistant/service/api/api_client.dart';
import 'package:fzu_assistant/service/auth_storage.dart';

class LoginPage extends HookWidget {
  const LoginPage({super.key});

  @override
  Widget build(BuildContext context) {
    final usernameController = useTextEditingController();
    final passwordController = useTextEditingController();
    final passwordFocus = useFocusNode();
    useListenable(passwordFocus);
    final captchaController = useTextEditingController();
    final isLoading = useState(false);
    final errorMessage = useState<String?>(null);
    final captchaImage = useState<Uint8List?>(null);

    Future<void> refreshCaptcha() async {
      try {
        final (image, solution) = await ApiClient.instance
            .getCaptchaWithSolution();
        if (!context.mounted) return;
        captchaImage.value = image;
        if (solution != null) {
          captchaController.text = solution.toString();
        }
      } catch (e) {
        if (!context.mounted) return;
        errorMessage.value = AppLocalizations.of(context)!
            .captchaFetchFailed(e.toString());
      }
    }

    useEffect(() {
      AuthStorage().loadCredentials().then((creds) {
        if (!context.mounted) return;
        if (creds != null) {
          usernameController.text = creds.username;
          passwordController.text = creds.password;
        }
      });
      refreshCaptcha();
      return null;
    }, []);

    Future<void> handleLogin() async {
      final username = usernameController.text.trim();
      final password = passwordController.text.trim();
      final captcha = captchaController.text.trim();

      if (username.isEmpty || password.isEmpty || captcha.isEmpty) {
        errorMessage.value = AppLocalizations.of(context)!.loginValidationError;
        return;
      }

      isLoading.value = true;
      errorMessage.value = null;

      try {
        await ApiClient.instance.login(username, password, captcha);
        await AuthStorage().saveCredentials(username, password);
        if (!context.mounted) return;
        context.pushReplacementNamed(AppRoutes.home);
      } catch (e) {
        if (!context.mounted) return;
        errorMessage.value = e.toString().replaceFirst('Exception: ', '');
        await refreshCaptcha();
      } finally {
        if (context.mounted) isLoading.value = false;
      }
    }

    final form = Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480),
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 60),
              Center(
                child: Hero(
                  tag: 'app-icon',
                  child: Image.asset(
                    'assets/icon/icon.png',
                    width: 80,
                    height: 80,
                  ),
                ),
              ),
              const SizedBox(height: 40),
              TextField(
                controller: usernameController,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: AppLocalizations.of(context)!.studentId,
                  prefixIcon: const Icon(Icons.person_outline),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              PasswordField(
                controller: passwordController,
                focusNode: passwordFocus,
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: captchaController,
                      decoration: InputDecoration(
                        labelText: AppLocalizations.of(context)!.captcha,
                        prefixIcon: const Icon(Icons.verified_outlined),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  GestureDetector(
                    onTap: refreshCaptcha,
                    child: Container(
                      width: 120,
                      height: 35,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.grey[300]!),
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: captchaImage.value != null
                          ? Image.memory(captchaImage.value!, fit: BoxFit.fill)
                          : Center(
                              child: Text(
                                AppLocalizations.of(context)!.getCaptcha,
                                style: const TextStyle(fontSize: 12),
                              ),
                            ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              if (errorMessage.value != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Text(
                    errorMessage.value!,
                    style: const TextStyle(color: Colors.red, fontSize: 13),
                  ),
                ),
              const SizedBox(height: 24),
              SizedBox(
                height: 48,
                child: FilledButton(
                  onPressed: isLoading.value ? null : handleLogin,
                  style: FilledButton.styleFrom(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: isLoading.value
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : Text(
                          AppLocalizations.of(context)!.login,
                          style: const TextStyle(fontSize: 16),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );

    return Scaffold(
      body: SafeArea(
        child: context.isLandscape
            ? Row(
                children: [
                  Expanded(
                    child: Center(
                      child: Padding(
                        padding: const EdgeInsets.all(32),
                        child: LoginMascot(eyesClosed: passwordFocus.hasFocus),
                      ),
                    ),
                  ),
                  SizedBox(
                    height: 240,
                    child: VerticalDivider(
                      width: 1,
                      thickness: 1,
                      color: Theme.of(context).colorScheme.outlineVariant,
                    ),
                  ),
                  Expanded(child: form),
                ],
              )
            : form,
      ),
    );
  }
}
