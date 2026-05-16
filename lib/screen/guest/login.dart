import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:fzu_assistant/l10n/app_localizations.dart';
import 'package:fzu_assistant/main.dart';
import 'package:fzu_assistant/service/api_client.dart';
import 'package:fzu_assistant/service/auth_storage.dart';
import 'package:fzu_assistant/service/login_service.dart';

class LoginPage extends HookWidget {
  const LoginPage({super.key});

  @override
  Widget build(BuildContext context) {
    final usernameController = useTextEditingController();
    final passwordController = useTextEditingController();
    final captchaController = useTextEditingController();
    final isLoading = useState(false);
    final errorMessage = useState<String?>(null);
    final captchaImage = useState<Uint8List?>(null);
    final obscurePassword = useState(true);
    final loginService = useMemoized(() => LoginService());

    Future<void> refreshCaptcha() async {
      try {
        final (image, solution) = await loginService.getCaptchaWithSolution();
        captchaImage.value = image;
        if (solution != null) {
          captchaController.text = solution.toString();
        }
      } catch (e) {
        errorMessage.value = AppLocalizations.of(context)!.captchaFetchFailed(e.toString());
      }
    }

    useEffect(() {
      AuthStorage().loadCredentials().then((creds) {
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
        if (context.mounted) {
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(builder: (_) => const HomeScreen()),
          );
        }
      } catch (e) {
        errorMessage.value = e.toString().replaceFirst('Exception: ', '');
        await refreshCaptcha();
      } finally {
        isLoading.value = false;
      }
    }

    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SizedBox(height: 40),
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
              TextField(
                controller: passwordController,
                obscureText: obscurePassword.value,
                decoration: InputDecoration(
                  labelText: AppLocalizations.of(context)!.password,
                  prefixIcon: const Icon(Icons.lock_outline),
                  suffixIcon: IconButton(
                    icon: Icon(
                      obscurePassword.value
                          ? Icons.visibility_off
                          : Icons.visibility,
                    ),
                    onPressed: () =>
                        obscurePassword.value = !obscurePassword.value,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
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
                      : Text(AppLocalizations.of(context)!.login, style: const TextStyle(fontSize: 16)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
