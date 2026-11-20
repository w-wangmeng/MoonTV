import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:xml/xml.dart';

import '../models.dart';

/// Apple CMS V10 client used by both TVBox JSON sites and MoonTV/LunaTV
/// `api_site` entries. A small XML fallback covers older TVBox type-0 APIs.
class VodApi {
  VodApi({Dio? dio})
    : _dio =
          dio ??
          Dio(
            BaseOptions(
              connectTimeout: const Duration(seconds: 12),
              receiveTimeout: const Duration(seconds: 20),
              sendTimeout: const Duration(seconds: 12),
              followRedirects: true,
              maxRedirects: 4,
              responseType: ResponseType.plain,
              headers: const {
                'User-Agent':
                    'Mozilla/5.0 (Linux; Android 12) AppleWebKit/537.36 '
                    '(KHTML, like Gecko) Chrome/120.0 Mobile Safari/537.36',
                'Accept': 'application/json, text/plain, */*',
              },
            ),
          );

  final Dio _dio;
  final Map<String, List<Category>> _categoryCache = {};

  Future<VodPage> fetchPage(
    SourceSite site, {
    int page = 1,
    String? categoryId,
    String? keyword,
  }) async {
    final params = <String, dynamic>{'ac': 'videolist', 'pg': page};
    if (categoryId != null && categoryId.isNotEmpty) {
      params['t'] = categoryId;
    }
    if (keyword != null && keyword.trim().isNotEmpty) {
      params['wd'] = keyword.trim();
    }

    final payload = await _request(site, params);
    if (payload is String) {
      return _parseXmlPage(payload, page: page);
    }
    if (payload is! Map) {
      throw ApiException('接口返回格式无法识别');
    }
    final map = payload.cast<dynamic, dynamic>();
    final rawList = map['list'];
    if (rawList is! List) {
      final message = map['msg']?.toString();
      throw ApiException(
        message == null || message.isEmpty ? '接口没有返回影片列表' : '接口提示：$message',
      );
    }
    final items = <VodItem>[];
    for (final entry in rawList) {
      if (entry is Map) {
        final item = _parseItem(entry.cast<dynamic, dynamic>(), site);
        if (item.name.isNotEmpty) items.add(item);
      }
    }

    final categories = keyword == null
        ? _categoriesFromItems(items)
        : const <Category>[];
    if (keyword == null && categoryId == null && categories.isNotEmpty) {
      _categoryCache[site.api] = categories;
    }

    final pageCount = _int(map['pagecount'], fallback: 1);
    final total = _int(map['total'], fallback: items.length);
    return VodPage(
      items: items,
      categories: categoryId == null
          ? (_categoryCache[site.api] ?? categories)
          : const [],
      page: page,
      pageCount: pageCount <= 0 ? 1 : pageCount,
      total: total,
    );
  }

  Future<List<Category>> fetchCategories(SourceSite site) async {
    final cached = _categoryCache[site.api];
    if (cached != null && cached.isNotEmpty) return cached;

    try {
      final payload = await _request(site, {'ac': 'class'});
      if (payload is Map) {
        final map = payload.cast<dynamic, dynamic>();
        final rawClass = map['class'];
        if (rawClass is List) {
          final categories = <Category>[];
          for (final entry in rawClass) {
            if (entry is! Map) continue;
            final id = _string(entry['type_id']);
            final name = _string(entry['type_name']);
            if (id.isNotEmpty && name.isNotEmpty) {
              categories.add(Category(id: id, name: name));
            }
          }
          if (categories.isNotEmpty) {
            _categoryCache[site.api] = categories;
            return categories;
          }
        }
      }
    } catch (_) {
      // Not every Apple CMS deployment implements ac=class. Falling back to
      // categories discovered on the first page is expected.
    }

    final page = await fetchPage(site, page: 1);
    return page.categories.isNotEmpty
        ? page.categories
        : (_categoryCache[site.api] ?? const []);
  }

