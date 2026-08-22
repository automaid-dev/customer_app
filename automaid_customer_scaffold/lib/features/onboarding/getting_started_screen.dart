import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/app_theme.dart';

/// First screen the app opens to. One job: make the brand felt for a
/// second, then get out of the way — "Get started" is the only action.
class GettingStartedScreen extends StatelessWidget {
  const GettingStartedScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              const Spacer(),
              // Hero banner — angular blue/yellow wedges echo the
              // LaundryBar mark's background treatment, giving the brand
              // a presence here without needing a photo asset.
              ClipRRect(
                borderRadius: BorderRadius.circular(28),
                child: AspectRatio(
                  aspectRatio: 1,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      CustomPaint(painter: _WedgeBackgroundPainter()),
                      Center(
                        child: Image.asset(
                          'assets/images/automaid_logo.png',
                          width: 160,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 40),
              Text(
                'Laundry day,\nsorted.',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.displaySmall?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: AppColors.ink,
                      height: 1.15,
                    ),
              ),
              const SizedBox(height: 12),
              Text(
                'Pickup, wash, and delivery — booked in a minute, '
                'tracked the whole way.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 15, color: Colors.grey[700]),
              ),
              const Spacer(),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () => context.go('/login'),
                  child: const Text('Get started'),
                ),
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }
}

/// Simple angular wedge background echoing the LaundryBar mark's own
/// background treatment, in brand blue/yellow, without needing an
/// exported image asset for it.
class _WedgeBackgroundPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    canvas.drawRect(Rect.fromLTWH(0, 0, w, h), Paint()..color = AppColors.blue);

    final yellowWedge = Path()
      ..moveTo(w * 0.55, 0)
      ..lineTo(w, 0)
      ..lineTo(w, h * 0.65)
      ..lineTo(w * 0.2, h)
      ..lineTo(0, h)
      ..lineTo(0, h * 0.85)
      ..close();
    canvas.drawPath(yellowWedge, Paint()..color = AppColors.yellow);

    final blueDarkWedge = Path()
      ..moveTo(w * 0.55, 0)
      ..lineTo(w * 0.8, 0)
      ..lineTo(w * 0.35, h)
      ..lineTo(w * 0.1, h)
      ..close();
    canvas.drawPath(blueDarkWedge, Paint()..color = AppColors.blueDark.withValues(alpha: 0.55));
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
