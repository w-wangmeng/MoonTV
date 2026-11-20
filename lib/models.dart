import 'dart:convert';

/// A single playable source extracted from either a MoonTV/LunaTV
/// `api_site` map or a TVBox `sites` array.
class SourceSite {
  const SourceSite({
    required this.key,
    required this.name,
    required this.api,
    this.detail = '',
    this.origin = '',
    this.type = 1,
  });

  final String key;
  final String name;
  final String api;
  final String detail;
  final String origin;

  /// TVBox site type. 0 = XML API, 1 = JSON API.
  final int type;

  String get host {
    final uri = Uri.tryParse(api);
    return (uri?.host.isNotEmpty ?? false) ? uri!.host : api;
  }

  /// Some MoonTV/LunaTV configs prefix names with emoji that lack a glyph in
  /// the bundled font. Keep the original for matching, display a clean name.
  String get displayName {
    var cleaned = name.replaceAll(
      RegExp(r'[\u{1F000}-\u{1FAFF}\u{2600}-\u{27BF}\u{FE0F}]', unicode: true),
      '',
    );
    cleaned = cleaned
        .replaceAll(RegExp(r'^[\s\-–—·•|]+|[\s\-–—·•|]+$'), '')
        .trim();
    return cleaned.isEmpty ? name : cleaned;
  }

  SourceSite copyWith({String? key, String? name}) {
    return SourceSite(
      key: key ?? this.key,
      name: name ?? this.name,
      api: api,
      detail: detail,
      origin: origin,
      type: type,
    );
  }

  Map<String, dynamic> toJson() => {
    'key': key,
    'name': name,
    'api': api,
    'detail': detail,
    'origin': origin,
    'type': type,
  };

  factory SourceSite.fromJson(Map<String, dynamic> json) {
    return SourceSite(
      key: _string(json['key']),
      name: _string(json['name']),
      api: _string(json['api']),
      detail: _string(json['detail']),
      origin: _string(json['origin']),
      type: _int(json['type'], fallback: 1),
    );
  }
}

class SavedConfig {
  const SavedConfig({
    required this.id,
    required this.url,
    required this.label,
    required this.format,
    required this.siteCount,
    required this.addedAt,
  });

  final String id;
  final String url;
  final String label;
  final String format;
  final int siteCount;
  final DateTime addedAt;

  SavedConfig copyWith({String? label, String? format, int? siteCount}) {
    return SavedConfig(
      id: id,
      url: url,
      label: label ?? this.label,
      format: format ?? this.format,
      siteCount: siteCount ?? this.siteCount,
      addedAt: addedAt,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'url': url,
    'label': label,
    'format': format,
    'siteCount': siteCount,
    'addedAt': addedAt.toIso8601String(),
  };

  factory SavedConfig.fromJson(Map<String, dynamic> json) {
    return SavedConfig(
      id: _string(json['id']),
      url: _string(json['url']),
      label: _string(json['label']),
      format: _string(json['format']),
      siteCount: _int(json['siteCount']),
      addedAt: DateTime.tryParse(_string(json['addedAt'])) ?? DateTime.now(),
    );
  }
}

class Category {
  const Category({required this.id, required this.name});

  final String id;
  final String name;
}

class Episode {
  const Episode({required this.name, required this.url});

  final String name;
  final String url;

  bool get isPlayable =>
      url.startsWith('http://') ||
      url.startsWith('https://') ||
      url.startsWith('rtsp://') ||
      url.startsWith('rtmp://');
}

class PlayGroup {
  const PlayGroup({required this.name, required this.episodes});

  final String name;
  final List<Episode> episodes;
}

class VodItem {
  const VodItem({
    required this.id,
    required this.name,
    required this.pic,
    required this.remarks,
    required this.year,
    required this.area,
    required this.typeId,
    required this.typeName,
    required this.actor,
    required this.director,
    required this.content,
    required this.groups,
  });

  final String id;
  final String name;
  final String pic;
  final String remarks;
  final String year;
  final String area;
  final String typeId;
  final String typeName;
  final String actor;
  final String director;
  final String content;
  final List<PlayGroup> groups;

  bool get hasPlayback => groups.any(
    (group) => group.episodes.any((episode) => episode.isPlayable),
  );

  Episode? get firstEpisode {
    for (final group in groups) {
      for (final episode in group.episodes) {
        if (episode.isPlayable) return episode;
      }
    }
    return null;
  }

