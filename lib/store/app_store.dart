import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models.dart';
import '../services/config_service.dart';
import '../services/vod_api.dart';

class SearchOutcome {
  const SearchOutcome({
    required this.hits,
    required this.errors,
    required this.searched,
  });

  final List<SearchHit> hits;
  final int errors;
  final int searched;
}

class AppStore extends ChangeNotifier {
  AppStore({
    required SharedPreferences preferences,
    ConfigService? configService,
    VodApi? vodApi,
  }) : _prefs = preferences,
       _configService = configService ?? ConfigService(),
       api = vodApi ?? VodApi();

  static const _configsKey = 'moonbox.configs.v1';
  static const _sitesKey = 'moonbox.sites.v1';
  static const _selectedKey = 'moonbox.selected.v1';
  static const _disabledSitesKey = 'moonbox.sites.disabled.v1';
  static const _deletedSitesKey = 'moonbox.sites.deleted.v1';

  final SharedPreferences _prefs;
  final ConfigService _configService;
  final VodApi api;

  final List<SavedConfig> _configs = [];
  List<SourceSite> _sites = [];
  final Set<String> _disabledSiteApis = {};
  final Set<String> _deletedSiteApis = {};
  SourceSite? _current;
  bool _initialized = false;
  bool _refreshing = false;
  String? _lastError;
  List<String> _lastWarnings = [];

  bool get initialized => _initialized;
  bool get refreshing => _refreshing;
  String? get lastError => _lastError;
  List<String> get lastWarnings => List.unmodifiable(_lastWarnings);
  List<SavedConfig> get configs => List.unmodifiable(_configs);
  List<SourceSite> get sites => List.unmodifiable(_sites);
  List<SourceSite> get enabledSites =>
      _sites.where(isSiteEnabled).toList(growable: false);
  int get disabledSiteCount => _sites.length - enabledSites.length;
  bool isSiteEnabled(SourceSite site) => !_disabledSiteApis.contains(site.api);
  SourceSite? get current => _current;
  bool get hasConfig => _configs.isNotEmpty;
  bool get isConfigured => _configs.isNotEmpty && _sites.isNotEmpty;
  bool get hasPlayableSources => enabledSites.isNotEmpty;

  Future<void> init() async {
    try {
      _disabledSiteApis
        ..clear()
        ..addAll(_prefs.getStringList(_disabledSitesKey) ?? const []);
      _deletedSiteApis
        ..clear()
        ..addAll(_prefs.getStringList(_deletedSitesKey) ?? const []);
      final rawConfigs = _prefs.getString(_configsKey);
      if (rawConfigs != null && rawConfigs.isNotEmpty) {
        final list = jsonDecode(rawConfigs);
        if (list is List) {
          for (final entry in list) {
            if (entry is Map) {
              _configs.add(SavedConfig.fromJson(entry.cast<String, dynamic>()));
            }
          }
        }
      }
      final rawSites = _prefs.getString(_sitesKey);
      if (rawSites != null && rawSites.isNotEmpty) {
        final list = jsonDecode(rawSites);
        if (list is List) {
          _sites = [
            for (final entry in list)
              if (entry is Map)
                SourceSite.fromJson(entry.cast<String, dynamic>()),
          ].where((site) => !_deletedSiteApis.contains(site.api)).toList();
        }
      }
      final selected = _prefs.getString(_selectedKey);
      _current = _pickSite(selected);
    } catch (_) {
      // Corrupt local cache should never block a first-run configuration.
      _configs.clear();
      _sites = [];
      _disabledSiteApis.clear();
      _deletedSiteApis.clear();
      _current = null;
    }

    _initialized = true;
    notifyListeners();
    if (_configs.isNotEmpty) {
      unawaited(refreshAll(silent: true));
    }
  }

