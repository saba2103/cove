import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/cove_tokens.dart';

/// Horizontal snapping carousel for paper slips (`design/specs/12-carousel.md`).
///
/// Built to the contract in `design/specs/12-carousel.md`:
/// - **Single item**: renders full content width (`100%` inside
///   [CoveSpace.gutter] horizontal padding) with **no pager**.
/// - **Multiple items**:
///   - Item width is [kItemWidthRatio] (`82%`) of the content width
///     (`maxWidth - 2 * CoveSpace.gutter`) so the next item peeks.
///   - Leading inset is [CoveSpace.gutter] (`20dp`) so the first item aligns
///     with the page text.
///   - Gap between items is [CoveSpace.md] (`12dp`).
///   - Snaps to item, respecting [CoveMotion.q] and Reduce Motion
///     ([MediaQuery.disableAnimationsOf]).
///   - Pager below with [CoveSpace.md] (`12dp`) vertical gap: inactive dots
///     [kDotSize] × [kDotSize] (`6×6dp`) in `line.strong`; active dot
///     [kActiveDotWidth] × [kDotSize] (`20×6dp`) in `accent.fill`, pill radius
///     ([CoveRadius.pill]), with [CoveSpace.sm] (`8dp`) between dots.
///   - Pager dots are never tap targets; swiping and screen-reader next/previous
///     actions navigate and announce `"2 of 3"`.
class CoveCarousel extends StatefulWidget {
  final List<Widget> children;
  final int initialIndex;
  final ValueChanged<int>? onIndexChanged;

  static const double kItemWidthRatio =
      0.82; // (literal ratio) 82% of content width
  static const double kDotSize = 6.0; // (literal) dots 6x6dp
  static const double kActiveDotWidth = 20.0; // (literal) active dot 20x6dp

  const CoveCarousel({
    super.key,
    required this.children,
    this.initialIndex = 0,
    this.onIndexChanged,
  }) : assert(initialIndex >= 0, 'initialIndex must be non-negative.');

  @override
  State<CoveCarousel> createState() => _CoveCarouselState();
}

class _CoveCarouselState extends State<CoveCarousel> {
  ScrollController? _scrollController;
  late int _currentIndex;
  double _stepExtent = 0.0;

  @override
  void initState() {
    super.initState();
    _currentIndex = _clampIndex(widget.initialIndex);
  }

  @override
  void didUpdateWidget(CoveCarousel oldWidget) {
    super.didUpdateWidget(oldWidget);
    final clamped = _clampIndex(_currentIndex);
    if (clamped != _currentIndex) {
      _currentIndex = clamped;
    }
  }

  @override
  void dispose() {
    _scrollController?.removeListener(_handleScroll);
    _scrollController?.dispose();
    super.dispose();
  }

  int _clampIndex(int index) {
    if (widget.children.isEmpty) return 0;
    return index.clamp(0, widget.children.length - 1);
  }

  void _ensureController(double stepExtent) {
    if (_scrollController == null) {
      final initialOffset = _currentIndex * stepExtent;
      _scrollController = ScrollController(initialScrollOffset: initialOffset)
        ..addListener(_handleScroll);
      _stepExtent = stepExtent;
      return;
    }
    _stepExtent = stepExtent;
  }

  void _handleScroll() {
    final controller = _scrollController;
    if (controller == null || !controller.hasClients || _stepExtent <= 0) {
      return;
    }
    final rawIndex = (controller.offset / _stepExtent).round();
    final nextIndex = _clampIndex(rawIndex);
    if (nextIndex != _currentIndex) {
      setState(() => _currentIndex = nextIndex);
      widget.onIndexChanged?.call(nextIndex);
    }
  }

  Future<void> _goToIndex(int targetIndex) async {
    final nextIndex = _clampIndex(targetIndex);
    final controller = _scrollController;
    if (nextIndex != _currentIndex) {
      setState(() => _currentIndex = nextIndex);
      widget.onIndexChanged?.call(nextIndex);
    }
    if (controller == null || !controller.hasClients || _stepExtent <= 0) {
      return;
    }
    final targetOffset = (nextIndex * _stepExtent).clamp(
      controller.position.minScrollExtent,
      controller.position.maxScrollExtent,
    );
    final duration = CoveMotion.q(context);
    if (duration == Duration.zero) {
      controller.jumpTo(targetOffset);
    } else {
      await controller.animateTo(
        targetOffset,
        duration: duration,
        curve: CoveMotion.easing,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final count = widget.children.length;
    if (count == 0) {
      return const SizedBox.shrink();
    }

    // Rule: One item renders full-width with no pager.
    if (count == 1) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: CoveSpace.gutter),
        child: widget.children.first,
      );
    }

    final cv = context.cv;
    final disableAnimations = MediaQuery.disableAnimationsOf(context);
    final positionAnnouncement = '${_currentIndex + 1} of $count';

