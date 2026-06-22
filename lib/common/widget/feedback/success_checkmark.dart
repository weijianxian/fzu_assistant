import 'package:flutter/material.dart';

/// 成功对勾动画（类似 Mastercard 付款成功）
class SuccessCheckmark extends StatefulWidget {
  final double size;
  final Color? color;
  final Color? backgroundColor;

  const SuccessCheckmark({
    super.key,
    this.size = 56,
    this.color,
    this.backgroundColor,
  }) : assert(size > 0);

  @override
  State<SuccessCheckmark> createState() => _SuccessCheckmarkState();
}

class _SuccessCheckmarkState extends State<SuccessCheckmark>
    with TickerProviderStateMixin {
  late final AnimationController _circleController;
  late final AnimationController _checkController;
  late final Animation<double> _circleAnimation;
  late final Animation<double> _checkAnimation;

  @override
  void initState() {
    super.initState();
    _circleController = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );
    _checkController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );

    _circleAnimation = CurvedAnimation(
      parent: _circleController,
      curve: Curves.easeOutCubic,
    );
    _checkAnimation = CurvedAnimation(
      parent: _checkController,
      curve: Curves.easeOutCubic,
    );

    _circleController.forward().then((_) {
      _checkController.forward();
    });
  }

  @override
  void dispose() {
    _circleController.dispose();
    _checkController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final effectiveColor = widget.color ?? theme.colorScheme.primary;
    final effectiveBg =
        widget.backgroundColor ?? theme.colorScheme.primaryContainer;

    return Center(
      widthFactor: 1,
      heightFactor: 1,
      child: SizedBox.square(
        dimension: widget.size,
        child: AnimatedBuilder(
          animation: Listenable.merge([_circleAnimation, _checkAnimation]),
          builder: (context, child) {
            return CustomPaint(
              painter: _CheckmarkPainter(
                circleProgress: _circleAnimation.value,
                checkProgress: _checkAnimation.value,
                color: effectiveColor,
                backgroundColor: effectiveBg,
              ),
            );
          },
        ),
      ),
    );
  }
}

class _CheckmarkPainter extends CustomPainter {
  final double circleProgress;
  final double checkProgress;
  final Color color;
  final Color backgroundColor;

  _CheckmarkPainter({
    required this.circleProgress,
    required this.checkProgress,
    required this.color,
    required this.backgroundColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.shortestSide / 2 - 4;
    final strokeWidth = (size.shortestSide / 24).clamp(2.0, 3.0);

    // 绘制背景圆
    final bgPaint = Paint()
      ..color = backgroundColor
      ..style = PaintingStyle.fill;
    canvas.drawCircle(center, radius, bgPaint);

    // 绘制圆圈进度
    if (circleProgress > 0) {
      final circlePaint = Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..strokeCap = StrokeCap.round;
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        -90 * (3.141592653589793 / 180),
        360 * circleProgress * (3.141592653589793 / 180),
        false,
        circlePaint,
      );
    }

    // 绘制对勾
    if (checkProgress > 0) {
      final checkPaint = Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round;

      // 对勾路径：从左下到中间，再从中间到右上
      final path = Path();
      final startPoint = Offset(size.width * 0.25, size.height * 0.5);
      final midPoint = Offset(size.width * 0.45, size.height * 0.65);
      final endPoint = Offset(size.width * 0.7, size.height * 0.35);

      if (checkProgress <= 0.5) {
        // 画第一段（左下到中间）
        final t = checkProgress * 2;
        final currentPoint = Offset(
          startPoint.dx + (midPoint.dx - startPoint.dx) * t,
          startPoint.dy + (midPoint.dy - startPoint.dy) * t,
        );
        path.moveTo(startPoint.dx, startPoint.dy);
        path.lineTo(currentPoint.dx, currentPoint.dy);
      } else {
        // 画两段
        final t = (checkProgress - 0.5) * 2;
        final currentPoint = Offset(
          midPoint.dx + (endPoint.dx - midPoint.dx) * t,
          midPoint.dy + (endPoint.dy - midPoint.dy) * t,
        );
        path.moveTo(startPoint.dx, startPoint.dy);
        path.lineTo(midPoint.dx, midPoint.dy);
        path.lineTo(currentPoint.dx, currentPoint.dy);
      }

      canvas.drawPath(path, checkPaint);
    }
  }

  @override
  bool shouldRepaint(_CheckmarkPainter oldDelegate) {
    return oldDelegate.circleProgress != circleProgress ||
        oldDelegate.checkProgress != checkProgress ||
        oldDelegate.color != color ||
        oldDelegate.backgroundColor != backgroundColor;
  }
}