  Future<VodItem> fetchDetail(SourceSite site, String id) async {
    final payload = await _request(site, {'ac': 'detail', 'ids': id});
    if (payload is String) {
      final page = _parseXmlPage(payload, page: 1);
      if (page.items.isNotEmpty) return page.items.first;
      throw ApiException('详情接口没有返回内容');
    }
    if (payload is! Map) throw ApiException('详情接口返回格式无法识别');
    final map = payload.cast<dynamic, dynamic>();
    final rawList = map['list'];
    if (rawList is List && rawList.isNotEmpty && rawList.first is Map) {
      return _parseItem((rawList.first as Map).cast<dynamic, dynamic>(), site);
    }
    throw ApiException(
      map['msg']?.toString().isNotEmpty == true
          ? '接口提示：${map['msg']}'
          : '详情接口没有返回内容',
    );
  }

  Future<Object?> _request(SourceSite site, Map<String, dynamic> params) async {
    final uri = Uri.tryParse(site.api);
    if (uri == null || !uri.hasScheme) {
      throw ApiException('站源地址无效：${site.api}');
    }
    final merged = <String, String>{
      ...uri.queryParameters,
      ...params.map((key, value) => MapEntry(key, value.toString())),
    };
    final requestUri = uri.replace(queryParameters: merged);

    late final Response<dynamic> response;
    try {
      response = await _dio.get<dynamic>(requestUri.toString());
    } on DioException catch (error) {
      final status = error.response?.statusCode;
      if (status != null) throw ApiException('接口返回 HTTP $status');
      if (error.type == DioExceptionType.connectionTimeout ||
          error.type == DioExceptionType.receiveTimeout) {
        throw ApiException('接口连接超时');
      }
      throw ApiException('接口连接失败，请检查网络或该源是否可用');
    }

    final status = response.statusCode ?? 0;
    if (status < 200 || status >= 400) {
      throw ApiException('接口返回 HTTP $status');
    }
    final data = response.data;
    final raw = data is String ? data : jsonEncode(data);
    if (raw.trim().isEmpty) throw ApiException('接口返回空内容');
    final trimmed = raw.trimLeft();
    if (trimmed.startsWith('<')) return raw;
    try {
      return jsonDecode(raw);
    } on FormatException {
      throw ApiException('接口返回的不是有效 JSON/XML');
    }
  }

  VodPage _parseXmlPage(String raw, {required int page}) {
    late final XmlDocument document;
    try {
      document = XmlDocument.parse(raw);
    } on XmlException {
      throw ApiException('XML 接口解析失败');
    }

    var pageCount = 1;
    var total = 0;
    final listElement = document.findAllElements('list').firstOrNull;
    if (listElement != null) {
      pageCount = _int(listElement.getAttribute('pagecount'), fallback: 1);
      total = _int(listElement.getAttribute('total'), fallback: 0);
    }

    final items = <VodItem>[];
    for (final video in document.findAllElements('video')) {
      final id = _xmlText(video, 'id');
      final name = _xmlText(video, 'name');
      if (name.isEmpty) continue;
      final groups = <PlayGroup>[];
      final dl = video.findElements('dl').firstOrNull;
      if (dl != null) {
        for (final dd in dl.findElements('dd')) {
          final flag = dd.getAttribute('flag')?.trim();
          final episodes = _parseEpisodes(dd.innerText);
          if (episodes.isNotEmpty) {
            groups.add(
              PlayGroup(
                name: (flag == null || flag.isEmpty) ? '线路 1' : flag,
                episodes: episodes,
              ),
            );
          }
        }
      }
      items.add(
        VodItem(
          id: id.isEmpty ? name : id,
          name: name,
          pic: _normalizePic(_xmlText(video, 'pic')),
          remarks: _xmlText(video, 'note'),
          year: _xmlText(video, 'year'),
          area: _xmlText(video, 'area'),
          typeId: _xmlText(video, 'type'),
          typeName: _xmlText(video, 'type'),
          actor: _xmlText(video, 'actor'),
          director: _xmlText(video, 'director'),
          content: _plainText(_xmlText(video, 'des')),
          groups: groups,
        ),
      );
    }
    return VodPage(
      items: items,
      categories: _categoriesFromItems(items),
      page: page,
      pageCount: pageCount <= 0 ? 1 : pageCount,
      total: total,
    );
  }

