import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'media_api.dart';
import 'media_models.dart';

class MediaStore extends ChangeNotifier {
  MediaStore({required this.preferences, MediaApi? api})
    : api = api ?? MediaApi();

  static const _accountKey = 'moonbox.media.account.v1';
  static const _deviceKey = 'moonbox.media.device.v1';
  static const _favoritesKey = 'moonbox.media.favorites.v1';
  static const _hiddenResumeKey = 'moonbox.media.hiddenResume.v1';

  final SharedPreferences preferences;
  final MediaApi api;

  MediaAccount? _account;
  List<MediaLibrary> _libraries = const [];
  List<MediaItem> _resume = const [];
  List<MediaItem> _favorites = const [];
  Set<String> _localFavorites = {};
  Set<String> _hiddenResume = {};
  bool _favoritesLoading = false;
  bool _favoritesLoaded = false;
  String? _favoritesError;
  bool _initialized = false;
  bool _busy = false;
  String? _error;

  MediaAccount? get account => _account;
  List<MediaLibrary> get libraries => _libraries;
  List<MediaItem> get resume => _resume
      .where((item) => !_hiddenResume.contains(_scopeId(item)))
      .toList(growable: false);
  List<MediaItem> get favorites => _favorites;
  bool get favoritesLoading => _favoritesLoading;
  bool get favoritesLoaded => _favoritesLoaded;
  String? get favoritesError => _favoritesError;
  bool get initialized => _initialized;
  bool get busy => _busy;
  String? get error => _error;
  bool get hasServer => _account != null;

  Future<void> init() async {
    _localFavorites = preferences.getStringList(_favoritesKey)?.toSet() ?? {};
    _hiddenResume = preferences.getStringList(_hiddenResumeKey)?.toSet() ?? {};
    final raw = preferences.getString(_accountKey);
    if (raw != null) {
      try {
        final decoded = jsonDecode(raw);
        if (decoded is Map) {
          _account = MediaAccount.fromJson(decoded.cast<String, dynamic>());
        }
      } catch (_) {
        await preferences.remove(_accountKey);
      }
    }
    _initialized = true;
    notifyListeners();
    if (_account != null) {
      await refresh();
    }
  }

  Future<void> login({
    required MediaServerType type,
    required String baseUrl,
    required String username,
    required String password,
    String? plexToken,
  }) async {
    _busy = true;
    _error = null;
    notifyListeners();
    try {
      final account = await api.login(
        type: type,
        baseUrl: baseUrl,
        username: username,
        password: password,
        deviceId: _deviceId(),
        plexToken: plexToken,
      );
      _account = account;
      await preferences.setString(_accountKey, jsonEncode(account.toJson()));
      await _loadHome();
    } catch (error) {
      _error = error.toString();
    } finally {
      _busy = false;
      notifyListeners();
    }
  }

  Future<void> refresh() async {
    if (_account == null) return;
    _busy = true;
    _error = null;
    notifyListeners();
    try {
      await _loadHome();
    } catch (error) {
      _error = error.toString();
    } finally {
      _busy = false;
      notifyListeners();
    }
  }

  Future<void> _loadHome() async {
    final account = _account;
    if (account == null) return;
    final results = await Future.wait([
      api.libraries(account),
      api.resume(account),
    ]);
    _libraries = results[0] as List<MediaLibrary>;
    _resume = results[1] as List<MediaItem>;
  }

  Future<void> logout() async {
    _account = null;
    _libraries = const [];
    _resume = const [];
    _favorites = const [];
    _favoritesLoaded = false;
    _favoritesError = null;
    _error = null;
    await preferences.remove(_accountKey);
    notifyListeners();
  }

  Future<List<MediaItem>> searchItems(String query) async {
    final account = _account;
    final term = query.trim();
    if (account == null || term.isEmpty) return const [];
    if (!account.isPlex) {
      return api.search(account, term);
    }
    final results = <MediaItem>[];
    final seen = <String>{};
    for (final library in _libraries) {
      try {
        final (items, _) = await api.items(
          account,
          libraryId: library.id,
          limit: 20,
          searchTerm: term,
        );
        for (final item in items) {
          if (seen.add(item.id)) results.add(item);
        }
      } catch (_) {
        // Plex libraries can fail individually; keep the remaining results.
      }
    }
    return results.take(40).toList(growable: false);
  }

  Future<void> loadFavorites() async {
    final account = _account;
    if (account == null) {
      _favorites = const [];
      _favoritesLoaded = false;
      _favoritesError = null;
      notifyListeners();
      return;
    }
    _favoritesLoading = true;
    _favoritesError = null;
    notifyListeners();
    try {
      final items = account.isPlex
          ? await _localPlexFavorites(account)
          : await api.favorites(account);
      _favorites = items;
      _favoritesLoaded = true;
    } catch (error) {
      _favoritesError = error.toString();
    } finally {
      _favoritesLoading = false;
      notifyListeners();
    }
  }

  Future<List<MediaItem>> _localPlexFavorites(MediaAccount account) async {
    final prefix = _scopePrefix;
    final ids = _localFavorites
        .where((key) => key.startsWith(prefix))
        .map((key) => key.substring(prefix.length))
        .toList(growable: false);
    final items = <MediaItem>[];
    for (final id in ids) {
      try {
        items.add(await api.item(account, id));
      } catch (_) {
        // A deleted Plex item should not hide the rest of the favorites.
      }
    }
    return items;
  }

  bool isFavorite(MediaItem item) =>
      item.isFavorite || _localFavorites.contains(_scopeId(item));

  Future<void> toggleFavorite(MediaItem item) async {
    final account = _account;
    if (account == null) return;
    final next = !isFavorite(item);
    if (account.isPlex) {
      if (next) {
        _localFavorites.add(_scopeId(item));
      } else {
        _localFavorites.remove(_scopeId(item));
      }
      notifyListeners();
      await preferences.setStringList(_favoritesKey, _localFavorites.toList());
      return;
    }
    await api.setFavorite(account, item, next);
    await refresh();
  }

  Future<void> hideResume(MediaItem item) async {
    final key = _scopeId(item);
    if (!_hiddenResume.add(key)) return;
    notifyListeners();
    await preferences.setStringList(_hiddenResumeKey, _hiddenResume.toList());
  }

  String get _scopePrefix {
    final account = _account;
    return account == null ? '' : '${account.baseUrl}|${account.userId}|';
  }

  String _scopeId(MediaItem item) => '$_scopePrefix${item.id}';

  void clearError() {
    if (_error == null) return;
    _error = null;
    notifyListeners();
  }

  String _deviceId() {
    final existing = preferences.getString(_deviceKey);
    if (existing != null && existing.isNotEmpty) return existing;
    final id = makeDeviceId();
    preferences.setString(_deviceKey, id);
    return id;
  }
}
