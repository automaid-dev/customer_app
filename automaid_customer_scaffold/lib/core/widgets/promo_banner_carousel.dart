import 'dart:async';

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/promo_banner_model.dart';

/// Auto-scrolling image carousel for admin-managed promotional banners
/// (see Banner::class on the backend) — tapping a banner opens its
/// link, if it has one. Renders nothing at all if the list is empty,
/// so a dashboard with no active banners configured looks exactly like
/// it did before this feature existed.
///
/// Auto-slide: each banner stays up for [interval] (6 s by default — long
/// enough to read a headline and a line of text), then slides to the next
/// and wraps around to the first. The timer pauses while the customer is
/// touching or swiping the banner, restarts the full interval after a
/// manual swipe, and stops while the app is in the background.
class PromoBannerCarousel extends StatefulWidget {
  const PromoBannerCarousel({
    super.key,
    required this.banners,
    this.height = 160,
    this.interval = const Duration(seconds: 6),
  });
  final List<PromoBanner> banners;
  final double height;
  final Duration interval;

  @override
  State<PromoBannerCarousel> createState() => _PromoBannerCarouselState();
}

class _PromoBannerCarouselState extends State<PromoBannerCarousel> with WidgetsBindingObserver {
  late final PageController _controller;
  int _page = 0;
  Timer? _timer;
  bool _touching = false;

  @override
  void initState() {
    super.initState();
    _controller = PageController();
    WidgetsBinding.instance.addObserver(this);
    _restartTimer();
  }

  @override
  void didUpdateWidget(covariant PromoBannerCarousel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.banners.length != widget.banners.length) {
      if (_page >= widget.banners.length) _page = 0;
      _restartTimer();
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _restartTimer();
    } else {
      _timer?.cancel();
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    _controller.dispose();
    super.dispose();
  }

  /// (Re)starts the countdown for the banner currently showing.
  void _restartTimer() {
    _timer?.cancel();
    if (widget.banners.length < 2 || _touching) return;
    _timer = Timer(widget.interval, _next);
  }

  void _next() {
    if (!mounted || _touching || !_controller.hasClients || widget.banners.length < 2) return;
    // Only slide when this screen is the one on top (not behind a pushed route).
    if (ModalRoute.of(context)?.isCurrent == false) {
      _restartTimer();
      return;
    }
    final next = (_page + 1) % widget.banners.length;
    _controller.animateToPage(
      next,
      duration: Duration(milliseconds: next == 0 ? 700 : 450),
      curve: Curves.easeInOut,
    );
    // onPageChanged restarts the timer once the slide lands.
  }

  Future<void> _openLink(String? link) async {
    if (link == null) return;
    final uri = Uri.tryParse(link);
    if (uri == null) return;
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.banners.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          height: widget.height,
          child: Listener(
            // Hold the banner still while a finger is on it.
            onPointerDown: (_) {
              _touching = true;
              _timer?.cancel();
            },
            onPointerUp: (_) {
              _touching = false;
              _restartTimer();
            },
            onPointerCancel: (_) {
              _touching = false;
              _restartTimer();
            },
            child: PageView.builder(
            controller: _controller,
            itemCount: widget.banners.length,
            onPageChanged: (i) {
              setState(() => _page = i);
              _restartTimer();
            },
            itemBuilder: (context, i) {
              final banner = widget.banners[i];
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: GestureDetector(
                  onTap: () => _openLink(banner.link),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.network(
                      banner.imageUrl,
                      fit: BoxFit.cover,
                      width: double.infinity,
                      errorBuilder: (_, __, ___) => Container(color: Colors.grey.shade200),
                    ),
                  ),
                ),
              );
            },
          ),
          ),
        ),
        if (widget.banners.length > 1) ...[
          const SizedBox(height: 8),
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
                    color: i == _page ? Theme.of(context).colorScheme.primary : Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
            ],
          ),
        ],
        // Caption for whichever banner is currently showing — matches
        // the reference design's "New Promotion!!" text under the image.
        if (_page < widget.banners.length && widget.banners[_page].title != null) ...[
          const SizedBox(height: 6),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Text(
              widget.banners[_page].title!,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ),
        ],
      ],
    );
  }
}
