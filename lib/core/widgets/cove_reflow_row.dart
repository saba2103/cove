import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import '../theme/cove_tokens.dart';

enum _CoveReflowSlot {
  leading,
  body,
  trailing,
}

/// Adaptive side-by-side row that behaves identically to a horizontal [Row] at
/// default text scale (`<= 1.0`) and reflows wide trailing content below [body]
/// at enlarged accessibility text scales (`> 1.0`) when inline space is tight.
class CoveReflowRow extends RenderObjectWidget {
  final Widget? leading;
  final Widget body;
  final Widget? trailing;
  final double leadingGap;
  final double trailingGap;
  final double stackGap;
  final bool allowStack;
  final bool forceStack;
  final double maxInlineTrailingFraction;
  final double minInlineBodyWidth;

  const CoveReflowRow({
    super.key,
    this.leading,
    required this.body,
    this.trailing,
    this.leadingGap = CoveSpace.md,
    this.trailingGap = CoveSpace.md,
    this.stackGap = CoveSpace.xs,
    this.allowStack = false,
    this.forceStack = false,
    this.maxInlineTrailingFraction = 0.36,
    this.minInlineBodyWidth = 172.0,
  });

  @override
  RenderObjectElement createElement() => _CoveReflowRowElement(this);

  @override
  RenderObject createRenderObject(BuildContext context) {
    return _RenderCoveReflowRow(
      leadingGap: leadingGap,
      trailingGap: trailingGap,
      stackGap: stackGap,
      allowStack: allowStack,
      forceStack: forceStack,
      maxInlineTrailingFraction: maxInlineTrailingFraction,
      minInlineBodyWidth: minInlineBodyWidth,
    );
  }

  @override
  void updateRenderObject(
    BuildContext context,
    RenderObject renderObject,
  ) {
    (renderObject as _RenderCoveReflowRow)
      ..leadingGap = leadingGap
      ..trailingGap = trailingGap
      ..stackGap = stackGap
      ..allowStack = allowStack
      ..forceStack = forceStack
      ..maxInlineTrailingFraction = maxInlineTrailingFraction
      ..minInlineBodyWidth = minInlineBodyWidth;
  }
}

class _CoveReflowRowElement extends RenderObjectElement {
  Element? _leading;
  Element? _body;
  Element? _trailing;

  _CoveReflowRowElement(CoveReflowRow super.widget);

  @override
  CoveReflowRow get widget => super.widget as CoveReflowRow;

  @override
  _RenderCoveReflowRow get renderObject =>
      super.renderObject as _RenderCoveReflowRow;

  @override
  void visitChildren(ElementVisitor visitor) {
    if (_leading != null) visitor(_leading!);
    if (_body != null) visitor(_body!);
    if (_trailing != null) visitor(_trailing!);
  }

  @override
  void forgetChild(Element child) {
    if (child == _leading) _leading = null;
    if (child == _body) _body = null;
    if (child == _trailing) _trailing = null;
    super.forgetChild(child);
  }

  @override
  void mount(Element? parent, Object? newSlot) {
    super.mount(parent, newSlot);
    _leading = updateChild(_leading, widget.leading, _CoveReflowSlot.leading);
    _body = updateChild(_body, widget.body, _CoveReflowSlot.body);
    _trailing =
        updateChild(_trailing, widget.trailing, _CoveReflowSlot.trailing);
  }

  @override
  void update(CoveReflowRow newWidget) {
    super.update(newWidget);
    _leading = updateChild(_leading, widget.leading, _CoveReflowSlot.leading);
    _body = updateChild(_body, widget.body, _CoveReflowSlot.body);
    _trailing =
        updateChild(_trailing, widget.trailing, _CoveReflowSlot.trailing);
  }

