import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum TvPreference {
  auto('自动', '按设备类型自动选择'),
  on('电视优先', '始终使用遥控器优化布局'),
  off('平板优先', '始终使用触控布局');

  const TvPreference(this.label, this.description);

  final String label;
  final String description;

  String get storageValue => switch (this) {
    TvPreference.auto => 'auto',
    TvPreference.on => 'on',
    TvPreference.off => 'off',
  };

  static TvPreference fromStorage(String? value) {
    return switch (value) {
      'on' => TvPreference.on,
      'off' => TvPreference.off,
      _ => TvPreference.auto,
    };
  }
}

/// Owns the Android TV detection result and the user's layout preference.
///
/// The preference is intentionally separate from the detected hardware so a
/// TV stick that reports itself as a tablet can still be switched manually.
class TvModeController extends ChangeNotifier {
  TvModeController(this._preferences);

  static const _preferenceKey = 'moonbox.tvMode.v1';
  static const _channel = MethodChannel('moonbox/device');

  final SharedPreferences _preferences;
  TvPreference _preference = TvPreference.auto;
  bool _detectedTelevision = false;
  bool _initialized = false;

  TvPreference get preference => _preference;
  bool get detectedTelevision => _detectedTelevision;
  bool get initialized => _initialized;

  bool get isTv =>
      _preference == TvPreference.on ||
      (_preference == TvPreference.auto && _detectedTelevision);

  String get detectedLabel => _detectedTelevision ? '检测到电视设备' : '未检测到电视设备';

  Future<void> init() async {
    _preference = TvPreference.fromStorage(
      _preferences.getString(_preferenceKey),
    );
    try {
      _detectedTelevision =
          await _channel.invokeMethod<bool>('isTelevision') ?? false;
    } catch (_) {
      _detectedTelevision = false;
    }
    _initialized = true;
    notifyListeners();
  }

  Future<void> setPreference(TvPreference value) async {
    if (_preference == value) return;
    _preference = value;
    notifyListeners();
    await _preferences.setString(_preferenceKey, value.storageValue);
  }
}

class TvModeScope extends InheritedNotifier<TvModeController> {
  const TvModeScope({
    super.key,
    required TvModeController controller,
    required super.child,
  }) : super(notifier: controller);

  static TvModeController of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<TvModeScope>();
    assert(scope != null, 'TvModeScope is missing above this widget');
    return scope!.notifier!;
  }

  static bool isTv(BuildContext context) => of(context).isTv;
}

/// Convenience accessor used by widgets that only need the layout decision.
class TvMode {
  const TvMode._();

  static TvModeController of(BuildContext context) => TvModeScope.of(context);
}