    return Semantics(
      container: true,
      liveRegion: true,
      value: positionAnnouncement,
      increasedValue:
          _currentIndex + 1 < count ? '${_currentIndex + 2} of $count' : null,
      decreasedValue: _currentIndex > 0 ? '$_currentIndex of $count' : null,
      onIncrease: _currentIndex + 1 < count
          ? () => _goToIndex(_currentIndex + 1)
          : null,
      onDecrease:
          _currentIndex > 0 ? () => _goToIndex(_currentIndex - 1) : null,
      onScrollLeft: _currentIndex + 1 < count
          ? () => _goToIndex(_currentIndex + 1)
          : null,
      onScrollRight:
          _currentIndex > 0 ? () => _goToIndex(_currentIndex - 1) : null,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final maxWidth = constraints.maxWidth.isFinite
              ? constraints.maxWidth
              : CoveSize.maxContent;
          final contentWidth = math.max(
            0.0,
            maxWidth - (CoveSpace.gutter * 2.0),
          );
          final itemWidth = contentWidth * CoveCarousel.kItemWidthRatio;
          final stepExtent = itemWidth + CoveSpace.md;
          final trailingInset = math.max(
            CoveSpace.gutter,
            maxWidth - CoveSpace.gutter - itemWidth,
          );

          _ensureController(stepExtent);

          return Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              ClipRect(
                clipper: const _HorizontalBoundsClipper(),
                child: SingleChildScrollView(
                  controller: _scrollController,
                  scrollDirection: Axis.horizontal,
                  clipBehavior: Clip.none,
                  physics: _CarouselSnapScrollPhysics(
                    stepExtent: stepExtent,
                    disableAnimations: disableAnimations,
                  ),
                  padding: EdgeInsets.only(
                    left: CoveSpace.gutter,
                    right: trailingInset,
                  ),
                  child: IntrinsicHeight(
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        for (var i = 0; i < count; i++) ...[
                          if (i > 0) const SizedBox(width: CoveSpace.md),
                          SizedBox(
                            key: ValueKey<String>('cove_carousel_item_$i'),
                            width: itemWidth,
                            child: widget.children[i],
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: CoveSpace.md),
              // Pager dots are purely visual indicators — never tap targets.
              IgnorePointer(
                child: ExcludeSemantics(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      for (var i = 0; i < count; i++) ...[
                        if (i > 0) const SizedBox(width: CoveSpace.sm),
                        AnimatedContainer(
                          key: ValueKey<String>('cove_carousel_dot_$i'),
                          duration: CoveMotion.q(context),
                          curve: CoveMotion.easing,
                          width: i == _currentIndex
                              ? CoveCarousel.kActiveDotWidth
                              : CoveCarousel.kDotSize,
                          height: CoveCarousel.kDotSize,
                          decoration: BoxDecoration(
                            color: i == _currentIndex
                                ? cv.accentFill
                                : cv.lineStrong,
                            borderRadius: const BorderRadius.all(
                              Radius.circular(CoveRadius.pill),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _CarouselSnapScrollPhysics extends ScrollPhysics {
  final double stepExtent;
  final bool disableAnimations;

  const _CarouselSnapScrollPhysics({
    required this.stepExtent,
    required this.disableAnimations,
    super.parent,
  });

  @override
  _CarouselSnapScrollPhysics applyTo(ScrollPhysics? ancestor) {
    return _CarouselSnapScrollPhysics(
      stepExtent: stepExtent,
      disableAnimations: disableAnimations,
      parent: buildParent(ancestor),
    );
  }

  double _getPage(ScrollMetrics position) {
    if (stepExtent <= 0) return 0.0;
    return position.pixels / stepExtent;
  }

  double _getPixels(ScrollMetrics position, double page) {
    return (page * stepExtent).clamp(
      position.minScrollExtent,
      position.maxScrollExtent,
    );
  }

  double _getTargetPixels(
    ScrollMetrics position,
    Tolerance tolerance,
    double velocity,
  ) {
    var page = _getPage(position);
    if (velocity < -tolerance.velocity) {
      page -= 0.5;
    } else if (velocity > tolerance.velocity) {
      page += 0.5;
    }
    return _getPixels(position, page.roundToDouble());
  }

  @override
  Simulation? createBallisticSimulation(
    ScrollMetrics position,
    double velocity,
  ) {
    if ((velocity <= 0.0 && position.pixels <= position.minScrollExtent) ||
        (velocity >= 0.0 && position.pixels >= position.maxScrollExtent)) {
      return super.createBallisticSimulation(position, velocity);
    }
    final tolerance = toleranceFor(position);
    final target = _getTargetPixels(position, tolerance, velocity);
    if (target != position.pixels) {
      if (disableAnimations) {
        return ScrollSpringSimulation(
          const SpringDescription(mass: 1.0, stiffness: 100000.0, damping: 1.0),
          position.pixels,
          target,
          0.0,
          tolerance: tolerance,
        );
      }
      return ScrollSpringSimulation(
        spring,
        position.pixels,
        target,
        velocity,
        tolerance: tolerance,
      );
    }
    return null;
  }

  @override
  bool get allowImplicitScrolling => false;
}

class _HorizontalBoundsClipper extends CustomClipper<Rect> {
  const _HorizontalBoundsClipper();

  @override
  Rect getClip(Size size) {
    return Rect.fromLTRB(
      0.0,
      -CoveSpace.xl,
      size.width,
      size.height + CoveSpace.xl,
    );
  }

  @override
  bool shouldReclip(covariant _HorizontalBoundsClipper oldClipper) => false;
}