  VodItem copyWith({List<PlayGroup>? groups}) {
    return VodItem(
      id: id,
      name: name,
      pic: pic,
      remarks: remarks,
      year: year,
      area: area,
      typeId: typeId,
      typeName: typeName,
      actor: actor,
      director: director,
      content: content,
      groups: groups ?? this.groups,
    );
  }
}

class VodPage {
  const VodPage({
    required this.items,
    required this.categories,
    required this.page,
    required this.pageCount,
    required this.total,
  });

  final List<VodItem> items;
  final List<Category> categories;
  final int page;
  final int pageCount;
  final int total;
}

class SearchHit {
  const SearchHit({required this.site, required this.item});

  final SourceSite site;
  final VodItem item;
}

class ConfigLoadResult {
  const ConfigLoadResult({
    required this.sites,
    required this.format,
    this.warnings = const [],
    this.subConfigUrls = const [],
    this.skipped = 0,
  });

  final List<SourceSite> sites;
  final String format;
  final List<String> warnings;
  final List<String> subConfigUrls;
  final int skipped;

  ConfigLoadResult merge(ConfigLoadResult other) {
    final seen = <String>{};
    final merged = <SourceSite>[];
    for (final site in [...sites, ...other.sites]) {
      final signature = '${site.api}|${site.name}';
      if (seen.add(signature)) merged.add(site);
    }
    return ConfigLoadResult(
      sites: merged,
      format: format == other.format ? format : '$format + ${other.format}',
      warnings: [...warnings, ...other.warnings],
      subConfigUrls: [...subConfigUrls, ...other.subConfigUrls],
      skipped: skipped + other.skipped,
    );
  }
}

class ApiException implements Exception {
  ApiException(this.message);

  final String message;

  @override
  String toString() => message;
}

String _string(Object? value) => value?.toString().trim() ?? '';

int _int(Object? value, {int fallback = 0}) {
  if (value is int) return value;
  return int.tryParse(value?.toString() ?? '') ?? fallback;
}

/// Bounded Base58 (Bitcoin alphabet) decoder used by MoonTV/LunaTV
/// subscriptions. The decoded bytes are UTF-8 JSON.
class Base58 {
  static const _alphabet =
      '123456789ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnopqrstuvwxyz';

  static String decode(String input) {
    final text = input.replaceAll(RegExp(r'\s+'), '');
    if (text.isEmpty) throw const FormatException('订阅内容为空');

    var value = BigInt.zero;
    for (final rune in text.runes) {
      final digit = _alphabet.indexOf(String.fromCharCode(rune));
      if (digit < 0) {
        throw FormatException(
          '不是有效的 Base58 订阅（字符 ${String.fromCharCode(rune)}）',
        );
      }
      value = value * BigInt.from(58) + BigInt.from(digit);
    }

    var hex = value == BigInt.zero ? '' : value.toRadixString(16);
    if (hex.length.isOdd) hex = '0$hex';
    final bytes = <int>[
      for (var i = 0; i < hex.length; i += 2)
        int.parse(hex.substring(i, i + 2), radix: 16),
    ];
    var leadingZeros = 0;
    for (final rune in text.runes) {
      if (rune == 0x31) {
        leadingZeros++;
      } else {
        break;
      }
    }
    final decoded = <int>[...List.filled(leadingZeros, 0), ...bytes];
    return utf8.decode(decoded, allowMalformed: true).trim();
  }
}

/// Parses both MoonTV/LunaTV and TVBox style configuration payloads.
///
/// MoonTV/LunaTV:
/// `{"api_site": {"key": {"name": "...", "api": "...", "detail": "..."}}}`
///
/// TVBox:
/// `{"sites": [{"key": "...", "name": "...", "type": 1, "api": "..."}]}`
class ConfigParser {
  static ConfigLoadResult parse(String raw, {String origin = ''}) {
    final trimmed = raw.trim();
    if (trimmed.isEmpty) throw const FormatException('配置内容为空');

    dynamic decoded;
    var format = 'JSON';
    try {
      decoded = jsonDecode(trimmed);
    } on FormatException {
      final text = Base58.decode(trimmed);
      try {
        decoded = jsonDecode(text);
      } on FormatException {
        throw const FormatException('Base58 解码后不是有效的 JSON 配置');
      }
      format = 'Base58 JSON';
    }
    return fromJson(decoded, origin: origin, format: format);
  }