  @override
  void insertRenderObjectChild(RenderObject child, _CoveReflowSlot slot) {
    final box = child as RenderBox;
    switch (slot) {
      case _CoveReflowSlot.leading:
        renderObject.leading = box;
      case _CoveReflowSlot.body:
        renderObject.body = box;
      case _CoveReflowSlot.trailing:
        renderObject.trailing = box;
    }
  }

  @override
  void moveRenderObjectChild(
    RenderObject child,
    _CoveReflowSlot oldSlot,
    _CoveReflowSlot newSlot,
  ) {
    assert(false, 'Slots in CoveReflowRow never move.');
  }

  @override
  void removeRenderObjectChild(RenderObject child, _CoveReflowSlot slot) {
    switch (slot) {
      case _CoveReflowSlot.leading:
        if (renderObject.leading == child) renderObject.leading = null;
      case _CoveReflowSlot.body:
        if (renderObject.body == child) renderObject.body = null;
      case _CoveReflowSlot.trailing:
        if (renderObject.trailing == child) renderObject.trailing = null;
    }
  }
}

class _RenderCoveReflowRow extends RenderBox {
  RenderBox? _leading;
  RenderBox? _body;
  RenderBox? _trailing;

  double _leadingGapPx;
  double _trailingGapPx;
  double _stackGapPx;
  bool _allowStackFlag;
  bool _forceStackFlag;
  double _maxInlineTrailingFrac;
  double _minInlineBodyWidthPx;

  _RenderCoveReflowRow({
    required double leadingGap,
    required double trailingGap,
    required double stackGap,
    required bool allowStack,
    required bool forceStack,
    required double maxInlineTrailingFraction,
    required double minInlineBodyWidth,
  }) : _leadingGapPx = leadingGap,
       _trailingGapPx = trailingGap,
       _stackGapPx = stackGap,
       _allowStackFlag = allowStack,
       _forceStackFlag = forceStack,
       _maxInlineTrailingFrac = maxInlineTrailingFraction,
       _minInlineBodyWidthPx = minInlineBodyWidth;

  void _setChild(RenderBox? oldChild, RenderBox? newChild) {
    if (oldChild != null) dropChild(oldChild);
    if (newChild != null) {
      newChild.parentData = BoxParentData();
      adoptChild(newChild);
    }
  }

  RenderBox? get leading => _leading;
  set leading(RenderBox? value) {
    if (_leading == value) return;
    _setChild(_leading, value);
    _leading = value;
    markNeedsLayout();
  }

  RenderBox? get body => _body;
  set body(RenderBox? value) {
    if (_body == value) return;
    _setChild(_body, value);
    _body = value;
    markNeedsLayout();
  }

  RenderBox? get trailing => _trailing;
  set trailing(RenderBox? value) {
    if (_trailing == value) return;
    _setChild(_trailing, value);
    _trailing = value;
    markNeedsLayout();
  }

  set leadingGap(double value) {
    if (_leadingGapPx == value) return;
    _leadingGapPx = value;
    markNeedsLayout();
  }

  set trailingGap(double value) {
    if (_trailingGapPx == value) return;
    _trailingGapPx = value;
    markNeedsLayout();
  }

  set stackGap(double value) {
    if (_stackGapPx == value) return;
    _stackGapPx = value;
    markNeedsLayout();
  }

  set allowStack(bool value) {
    if (_allowStackFlag == value) return;
    _allowStackFlag = value;
    markNeedsLayout();
  }

  set forceStack(bool value) {
    if (_forceStackFlag == value) return;
    _forceStackFlag = value;
    markNeedsLayout();
  }

  set maxInlineTrailingFraction(double value) {
    if (_maxInlineTrailingFrac == value) return;
    _maxInlineTrailingFrac = value;
    markNeedsLayout();
  }

  set minInlineBodyWidth(double value) {
    if (_minInlineBodyWidthPx == value) return;
    _minInlineBodyWidthPx = value;
    markNeedsLayout();
  }

  @override
  void attach(PipelineOwner owner) {
    super.attach(owner);
    _leading?.attach(owner);
    _body?.attach(owner);
    _trailing?.attach(owner);
  }

