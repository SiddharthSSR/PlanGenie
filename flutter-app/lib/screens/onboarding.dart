import 'package:flutter/material.dart';

import 'package:plangenie/src/features/auth/login_screen.dart';
import 'package:plangenie/src/features/auth/signup_screen.dart';

const _gradientStart = Color(0xFF0B1120);
const _gradientMiddle = Color(0xFF1E3A8A);
const _gradientEnd = Color(0xFF3B82F6);

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  late final PageController _pageController;
  int _currentPage = 0;
  double _pageOffset = 0.0;

  // TODO: Record user Travel DNA preferences to Firestore when collecting onboarding responses.
  final List<_OnboardingContent> _pages = const [
    _OnboardingContent(
      title: 'Travel DNA',
      body:
          'Understand your travel DNA with curated journeys tailored to how you like to explore.',
      icon: Icons.fingerprint,
      accentColor: Color(0xFF60A5FA),
      semanticLabel: 'Travel DNA onboarding highlight',
    ),
    _OnboardingContent(
      title: 'Adaptive Itinerary',
      body:
          'Watch your plan adapt in real-time as plans shift, crowds swell, or weather calls for a pivot.',
      icon: Icons.auto_awesome,
      accentColor: Color(0xFF8B5CF6),
      semanticLabel: 'Adaptive itinerary onboarding highlight',
    ),
    _OnboardingContent(
      title: 'Hidden Gems',
      body:
          'Unlock hyperlocal tips and hidden gems surfaced by our AI scouts before anyone else.',
      icon: Icons.spa,
      accentColor: Color(0xFF34D399),
      semanticLabel: 'Hidden gems onboarding highlight',
    ),
    _OnboardingContent(
      title: 'Seamless Booking',
      body:
          'Reserve stays, experiences, and transport in a single flow without breaking your planning zone.',
      icon: Icons.event_available,
      accentColor: Color(0xFFF59E0B),
      semanticLabel: 'Seamless booking onboarding highlight',
    ),
    _OnboardingContent(
      title: 'Map-First UI',
      body:
          'Navigate your itinerary through an immersive, map-first interface built for spatial thinkers.',
      icon: Icons.map_outlined,
      accentColor: Color(0xFF38BDF8),
      semanticLabel: 'Map-first UI onboarding highlight',
    ),
  ];

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
    _pageOffset = _pageController.initialPage.toDouble();
    _pageController.addListener(_handleScroll);
  }

  @override
  void dispose() {
    _pageController.removeListener(_handleScroll);
    _pageController.dispose();
    super.dispose();
  }

  void _handleScroll() {
    if (!mounted) {
      return;
    }
    setState(() {
      _pageOffset = _pageController.hasClients
          ? _pageController.page ?? _currentPage.toDouble()
          : _currentPage.toDouble();
    });
  }

  void _handlePrimaryAction() {
    if (_currentPage < _pages.length - 1) {
      _pageController.animateToPage(
        _currentPage + 1,
        duration: const Duration(milliseconds: 450),
        curve: Curves.easeOutCubic,
      );
      return;
    }

    // TODO: Persist onboarding completion status via SharedPreferences or Firestore.
    // TODO: Hook onboarding completion into Firebase Auth profile creation once sign-up is implemented.
    _openSignUp();
  }

  void _openLogin() {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const LoginScreen()),
    );
  }

  void _openSignUp() {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const SignUpScreen()),
    );
  }

  LinearGradient _backgroundForProgress(double progress) {
    final clamped = progress.clamp(0.0, 1.0);
    final topColor =
        Color.lerp(_gradientStart, _gradientMiddle, clamped) ?? _gradientStart;
    final bottomColor =
        Color.lerp(_gradientMiddle, _gradientEnd, clamped) ?? _gradientEnd;

    return LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [topColor, bottomColor],
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isLastPage = _currentPage == _pages.length - 1;
    final double clampedPage =
        _pages.length <= 1 ? 0.0 : _pageOffset.clamp(0.0, _pages.length - 1);
    final double scrollProgress =
        _pages.length <= 1 ? 0.0 : clampedPage / (_pages.length - 1);

    final backgroundGradient = _backgroundForProgress(scrollProgress);

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: backgroundGradient,
        ),
        child: Stack(
          children: [
            PageView.builder(
              controller: _pageController,
              physics: const BouncingScrollPhysics(parent: PageScrollPhysics()),
              scrollDirection: Axis.vertical,
              onPageChanged: (index) => setState(() => _currentPage = index),
              itemCount: _pages.length,
              itemBuilder: (context, index) {
                final content = _pages[index];
                final offset = _pageOffset - index;
                final activation = (1 - offset.abs()).clamp(0.0, 1.0);
                return _OnboardingPage(
                  content: content,
                  offset: offset,
                  activation: activation,
                );
              },
            ),
            SafeArea(
              child: Stack(
                children: [
                  Positioned(
                    top: 16,
                    right: 24,
                    child: Semantics(
                      button: true,
                      label: 'Log in',
                      child: GestureDetector(
                        onTap: _openLogin,
                        behavior: HitTestBehavior.opaque,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 6,
                          ),
                          child: Text(
                            'Log in',
                            style: theme.textTheme.labelLarge?.copyWith(
                              color: Colors.white.withValues(alpha: 0.92),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    left: 20,
                    right: 20,
                    bottom: 32,
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Expanded(
                          child: Semantics(
                            button: true,
                            label: isLastPage
                                ? 'Get started with PlanGenie'
                                : 'Go to next onboarding page',
                            child: TextButton(
                              onPressed: _handlePrimaryAction,
                              style: TextButton.styleFrom(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 18,
                                ),
                                backgroundColor:
                                    Colors.white.withValues(alpha: 0.12),
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(18),
                                ),
                              ),
                              child: Text(isLastPage ? 'Get started' : 'Next'),
                            ),
                          ),
                        ),
                        const SizedBox(width: 24),
                        _PageIndicator(
                          length: _pages.length,
                          currentIndex: _currentPage,
                          pageOffset: _pageOffset,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _OnboardingPage extends StatelessWidget {
  const _OnboardingPage({
    required this.content,
    required this.offset,
    required this.activation,
  });

  final _OnboardingContent content;
  final double offset;
  final double activation;

  @override
  Widget build(BuildContext context) {
    final double clampedOffset = offset.clamp(-1.0, 1.0);
    final double iconParallax = clampedOffset * -32;
    final double textParallax = clampedOffset * 10;
    final double opacity = (1 - clampedOffset.abs()).clamp(0.0, 1.0);

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Transform.translate(
              offset: Offset(0, iconParallax),
              child: _AnimatedFeatureIcon(
                icon: content.icon,
                accentColor: content.accentColor,
                activation: activation,
              ),
            ),
            const SizedBox(height: 48),
            AnimatedOpacity(
              duration: const Duration(milliseconds: 260),
              opacity: opacity,
              child: AnimatedSlide(
                duration: const Duration(milliseconds: 320),
                curve: Curves.easeOutCubic,
                offset: Offset(0, textParallax / 72),
                child: _OnboardingTextBlock(content: content),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _OnboardingTextBlock extends StatelessWidget {
  const _OnboardingTextBlock({required this.content});

  final _OnboardingContent content;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    const onPrimary = Colors.white;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Semantics(
          header: true,
          label: content.semanticLabel,
          child: Text(
            content.title,
            textAlign: TextAlign.center,
            style:
                (textTheme.displaySmall ?? textTheme.headlineMedium)?.copyWith(
              color: onPrimary,
              fontWeight: FontWeight.w700,
              height: 1.08,
              letterSpacing: -0.5,
            ),
          ),
        ),
        const SizedBox(height: 18),
        Text(
          content.body,
          textAlign: TextAlign.center,
          style: (textTheme.bodyLarge ?? const TextStyle()).copyWith(
            color: onPrimary.withValues(alpha: 0.88),
            height: 1.55,
            fontWeight: FontWeight.w400,
          ),
          semanticsLabel: content.body,
        ),
      ],
    );
  }
}

class _AnimatedFeatureIcon extends StatelessWidget {
  const _AnimatedFeatureIcon({
    required this.icon,
    required this.accentColor,
    required this.activation,
  });

  final IconData icon;
  final Color accentColor;
  final double activation;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0, end: activation.clamp(0.0, 1.0)),
      duration: const Duration(milliseconds: 600),
      curve: Curves.easeOutCubic,
      builder: (context, value, child) {
        final fill = value.clamp(0.0, 1.0);
        final baseColor = Colors.white.withValues(alpha: 0.18);
        final iconColor = Color.lerp(baseColor, accentColor, fill) ?? baseColor;

        return Transform.scale(
          scale: 0.94 + (0.06 * fill),
          child: Icon(
            icon,
            size: 160,
            color: iconColor,
          ),
        );
      },
    );
  }
}

class _PageIndicator extends StatelessWidget {
  const _PageIndicator({
    required this.length,
    required this.currentIndex,
    required this.pageOffset,
  });

  final int length;
  final int currentIndex;
  final double pageOffset;

  @override
  Widget build(BuildContext context) {
    final double effectiveOffset =
        pageOffset.isNaN ? currentIndex.toDouble() : pageOffset;

    // TODO: Consider using smooth_page_indicator for richer indicator animations.
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(length, (index) {
        final double t = (1 - (effectiveOffset - index).abs()).clamp(0.0, 1.0);
        final double height = 10 + (14 * t);
        final double width = 8 + (4 * t);
        final Color color = Color.lerp(
              Colors.white.withValues(alpha: 0.25),
              Colors.white,
              t,
            ) ??
            Colors.white;

        return AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOut,
          margin: const EdgeInsets.symmetric(vertical: 4),
          width: width,
          height: height,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              if (index == currentIndex)
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.1 * t),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
            ],
          ),
        );
      }),
    );
  }
}

class _OnboardingContent {
  const _OnboardingContent({
    required this.title,
    required this.body,
    required this.icon,
    required this.accentColor,
    required this.semanticLabel,
  });

  final String title;
  final String body;
  final IconData icon;
  final Color accentColor;
  final String semanticLabel;
}
