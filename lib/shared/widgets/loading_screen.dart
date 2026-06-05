import 'dart:ui' as ui;
import 'package:flutter/material.dart';

class SpinnerPainter extends CustomPainter {
  final Color color;
  final Color trackColor;
  final double strokeWidth;

  SpinnerPainter({
    required this.color,
    required this.trackColor,
    this.strokeWidth = 2.0,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = trackColor
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke;

    final rrect = RRect.fromRectAndRadius(
      Offset.zero & size,
      const Radius.circular(16),
    );
    canvas.drawRRect(rrect, paint);

    final activePaint = Paint()
      ..color = color
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final path = Path()..addRRect(rrect);
    final pathMetrics = path.computeMetrics();
    for (final metric in pathMetrics) {
      final extract = metric.extractPath(0, metric.length * 0.25);
      canvas.drawPath(extract, activePaint);
    }
  }

  @override
  bool shouldRepaint(covariant SpinnerPainter oldDelegate) {
    return oldDelegate.color != color ||
        oldDelegate.trackColor != trackColor ||
        oldDelegate.strokeWidth != strokeWidth;
  }
}

class LoadingScreen extends StatefulWidget {
  final String message;
  final bool isSuperAdmin;
  final bool fullScreen;
  final Widget? child;
  final bool isLoading;

  const LoadingScreen({
    super.key,
    this.message = "Securing connection...",
    this.isSuperAdmin = false,
    this.fullScreen = true,
    this.child,
    this.isLoading = true,
  });

  @override
  State<LoadingScreen> createState() => _LoadingScreenState();
}

class _LoadingScreenState extends State<LoadingScreen> with TickerProviderStateMixin {
  late final AnimationController _rotationController;
  late final AnimationController _pulseController;
  late final AnimationController _textPulseController;

  late final Animation<double> _pulseAnimation;
  late final Animation<double> _textOpacityAnimation;

  @override
  void initState() {
    super.initState();

    _rotationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat();

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat(reverse: true);

    _pulseAnimation = CurvedAnimation(
      parent: _pulseController,
      curve: Curves.easeInOut,
    );

    _textPulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);

    _textOpacityAnimation = Tween<double>(begin: 0.4, end: 1.0).animate(
      CurvedAnimation(
        parent: _textPulseController,
        curve: Curves.easeInOut,
      ),
    );
  }