  @override
  void detach() {
    super.detach();
    _leading?.detach();
    _body?.detach();
    _trailing?.detach();
  }

  @override
  void visitChildren(RenderObjectVisitor visitor) {
    if (_leading != null) visitor(_leading!);
    if (_body != null) visitor(_body!);
    if (_trailing != null) visitor(_trailing!);
  }

  @override
  Size computeDryLayout(BoxConstraints constraints) {
    final bodyChild = _body;
    if (bodyChild == null) return constraints.smallest;

    final hasBoundedW = constraints.hasBoundedWidth;
    final maxW = hasBoundedW ? constraints.maxWidth : double.infinity;

    Size leadSize = Size.zero;
    if (_leading != null) {
      leadSize = _leading!.getDryLayout(BoxConstraints(maxWidth: maxW));
    }
    final leadOffset = _leading != null ? leadSize.width + _leadingGapPx : 0.0;
    final availAfterLead = math.max(0.0, maxW - leadOffset);

    if (_trailing == null) {
      final bodySize = bodyChild.getDryLayout(
        BoxConstraints(
          minWidth: hasBoundedW ? availAfterLead : 0.0,
          maxWidth: availAfterLead,
        ),
      );
      final totalW = hasBoundedW ? maxW : leadOffset + bodySize.width;
      final totalH = math.max(leadSize.height, bodySize.height);
      return constraints.constrain(Size(totalW, totalH));
    }

    final trailSize = _trailing!.getDryLayout(
      BoxConstraints(maxWidth: availAfterLead),
    );
    final bodyInlineAvail = availAfterLead - trailSize.width - _trailingGapPx;
    final shouldStack = _allowStackFlag &&
        hasBoundedW &&
        (_forceStackFlag ||
            trailSize.width > availAfterLead * _maxInlineTrailingFrac ||
            bodyInlineAvail < _minInlineBodyWidthPx);

    if (shouldStack) {
      final bodySize = bodyChild.getDryLayout(
        BoxConstraints(minWidth: availAfterLead, maxWidth: availAfterLead),
      );
      final stackedH = bodySize.height + _stackGapPx + trailSize.height;
      final totalH = math.max(leadSize.height, stackedH);
      return constraints.constrain(Size(maxW, totalH));
    }

    final clampedBodyW = math.max(0.0, bodyInlineAvail);
    final bodySize = bodyChild.getDryLayout(
      BoxConstraints(
        minWidth: hasBoundedW ? clampedBodyW : 0.0,
        maxWidth: clampedBodyW,
      ),
    );
    final totalW = hasBoundedW
        ? maxW
        : leadOffset + bodySize.width + _trailingGapPx + trailSize.width;
    final totalH = math.max(
      leadSize.height,
      math.max(bodySize.height, trailSize.height),
    );
    return constraints.constrain(Size(totalW, totalH));
  }

