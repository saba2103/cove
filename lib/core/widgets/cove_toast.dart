import 'dart:async';
import 'package:flutter/material.dart';
import '../theme/cove_tokens.dart';
import 'cove_page_header.dart';

/// Data model for a single active [CoveToast] in [CoveToastHost].
@immutable
class CoveToastEntry {
  final String message;
  final String undoLabel;
  final VoidCallback? onUndo;

  const CoveToastEntry({
    required this.message,
    this.undoLabel = 'Undo',
    this.onUndo,
  });
}

/// The brief confirmation pill, usually carrying an Undo (`design/specs/08-toast.md`).
///
/// Built to the contract in `design/specs/08-toast.md`:
/// - Position: below the status-bar inset AND any page header, above the
///   content acted on (`inset + CovePageHeader.kMinHeight + CoveSpace.md`).
/// - Padding: [CoveSpace.sm] (`8dp`) vertical, [CoveSpace.gutter] (`20dp`)
///   horizontal.
/// - Radius: [CoveRadius.pill] (`999dp`).
/// - Fill: `surface.row`, `1dp` `accent.fill` border.
/// - Text: [CoveType.readout] in `text.primary`.
/// - Undo: `accent.text`, a real button with a [CoveSize.hit] (`48dp`) tap
///   target that does not grow the drawn pill height.
/// - WCAG 2.2.1: pauses auto-dismiss while focused, and extends timeout when a
///   screen reader (`MediaQuery.accessibleNavigationOf`) is active.
/// - One at a time: a second toast replaces the first; they never stack.
class CoveToast extends StatefulWidget {
  final String message;
  final String undoLabel;
  final VoidCallback? onUndo;
  final ValueChanged<bool>? onFocusChanged;

  static const double kBorderWidth = 1.0; // (literal) 1dp accent.fill border
  static const double _kSingleLinePillHeight =
      36.0; // 8dp top + 18dp readout + 8dp bottom + 2dp border
  static const double kHitBleed =
      (CoveSize.hit - _kSingleLinePillHeight) / 2; // 6.0dp vertical hit ring
  static const Duration kDefaultDuration = Duration(seconds: 4);
  static const Duration kAccessibleUndoDuration = Duration(seconds: 20);

  const CoveToast({
    super.key,
    required this.message,
    this.undoLabel = 'Undo',
    this.onUndo,
    this.onFocusChanged,
  });

  /// Device-anchored top offset (`inset + header height + CoveSpace.md`) per
  /// `design/specs/08-toast.md`.
  static double topOffsetFor(BuildContext context) {
    return CovePageInsets.topOf(context) +
        CovePageHeader.kMinHeight +
        CoveSpace.md;
  }

  /// Resolves the auto-dismiss duration per WCAG 2.2.1 (`design/specs/08-toast.md`).
  ///
  /// Returns `null` (paused) when an Undo action is present and focused, and
  /// extends to [kAccessibleUndoDuration] (`20s`) when an Undo is present and
  /// `MediaQuery.accessibleNavigationOf(context)` is active.
  static Duration? effectiveDurationFor({
    required bool hasUndo,
    required bool accessibleNavigation,
    required bool hasFocus,
  }) {
    if (hasUndo && hasFocus) {
      return null;
    }
    if (hasUndo && accessibleNavigation) {
      return kAccessibleUndoDuration;
    }
    return kDefaultDuration;
  }

  @override
  State<CoveToast> createState() => _CoveToastState();
}

class _CoveToastState extends State<CoveToast> {
  bool _undoPressed = false;

