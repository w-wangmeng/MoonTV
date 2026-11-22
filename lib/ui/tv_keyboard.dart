import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../tv_mode.dart';

const _channel = MethodChannel('moonbox/device');

/// Wraps the app and, on Android TV, forces the system soft keyboard to show
/// whenever a text field gains focus.
///
/// Flutter's engine asks Android for the on-screen IME when a [TextField]
/// gets focus, but on Android TV / leanback devices (no touch screen, D-pad
/// navigation) that request is commonly dropped by the platform, so the soft
/// keyboard never appears. This listener watches the global focus tree and,
/// when an editable field is focused, nudges Android to show the IME with a
/// forced method-channel call.
class TvKeyboardListener extends StatefulWidget {
  const TvKeyboardListener({
    super.key,
    required this.controller,
    required this.child,
  });

  final TvModeController controller;
  final Widget child;

  @override
  State<TvKeyboardListener> createState() => _TvKeyboardListenerState();
}

class _TvKeyboardListenerState extends State<TvKeyboardListener> {
  FocusNode? _lastEditable;

  @override
  void initState() {
    super.initState();
    FocusManager.instance.addListener(_onFocusChanged);
  }

  @override
  void dispose() {
    FocusManager.instance.removeListener(_onFocusChanged);
    super.dispose();
  }

  void _onFocusChanged() {
    if (!kIsWeb && defaultTargetPlatform != TargetPlatform.android) return;
    if (!widget.controller.isTv) return;

    final node = FocusManager.instance.primaryFocus;
    if (node == null || identical(node, _lastEditable)) return;

    if (_isEditable(node)) {
      _lastEditable = node;
      _forceKeyboard();
    } else {
      _lastEditable = null;
    }
  }

  /// True when the focused node belongs to an editable text widget
  /// (TextField / TextFormField).
  bool _isEditable(FocusNode node) {
    final context = node.context;
    if (context == null) return false;
    return context.findAncestorWidgetOfExactType<EditableText>() != null;
  }

  void _forceKeyboard() {
    // Wait one frame so Flutter attaches the InputConnection, then have
    // Android force-display the IME.
    unawaited(Future<void>.delayed(const Duration(milliseconds: 60), () {
      if (!mounted) return;
      _channel.invokeMethod<bool>('showKeyboard');
    }));
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