  Future<ConfigLoadResult> addConfig(String url, {String? label}) async {
    final normalized = url.trim();
    if (normalized.isEmpty) throw ApiException('请输入配置地址');
    if (_configs.any((config) => config.url == normalized)) {
      throw ApiException('这个配置已经添加过了');
    }

    final result = await _configService.load(normalized);
    if (result.sites.isEmpty) {
      throw ApiException('配置里没有可用的点播源');
    }

    final existingKeys = _sites.map((site) => site.key).toSet();
    final newSites = <SourceSite>[];
    for (final site in result.sites) {
      var key = site.key.trim();
      if (key.isEmpty) key = 'site_${newSites.length + 1}';
      var uniqueKey = key;
      var suffix = 2;
      while (existingKeys.contains(uniqueKey) ||
          newSites.any((entry) => entry.key == uniqueKey)) {
        uniqueKey = '${key}_$suffix';
        suffix++;
      }
      newSites.add(site.copyWith(key: uniqueKey));
    }
    _deletedSiteApis.removeAll(newSites.map((site) => site.api));

    final saved = SavedConfig(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      url: normalized,
      label: (label == null || label.trim().isEmpty)
          ? _labelForUrl(normalized)
          : label.trim(),
      format: result.format,
      siteCount: newSites.length,
      addedAt: DateTime.now(),
    );

    _configs.add(saved);
    _sites = _mergeSites([..._sites, ...newSites]);
    _current = _pickSite(_current?.key);
    _lastWarnings = result.warnings;
    _lastError = null;
    await _persist();
    notifyListeners();
    return result;
  }

  Future<void> refreshAll({bool silent = false}) async {
    if (_configs.isEmpty || _refreshing) return;
    _refreshing = true;
    _lastError = null;
    if (!silent) notifyListeners();

    final refreshedSites = <SourceSite>[];
    final warnings = <String>[];
    final errors = <String>[];
    final updatedConfigs = <SavedConfig>[];
    final selectedKey = _current?.key;
    final selectedApi = _current?.api;

    for (final config in _configs) {
      try {
        final result = await _configService.load(config.url);
        final configSites = <SourceSite>[];
        for (final site in result.sites) {
          var key = site.key.trim();
          if (key.isEmpty) key = 'site_${configSites.length + 1}';
          configSites.add(site.copyWith(key: key));
        }
        refreshedSites.addAll(configSites);
        warnings.addAll(result.warnings);
        updatedConfigs.add(
          config.copyWith(siteCount: configSites.length, format: result.format),
        );
      } catch (error) {
        errors.add('${config.label}：$error');
        final oldSites = _sites
            .where((site) => site.origin == config.url)
            .toList();
        refreshedSites.addAll(oldSites);
        updatedConfigs.add(config.copyWith(siteCount: oldSites.length));
      }
    }

    _configs
      ..clear()
      ..addAll(updatedConfigs);
    final merged = _mergeSites(refreshedSites)
        .where((site) => !_deletedSiteApis.contains(site.api))
        .toList();
    if (merged.isNotEmpty || _sites.isEmpty) {
      _sites = merged;
    }
    // Keep the last good list if every refresh failed.
    _current = _pickSite(selectedKey, api: selectedApi);
    _lastWarnings = warnings;
    _lastError = errors.isEmpty ? null : errors.join('\n');
    _refreshing = false;
    await _persist();
    notifyListeners();
  }

  Future<void> removeConfig(String id) async {
    final index = _configs.indexWhere((config) => config.id == id);
    if (index < 0) return;
    final removed = _configs.removeAt(index);
    final removedApis = _sites
        .where((site) => site.origin == removed.url)
        .map((site) => site.api)
        .toSet();
    _disabledSiteApis.removeAll(removedApis);
    _sites = _sites.where((site) => site.origin != removed.url).toList();
    _current = _pickSite(_current?.key);
    await _persist();
    notifyListeners();
  }

  Future<void> clearAll() async {
    _configs.clear();
    _sites = [];
    _disabledSiteApis.clear();
    _deletedSiteApis.clear();
    _current = null;
    _lastError = null;
    _lastWarnings = [];
    await _prefs.remove(_configsKey);
    await _prefs.remove(_sitesKey);
    await _prefs.remove(_selectedKey);
    await _prefs.remove(_disabledSitesKey);
    await _prefs.remove(_deletedSitesKey);
    notifyListeners();
  }

  Future<void> selectSite(SourceSite site) async {
    if (!isSiteEnabled(site)) return;
    _current = site;
    await _prefs.setString(_selectedKey, site.key);
    notifyListeners();
  }

