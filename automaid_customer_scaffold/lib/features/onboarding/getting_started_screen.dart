import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/models/promo_banner_model.dart';
import '../../core/theme/app_theme.dart';
import '../customer/providers/customer_providers.dart';

/// First screen the app opens to. One job: make the brand felt for a
/// second, then get out of the way — "Get started" is the only action.
///
/// The hero content is now an admin-managed carousel (see Banner::class
/// on the backend, target=onboarding) that swipes manually and also
/// auto-advances every few seconds. If no onboarding banners are
/// configured yet, this falls back to the original static brand panel
/// exactly as before, so there's no broken/empty state on a fresh
/// install before anyone's set one up in the admin.
class GettingStartedScreen extends ConsumerWidget {
  const GettingStartedScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bannersAsync = ref.watch(onboardingBannersProvider);

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              const SizedBox(height: 8),
              // Fixed header, above the banner card — not overlaid on
              // top of the sliding image itself, so it doesn't compete
              // with whatever's happening in that image (previous
              // version overlaid it inside the image and it clashed
              // with the banner's own content).
              Image.asset(
                'assets/images/laundrybar_logo_transparent.png',
                height: 100,
              ),
              const Spacer(),
              Expanded(
                flex: 6,
                child: bannersAsync.when(
                  data: (banners) => banners.isEmpty
                      ? const _StaticHero()
                      : _OnboardingCarousel(banners: banners),
                  loading: () => const _StaticHero(),
                  error: (e, _) => const _StaticHero(),
                ),
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

class _OnboardingCarousel extends StatefulWidget {
  const _OnboardingCarousel({required this.banners});
  final List<PromoBanner> banners;

  @override
  State<_OnboardingCarousel> createState() => _OnboardingCarouselState();
}

class _OnboardingCarouselState extends State<_OnboardingCarousel> {
  late final PageController _controller;
  Timer? _timer;
  int _page = 0;

  @override
  void initState() {
    super.initState();
    _controller = PageController();
    // Auto-slide — swiping manually still works and resets nothing
    // special, it just changes which page this timer sees as current
    // on its next tick.
    _timer = Timer.periodic(const Duration(seconds: 4), (_) {
      if (!mounted || widget.banners.length <= 1) return;
      final next = (_page + 1) % widget.banners.length;
      _controller.animateToPage(
        next,
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeInOut,
      );
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Expanded(
          child: PageView.builder(
            controller: _controller,
            itemCount: widget.banners.length,
            onPageChanged: (i) => setState(() => _page = i),
            itemBuilder: (context, i) {
              final banner = widget.banners[i];
              return Column(
                children: [
                  Expanded(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(28),
                      child: Image.network(
                        banner.imageUrl,
                        fit: BoxFit.cover,
                        width: double.infinity,
                        errorBuilder: (_, __, ___) => const _StaticHero(),
                      ),
                    ),
                  ),
                  if (banner.title != null) ...[
                    const SizedBox(height: 20),
                    Text(
                      banner.title!,
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                            fontWeight: FontWeight.w700,
                            color: AppColors.ink,
                          ),
                    ),
                  ],
                  if (banner.description != null) ...[
                    const SizedBox(height: 8),
                    Text(
                      banner.description!,
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 14, color: Colors.grey[700]),
                    ),
                  ],
                ],
              );
            },
          ),
        ),
        if (widget.banners.length > 1) ...[
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              for (var i = 0; i < widget.banners.length; i++)
                AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  margin: const EdgeInsets.symmetric(horizontal: 3),
                  width: i == _page ? 18 : 6,
                  height: 6,
                  decoration: BoxDecoration(
                    color: i == _page ? AppColors.blue : Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
            ],
          ),
        ],
      ],
    );
  }
}

/// The original static brand panel — unchanged, kept as the fallback
/// for when no onboarding banners are configured (or the carousel
/// fails to load) so this screen is never empty/broken.
class _StaticHero extends StatelessWidget {
  const _StaticHero();

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
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
      ],
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