  @override
  Widget build(BuildContext context) {
    final cv = context.cv;
    final hasUndo = widget.onUndo != null;

    final Widget drawnPill = Container(
      key: const ValueKey('cove_toast_pill'),
      padding: const EdgeInsets.symmetric(
        vertical: CoveSpace.sm,
        horizontal: CoveSpace.gutter,
      ),
      decoration: BoxDecoration(
        color: cv.surfaceRow,
        borderRadius: const BorderRadius.all(
          Radius.circular(CoveRadius.pill),
        ),
        border: Border.all(
          color: cv.accentFill,
          width: CoveToast.kBorderWidth,
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              widget.message,
              style: CoveType.readout.copyWith(color: cv.textPrimary),
            ),
          ),
          if (hasUndo) ...[
            const SizedBox(width: CoveSpace.md),
            IgnorePointer(
              child: Text(
                widget.undoLabel,
                style: CoveType.readout.copyWith(
                  color: _undoPressed ? cv.accentTint : cv.accentText,
                ),
              ),
            ),
          ],
        ],
      ),
    );

    if (!hasUndo) {
      return Semantics(
        liveRegion: true,
        child: drawnPill,
      );
    }

    return Semantics(
      liveRegion: true,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: CoveSize.hit),
        child: Stack(
          alignment: Alignment.center,
          children: [
            drawnPill,
            Positioned(
              right: 0,
              top: 0,
              bottom: 0,
              child: Focus(
                onFocusChange: widget.onFocusChanged,
                child: Semantics(
                  button: true,
                  label: widget.undoLabel,
                  child: GestureDetector(
                    key: const ValueKey('cove_toast_undo'),
                    behavior: HitTestBehavior.opaque,
                    onTap: widget.onUndo,
                    onTapDown: (_) => setState(() => _undoPressed = true),
                    onTapUp: (_) => setState(() => _undoPressed = false),
                    onTapCancel: () => setState(() => _undoPressed = false),
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(
                        minWidth: CoveSize.hit,
                        minHeight: CoveSize.hit,
                      ),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: CoveSpace.gutter,
                        ),
                        child: Center(
                          child: Opacity(
                            opacity: 0.0,
                            child: Text(
                              widget.undoLabel,
                              style: CoveType.readout,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Host overlay that positions at most one [CoveToast] at
/// `inset + CovePageHeader.kMinHeight + CoveSpace.md` (`design/specs/08-toast.md`).
///
/// Showing a second toast replaces the first immediately so toasts never stack.
/// When an Undo action is present, auto-dismiss pauses on focus and extends
/// when `MediaQuery.accessibleNavigationOf(context)` is active (WCAG 2.2.1).
class CoveToastHost extends StatefulWidget {
  final Widget child;
  final CoveToastEntry? initialToast;
  final bool autoDismiss;

  const CoveToastHost({
    super.key,
    required this.child,
    this.initialToast,
    this.autoDismiss = true,
  });

  static CoveToastHostState? maybeOf(BuildContext context) {
    return context.findAncestorStateOfType<CoveToastHostState>();
  }

  @override
  State<CoveToastHost> createState() => CoveToastHostState();
}

class CoveToastHostState extends State<CoveToastHost> {
  CoveToastEntry? _active;
  Timer? _timer;
  bool _hasFocus = false;

  CoveToastEntry? get activeToast => _active;

  @override
  void initState() {
    super.initState();
    _active = widget.initialToast;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (widget.autoDismiss && _active != null && _timer == null && !_hasFocus) {
      _scheduleAutoDismiss();
    }
  }

  /// Displays [entry], replacing any currently visible toast immediately.
  void show(CoveToastEntry entry) {
    _timer?.cancel();
    setState(() {
      _active = entry;
      _hasFocus = false;
    });
    if (widget.autoDismiss) {
      _scheduleAutoDismiss();
    }
  }

  /// Dismisses the active toast if one is visible.
  void dismiss() {
    _timer?.cancel();
    _timer = null;
    if (_active != null && mounted) {
      setState(() {
        _active = null;
        _hasFocus = false;
      });
    }
  }

  void _handleFocusChanged(bool focused) {
    if (_hasFocus == focused) return;
    setState(() => _hasFocus = focused);
    if (focused) {
      _timer?.cancel();
      _timer = null;
    } else if (_active != null && widget.autoDismiss) {
      _scheduleAutoDismiss();
    }
  }

  void _scheduleAutoDismiss() {
    _timer?.cancel();
    _timer = null;
    final entry = _active;
    if (entry == null || !mounted || !widget.autoDismiss) return;

    final accessible = MediaQuery.accessibleNavigationOf(context);
    final duration = CoveToast.effectiveDurationFor(
      hasUndo: entry.onUndo != null,
      accessibleNavigation: accessible,
      hasFocus: _hasFocus,
    );
    if (duration != null) {
      _timer = Timer(duration, dismiss);
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final entry = _active;
    final hasUndo = entry?.onUndo != null;
    final topOffset = CoveToast.topOffsetFor(context) -
        (hasUndo ? CoveToast.kHitBleed : 0.0);

    return Stack(
      fit: StackFit.expand,
      children: [
        widget.child,
        if (entry != null)
          Positioned(
            top: topOffset,
            left: CoveSpace.gutter,
            right: CoveSpace.gutter,
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(
                  maxWidth: CoveSize.maxContent,
                ),
                child: CoveToast(
                  key: ValueKey('active_toast_${entry.message}'),
                  message: entry.message,
                  undoLabel: entry.undoLabel,
                  onUndo: entry.onUndo == null
                      ? null
                      : () {
                          final callback = entry.onUndo!;
                          dismiss();
                          callback();
                        },
                  onFocusChanged: _handleFocusChanged,
                ),
              ),
            ),
          ),
      ],
    );
  }
}
