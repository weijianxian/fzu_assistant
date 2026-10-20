import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

/// 登录页的 SVG 角色，在输入密码时闭眼。
class LoginMascot extends StatelessWidget {
  const LoginMascot({super.key, required this.eyesClosed});

  final bool eyesClosed;

  @override
  Widget build(BuildContext context) => ExcludeSemantics(
    child: SizedBox(
      width: 240,
      height: 240,
      child: DecoratedBox(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Theme.of(context).colorScheme.surfaceContainerHigh,
        ),
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 160),
          child: SvgPicture.asset(
            eyesClosed
                ? 'assets/illustrations/login_mascot_closed.svg'
                : 'assets/illustrations/login_mascot.svg',
            key: ValueKey(eyesClosed),
            width: 240,
            height: 240,
          ),
        ),
      ),
    ),
  );
}