  Future<void> setSiteEnabled(SourceSite site, bool enabled) async {
    if (enabled) {
      _disabledSiteApis.remove(site.api);
    } else {
      _disabledSiteApis.add(site.api);
    }
    _current = _pickSite(_current?.key);
    await _persist();
    notifyListeners();
  }

  Future<void> removeSite(SourceSite site) async {
    final wasCurrent = _current?.api == site.api;
    _deletedSiteApis.add(site.api);
    _disabledSiteApis.remove(site.api);
    _sites = _sites.where((entry) => entry.api != site.api).toList();
    _current = _pickSite(wasCurrent ? null : _current?.key);
    await _persist();
    notifyListeners();
  }

  Future<SearchOutcome> search(String query, {bool allSources = false}) async {
    final text = query.trim();
    if (text.isEmpty) {
      return const SearchOutcome(hits: [], errors: 0, searched: 0);
    }

    final available = _sites.where(isSiteEnabled).toList(growable: false);
    final targets = <SourceSite>[];
    if (allSources) {
      targets.addAll(available.take(24));
    } else if (_current != null && isSiteEnabled(_current!)) {
      targets.add(_current!);
    }
    if (targets.isEmpty) {
      return const SearchOutcome(hits: [], errors: 0, searched: 0);
    }

    final hits = <SearchHit>[];
    var errors = 0;
    for (var i = 0; i < targets.length; i += 6) {
      final chunk = targets.skip(i).take(6);
      final results = await Future.wait<List<SearchHit>?>(
        chunk.map((site) async {
          try {
            var page = await api.fetchPage(site, keyword: text);
            // Many Apple CMS deployments are case-sensitive for Latin
            // keywords. A single uppercase retry keeps lowercase input useful.
            final upper = text.toUpperCase();
            if (page.items.isEmpty &&
                upper != text &&
                RegExp(r'[a-z]').hasMatch(text)) {
              page = await api.fetchPage(site, keyword: upper);
            }
            return [
              for (final item in page.items) SearchHit(site: site, item: item),
            ];
          } catch (_) {
            return null;
          }
        }),
      );
      for (final result in results) {
        if (result == null) {
          errors++;
        } else {
          hits.addAll(result);
        }
      }
    }
    return SearchOutcome(hits: hits, errors: errors, searched: targets.length);
  }

  List<SourceSite> _mergeSites(List<SourceSite> input) {
    final seenApi = <String>{};
    final seenKey = <String>{};
    final output = <SourceSite>[];
    for (final site in input) {
      if (seenApi.contains(site.api)) continue;
      var key = site.key;
      var suffix = 2;
      while (seenKey.contains(key)) {
        key = '${site.key}_$suffix';
        suffix++;
      }
      seenApi.add(site.api);
      seenKey.add(key);
      output.add(site.copyWith(key: key));
    }
    return output;
  }

  SourceSite? _pickSite(String? key, {String? api}) {
    if (_sites.isEmpty) return null;
    if (api != null) {
      for (final site in _sites) {
        if (isSiteEnabled(site) && site.api == api) return site;
      }
    }
    if (key != null) {
      for (final site in _sites) {
        if (isSiteEnabled(site) && site.key == key) return site;
      }
    }
    for (final site in _sites) {
      if (isSiteEnabled(site)) return site;
    }
    return null;
  }

  Future<void> _persist() async {
    await _prefs.setString(
      _configsKey,
      jsonEncode([for (final config in _configs) config.toJson()]),
    );
    await _prefs.setString(
      _sitesKey,
      jsonEncode([for (final site in _sites) site.toJson()]),
    );
    await _prefs.setStringList(
      _disabledSitesKey,
      _disabledSiteApis.toList(growable: false),
    );
    await _prefs.setStringList(
      _deletedSitesKey,
      _deletedSiteApis.toList(growable: false),
    );
    final current = _current;
    if (current != null) {
      await _prefs.setString(_selectedKey, current.key);
    } else {
      await _prefs.remove(_selectedKey);
    }
  }

  String _labelForUrl(String url) {
    final uri = Uri.tryParse(url);
    if (uri != null && uri.host.isNotEmpty) return uri.host;
    return '自定义配置';
  }
}