  @override
  void dispose() {
    _rotationController.dispose();
    _pulseController.dispose();
    _textPulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.child != null) {
      if (!widget.isLoading) {
        return widget.child!;
      }
      return Stack(
        children: [
          widget.child!,
          Positioned.fill(
            child: ClipRect(
              child: BackdropFilter(
                filter: ui.ImageFilter.blur(sigmaX: 5.0, sigmaY: 5.0),
                child: Container(
                  color: (Theme.of(context).brightness == Brightness.dark
                      ? Colors.black.withValues(alpha: 0.5)
                      : Colors.white.withValues(alpha: 0.5)),
                  child: Center(
                    child: LoadingScreen(
                      message: widget.message,
                      isSuperAdmin: widget.isSuperAdmin,
                      fullScreen: false,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      );
    }

    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    final activeSpinnerColor = isDark ? const Color(0xFF818CF8) : const Color(0xFF6366F1);
    final trackSpinnerColor = activeSpinnerColor.withValues(alpha: 0.1);

    final bgGradColor1 = isDark ? const Color(0xFF4F46E5) : const Color(0xFF6366F1);
    final bgGradColor2 = isDark ? const Color(0xFF7C3AED) : const Color(0xFF8B5CF6);

    Widget loadingContent = Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        // Brand Icon Outer Container with pulse and rotation
        SizedBox(
          width: 60,
          height: 60,
          child: Stack(
            alignment: Alignment.center,
            children: [
              // Pulsing Outer Gradient Ring
              AnimatedBuilder(
                animation: _pulseAnimation,
                builder: (context, child) {
                  final scale = 1.0 + 0.2 * _pulseAnimation.value;
                  final opacity = 0.2 + 0.2 * _pulseAnimation.value;
                  return Transform.scale(
                    scale: scale,
                    child: Opacity(
                      opacity: opacity,
                      child: Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(14),
                          gradient: LinearGradient(
                            colors: [bgGradColor1, bgGradColor2],
                            begin: Alignment.bottomLeft,
                            end: Alignment.topRight,
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
              // Rotating Spinner Border
              RotationTransition(
                turns: _rotationController,
                child: SizedBox(
                  width: 38,
                  height: 38,
                  child: CustomPaint(
                    painter: SpinnerPainter(
                      color: activeSpinnerColor,
                      trackColor: trackSpinnerColor,
                      strokeWidth: 1.5,
                    ),
                  ),
                ),
              ),
              // Central Icon Box
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF0D1117) : Colors.white,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: isDark ? const Color(0xFF30363D) : const Color(0xFFE2E8F0),
                    width: 1,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.15),
                      blurRadius: 12,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: Center(
                  child: widget.isSuperAdmin
                      ? Icon(
                          Icons.shield_outlined,
                          color: isDark ? const Color(0xFFFBBF24) : const Color(0xFFF59E0B),
                          size: 14,
                        )
                      : Image.asset(
                          'assets/mano.png',
                          width: 14,
                          height: 14,
                          errorBuilder: (context, error, stackTrace) {
                            return Icon(
                              Icons.business,
                              color: activeSpinnerColor,
                              size: 14,
                            );
                          },
                        ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        // Loading Status Information
        Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  "MANO ",
                  style: TextStyle(
                    fontSize: 8.5,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 3.0, // tracking-[0.35em]
                    color: isDark ? Colors.white : const Color(0xFF1E293B),
                  ),
                ),
                Text(
                  widget.isSuperAdmin ? "INTERNAL" : "SOFTWARE",
                  style: TextStyle(
                    fontSize: 8.5,
                    fontWeight: FontWeight.w500,
                    letterSpacing: 3.0,
                    color: activeSpinnerColor,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            FadeTransition(
              opacity: _textOpacityAnimation,
              child: Text(
                widget.message.toUpperCase(),
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 7.0,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.5, // tracking-widest
                  color: isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8),
                ),
              ),
            ),
          ],
        ),
      ],
    );

    if (!widget.fullScreen) {
      return Container(
        width: double.infinity,
        height: double.infinity,
        color: Colors.transparent,
        child: Center(child: loadingContent),
      );
    }

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF010404) : const Color(0xFFF8FAFC),
      body: Stack(
        children: [
          // Background Blurs (Only for fullScreen)
          Positioned.fill(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final width = constraints.maxWidth;
                final height = constraints.maxHeight;
                return Stack(
                  children: [
                    // Top-Left Glow
                    Positioned(
                      top: -height * 0.1,
                      left: -width * 0.1,
                      child: AnimatedBuilder(
                        animation: _pulseAnimation,
                        builder: (context, child) {
                          final scale = 1.0 + 0.15 * _pulseAnimation.value;
                          final opacity = 0.3 + 0.15 * _pulseAnimation.value;
                          return Transform.scale(
                            scale: scale,
                            child: Container(
                              width: width * 0.6,
                              height: width * 0.6,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                gradient: RadialGradient(
                                  colors: [
                                    bgGradColor1.withValues(alpha: isDark ? 0.1 * opacity : 0.05 * opacity),
                                    bgGradColor1.withValues(alpha: 0.0),
                                  ],
                                  stops: const [0.0, 1.0],
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                    // Bottom-Right Glow
                    Positioned(
                      bottom: -height * 0.1,
                      right: -width * 0.1,
                      child: AnimatedBuilder(
                        animation: _pulseAnimation,
                        builder: (context, child) {
                          final val = 1.0 - _pulseAnimation.value;
                          final scale = 1.0 + 0.2 * val;
                          final opacity = 0.3 + 0.1 * val;
                          return Transform.scale(
                            scale: scale,
                            child: Container(
                              width: width * 0.5,
                              height: width * 0.5,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                gradient: RadialGradient(
                                  colors: [
                                    bgGradColor2.withValues(alpha: isDark ? 0.1 * opacity : 0.05 * opacity),
                                    bgGradColor2.withValues(alpha: 0.0),
                                  ],
                                  stops: const [0.0, 1.0],
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
          // Main Content
          SafeArea(
            child: Center(
              child: loadingContent,
            ),
          ),
        ],
      ),
    );
  }
}