  @override
  void performLayout() {
    final bodyChild = _body;
    if (bodyChild == null) {
      size = constraints.smallest;
      return;
    }

    final hasBoundedW = constraints.hasBoundedWidth;
    final maxW = hasBoundedW ? constraints.maxWidth : double.infinity;

    Size leadSize = Size.zero;
    if (_leading != null) {
      _leading!.layout(BoxConstraints(maxWidth: maxW), parentUsesSize: true);
      leadSize = _leading!.size;
    }
    final leadOffset = _leading != null ? leadSize.width + _leadingGapPx : 0.0;
    final availAfterLead = math.max(0.0, maxW - leadOffset);

    if (_trailing == null) {
      bodyChild.layout(
        BoxConstraints(
          minWidth: hasBoundedW ? availAfterLead : 0.0,
          maxWidth: availAfterLead,
        ),
        parentUsesSize: true,
      );
      final bodySize = bodyChild.size;
      final totalW = hasBoundedW ? maxW : leadOffset + bodySize.width;
      final totalH = math.max(leadSize.height, bodySize.height);
      size = constraints.constrain(Size(totalW, totalH));

      if (_leading != null) {
        (_leading!.parentData! as BoxParentData).offset = Offset(
          0.0,
          (size.height - leadSize.height) / 2.0,
        );
      }
      (bodyChild.parentData! as BoxParentData).offset = Offset(
        leadOffset,
        (size.height - bodySize.height) / 2.0,
      );
      return;
    }

    _trailing!.layout(
      BoxConstraints(maxWidth: availAfterLead),
      parentUsesSize: true,
    );
    final trailSize = _trailing!.size;

    final bodyInlineAvail = availAfterLead - trailSize.width - _trailingGapPx;
    final shouldStack = _allowStackFlag &&
        hasBoundedW &&
        (_forceStackFlag ||
            trailSize.width > availAfterLead * _maxInlineTrailingFrac ||
            bodyInlineAvail < _minInlineBodyWidthPx);

    if (shouldStack) {
      bodyChild.layout(
        BoxConstraints(minWidth: availAfterLead, maxWidth: availAfterLead),
        parentUsesSize: true,
      );
      final bodySize = bodyChild.size;
      final stackedH = bodySize.height + _stackGapPx + trailSize.height;
      final totalH = math.max(leadSize.height, stackedH);
      size = constraints.constrain(Size(maxW, totalH));

      if (_leading != null) {
        final anchorH = math.min(
          size.height,
          math.max(leadSize.height, CoveSize.row - CoveSpace.sm),
        );
        (_leading!.parentData! as BoxParentData).offset = Offset(
          0.0,
          math.max(0.0, (anchorH - leadSize.height) / 2.0),
        );
      }
      (bodyChild.parentData! as BoxParentData).offset = Offset(
        leadOffset,
        0.0,
      );
      (_trailing!.parentData! as BoxParentData).offset = Offset(
        leadOffset,
        bodySize.height + _stackGapPx,
      );
      return;
    }

    final clampedBodyW = math.max(0.0, bodyInlineAvail);
    bodyChild.layout(
      BoxConstraints(
        minWidth: hasBoundedW ? clampedBodyW : 0.0,
        maxWidth: clampedBodyW,
      ),
      parentUsesSize: true,
    );
    final bodySize = bodyChild.size;
    final totalW = hasBoundedW
        ? maxW
        : leadOffset + bodySize.width + _trailingGapPx + trailSize.width;
    final totalH = math.max(
      leadSize.height,
      math.max(bodySize.height, trailSize.height),
    );
    size = constraints.constrain(Size(totalW, totalH));

    if (_leading != null) {
      (_leading!.parentData! as BoxParentData).offset = Offset(
        0.0,
        (size.height - leadSize.height) / 2.0,
      );
    }
    (bodyChild.parentData! as BoxParentData).offset = Offset(
      leadOffset,
      (size.height - bodySize.height) / 2.0,
    );
    (_trailing!.parentData! as BoxParentData).offset = Offset(
      size.width - trailSize.width,
      (size.height - trailSize.height) / 2.0,
    );
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    for (final child in <RenderBox?>[_leading, _body, _trailing]) {
      if (child != null) {
        final pd = child.parentData! as BoxParentData;
        context.paintChild(child, offset + pd.offset);
      }
    }
  }

  @override
  bool hitTestChildren(BoxHitTestResult result, {required Offset position}) {
    for (final child in <RenderBox?>[_trailing, _body, _leading]) {
      if (child != null) {
        final pd = child.parentData! as BoxParentData;
        final isHit = result.addWithPaintOffset(
          offset: pd.offset,
          position: position,
          hitTest: (BoxHitTestResult result, Offset transformed) {
            return child.hitTest(result, position: transformed);
          },
        );
        if (isHit) return true;
      }
    }
    return false;
  }
}