  static ConfigLoadResult fromJson(
    dynamic root, {
    String origin = '',
    String format = 'JSON',
  }) {
    final sites = <SourceSite>[];
    final warnings = <String>[];
    final subConfigUrls = <String>[];
    var skipped = 0;
    var detected = format;

    List<dynamic>? siteList;
    if (root is List) {
      siteList = root;
    } else if (root is Map) {
      final map = root.cast<dynamic, dynamic>();
      final apiSite = map['api_site'];
      if (apiSite is Map) {
        detected = 'MoonTV/LunaTV api_site';
        apiSite.forEach((key, value) {
          if (value is! Map) return;
          final api = _string(value['api']).isEmpty
              ? _string(value['url'])
              : _string(value['api']);
          if (api.isEmpty) {
            skipped++;
            return;
          }
          final name = _string(value['name']).isEmpty
              ? key.toString()
              : _string(value['name']);
          sites.add(
            SourceSite(
              key: key.toString(),
              name: name,
              api: _normalizeUrl(api, origin),
              detail: _normalizeUrl(_string(value['detail']), origin),
              origin: origin,
              type: 1,
            ),
          );
        });
      }

      final rawSites = map['sites'];
      if (rawSites is List) {
        if (sites.isEmpty) detected = 'TVBox sites';
        siteList = rawSites;
      } else if (sites.isEmpty && apiSite == null) {
        final urls = map['urls'];
        if (urls is List) {
          detected = 'TVBox urls';
          for (final entry in urls) {
            if (entry is String && entry.trim().isNotEmpty) {
              subConfigUrls.add(_normalizeUrl(entry.trim(), origin));
            } else if (entry is Map && _string(entry['url']).isNotEmpty) {
              subConfigUrls.add(_normalizeUrl(_string(entry['url']), origin));
            }
          }
          if (subConfigUrls.isEmpty) {
            throw const FormatException('配置包含 urls，但没有有效的子配置地址');
          }
        } else {
          throw const FormatException(
            '未找到 api_site 或 sites，这不是 MoonTV/LunaTV / TVBox 配置',
          );
        }
      }

      if ((siteList == null || siteList.isEmpty) &&
          map['lives'] is List &&
          (map['lives'] as List).isNotEmpty &&
          sites.isEmpty &&
          subConfigUrls.isEmpty) {
        warnings.add('该 TVBox 配置只有直播源，暂不支持直播');
      }
    } else {
      throw const FormatException('配置根节点必须是 JSON 对象或数组');
    }

    if (siteList != null) {
      for (final entry in siteList) {
        if (entry is! Map) {
          skipped++;
          continue;
        }
        final type = _int(entry['type'], fallback: 1);
        final api = _string(entry['api']);
        if (api.isEmpty) {
          skipped++;
          continue;
        }
        // TVBox spider (3/4) and JS-only sites cannot be driven by the
        // standard Apple CMS JSON API. Keep the app honest instead of
        // presenting a source that will always fail.
        if (type != 0 && type != 1) {
          skipped++;
          continue;
        }
        final key = _string(entry['key']).isEmpty
            ? 'site_${sites.length + 1}'
            : _string(entry['key']);
        final name = _string(entry['name']).isEmpty
            ? key
            : _string(entry['name']);
        sites.add(
          SourceSite(
            key: key,
            name: name,
            api: _normalizeUrl(api, origin),
            detail: _normalizeUrl(_string(entry['detail']), origin),
            origin: origin,
            type: type,
          ),
        );
      }
    }

    // A site may appear in several configs. Keep the first occurrence so
    // source selection stays stable between refreshes.
    final seen = <String>{};
    final unique = <SourceSite>[];
    for (final site in sites) {
      if (seen.add(site.api)) unique.add(site);
    }

    if (skipped > 0) {
      warnings.add('已跳过 $skipped 个需要 JAR/JS 爬虫或缺少 api 的站源');
    }
    if (unique.isEmpty && subConfigUrls.isEmpty) {
      throw const FormatException('配置解析成功，但没有可用的 JSON/XML 点播源（可能全部是爬虫源）');
    }
    return ConfigLoadResult(
      sites: unique,
      format: detected,
      warnings: warnings,
      subConfigUrls: subConfigUrls,
      skipped: skipped,
    );
  }

  static String _normalizeUrl(String value, String origin) {
    var url = value.trim();
    if (url.isEmpty) return '';
    if (url.startsWith('//')) return 'https:$url';
    if (url.startsWith('/') && origin.isNotEmpty) {
      final base = Uri.tryParse(origin);
      if (base != null && base.hasScheme) {
        return base.replace(path: url).toString();
      }
    }
    return url;
  }
}
