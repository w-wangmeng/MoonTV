import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

import '../tv_mode.dart';

/// Keeps a D-pad focused card inside the visible part of its scroller.
///
/// This is intentionally a no-op for touch layouts so normal tablet scrolling
/// behavior is untouched.
void ensureTvFocusVisible(BuildContext context, {double alignment = 0.28}) {
  if (!TvMode.of(context).isTv) return;
  WidgetsBinding.instance.addPostFrameCallback((_) {
    if (!context.mounted) return;
    final box = context.findRenderObject();
    final scrollable = Scrollable.maybeOf(context);
    if (box is! RenderBox || !box.hasSize || scrollable == null) return;
    try {
      final viewport = RenderAbstractViewport.of(box);
      final reveal = viewport.getOffsetToReveal(box, 0);
      final position = scrollable.position;
      final visibleTop = position.pixels;
      final visibleBottom = visibleTop + position.viewportDimension;
      if (reveal.offset >= visibleTop &&
          reveal.offset + box.size.height <= visibleBottom) {
        return;
      }
    } catch (_) {
      // If the viewport is not measurable yet, let ensureVisible handle it.
    }
    Scrollable.ensureVisible(
      context,
      alignment: alignment,
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOutCubic,
    );
  });
}