  VodItem _parseItem(Map<dynamic, dynamic> map, SourceSite site) {
    final playFrom = _string(map['vod_play_from']);
    final playUrl = _string(map['vod_play_url']);
    final directUrl = _string(map['vod_url']);
    final groups = _parsePlayGroups(
      playFrom: playFrom,
      playUrl: playUrl.isEmpty ? directUrl : playUrl,
    );
    return VodItem(
      id: _string(map['vod_id']).isEmpty
          ? _string(map['id'])
          : _string(map['vod_id']),
      name: _string(map['vod_name']).isEmpty
          ? _string(map['name'])
          : _string(map['vod_name']),
      pic: _normalizePic(
        _string(map['vod_pic']).isEmpty
            ? _string(map['pic'])
            : _string(map['vod_pic']),
      ),
      remarks: _string(map['vod_remarks']).isEmpty
          ? _string(map['note'])
          : _string(map['vod_remarks']),
      year: _string(map['vod_year']),
      area: _string(map['vod_area']),
      typeId: _string(map['type_id']),
      typeName: _string(map['type_name']),
      actor: _string(map['vod_actor']),
      director: _string(map['vod_director']),
      content: _plainText(
        _string(map['vod_content']).isEmpty
            ? _string(map['vod_blurb'])
            : _string(map['vod_content']),
      ),
      groups: groups,
    );
  }

  List<PlayGroup> _parsePlayGroups({
    required String playFrom,
    required String playUrl,
  }) {
    final froms = playFrom.split(r'$$$');
    final urls = playUrl.split(r'$$$');
    final groups = <PlayGroup>[];
    for (var i = 0; i < urls.length; i++) {
      final episodes = _parseEpisodes(urls[i]);
      if (episodes.isEmpty) continue;
      final name = i < froms.length && froms[i].trim().isNotEmpty
          ? froms[i].trim()
          : '线路 ${i + 1}';
      groups.add(PlayGroup(name: name, episodes: episodes));
    }
    return groups;
  }

  List<Episode> _parseEpisodes(String raw) {
    final episodes = <Episode>[];
    final chunks = raw.split('#');
    for (var i = 0; i < chunks.length; i++) {
      final chunk = chunks[i].trim();
      if (chunk.isEmpty) continue;
      final separator = chunk.indexOf(r'$');
      String name;
      String url;
      if (separator >= 0) {
        name = chunk.substring(0, separator).trim();
        url = chunk.substring(separator + 1).trim();
      } else {
        name = '第${i + 1}集';
        url = chunk;
      }
      if (url.isEmpty) continue;
      if (url.startsWith('magnet:') || url.startsWith('ed2k:')) continue;
      if (!url.startsWith('http://') &&
          !url.startsWith('https://') &&
          !url.startsWith('rtsp://') &&
          !url.startsWith('rtmp://')) {
        continue;
      }
      episodes.add(Episode(name: name.isEmpty ? '第${i + 1}集' : name, url: url));
    }
    return episodes;
  }

  List<Category> _categoriesFromItems(List<VodItem> items) {
    final seen = <String>{};
    final categories = <Category>[];
    for (final item in items) {
      if (item.typeId.isEmpty || item.typeName.isEmpty) continue;
      if (seen.add(item.typeId)) {
        categories.add(Category(id: item.typeId, name: item.typeName));
      }
    }
    return categories;
  }

  String _normalizePic(String value) {
    var pic = value.trim();
    if (pic.isEmpty) return '';
    if (pic.startsWith('//')) pic = 'https:$pic';
    return pic;
  }

  String _plainText(String value) {
    return value
        .replaceAll(RegExp(r'<[^>]*>'), ' ')
        .replaceAll('&nbsp;', ' ')
        .replaceAll('&amp;', '&')
        .replaceAll('&quot;', '"')
        .replaceAll('&#39;', "'")
        .replaceAll('&lt;', '<')
        .replaceAll('&gt;', '>')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  String _xmlText(XmlElement element, String name) {
    return element.findElements(name).firstOrNull?.innerText.trim() ?? '';
  }

  String _string(Object? value) => value?.toString().trim() ?? '';

  int _int(Object? value, {int fallback = 0}) {
    if (value is int) return value;
    return int.tryParse(value?.toString() ?? '') ?? fallback;
  }
}

extension _FirstOrNull<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
