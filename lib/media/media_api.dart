import 'dart:math';

import 'package:dio/dio.dart';

import 'media_models.dart';

class MediaApiException implements Exception {
  const MediaApiException(this.message);
  final String message;

  @override
  String toString() => message;
}

class MediaApi {
  MediaApi()
    : _dio = Dio(
        BaseOptions(
          connectTimeout: const Duration(seconds: 12),
          receiveTimeout: const Duration(seconds: 25),
          sendTimeout: const Duration(seconds: 12),
          followRedirects: true,
          maxRedirects: 5,
          responseType: ResponseType.json,
          headers: const {
            'Accept': 'application/json',
            'User-Agent': 'MoonTV/1.4.0 (Android)',
          },
        ),
      );

  final Dio _dio;

  Future<MediaAccount> login({
    required MediaServerType type,
    required String baseUrl,
    required String username,
    required String password,
    required String deviceId,
    String? plexToken,
  }) async {
    final base = _normalizeBase(baseUrl);
    if (type == MediaServerType.plex) {
      return _loginPlex(
        baseUrl: base,
        token: plexToken?.trim().isNotEmpty == true
            ? plexToken!.trim()
            : password.trim(),
        deviceId: deviceId,
        username: username,
      );
    }
    final header = _authHeader(deviceId, null);
    try {
      final response = await _dio.post<Map<String, dynamic>>(
        '$base/Users/AuthenticateByName',
        data: {'Username': username, 'Pw': password},
        options: Options(headers: {'X-Emby-Authorization': header}),
      );
      final data = response.data ?? const <String, dynamic>{};
      final token = _str(data['AccessToken']);
      final user = data['User'];
      if (token.isEmpty || user is! Map) {
        throw const MediaApiException('登录成功但服务器没有返回访问令牌');
      }
      final serverName = await _serverName(base, token);
      return MediaAccount(
        type: type,
        baseUrl: base,
        serverName: serverName,
        userId: _str(user['Id']),
        userName: _str(user['Name'], fallback: username),
        accessToken: token,
        deviceId: deviceId,
      );
    } on DioException catch (error) {
      throw MediaApiException(_friendly(error, login: true));
    }
  }

  Future<MediaAccount> _loginPlex({
    required String baseUrl,
    required String token,
    required String deviceId,
    required String username,
  }) async {
    if (token.isEmpty) {
      throw const MediaApiException('Plex 需要在密码框填写 X-Plex-Token');
    }
    final base = baseUrl.replaceAll(RegExp(r'/+$'), '');
    try {
      final response = await _dio.get<Map<String, dynamic>>(
        '$base/',
        options: Options(
          headers: {'X-Plex-Token': token, 'X-Plex-Product': 'MoonTV'},
        ),
      );
      final container = response.data?['MediaContainer'];
      if (container is! Map) {
        throw const MediaApiException('地址不是可用的 Plex 服务器');
      }
      return MediaAccount(
        type: MediaServerType.plex,
        baseUrl: base,
        serverName: _str(container['friendlyName'], fallback: 'Plex'),
        userId: 'plex',
        userName: username.isEmpty ? 'Plex' : username,
        accessToken: token,
        deviceId: deviceId,
      );
    } on DioException catch (error) {
      throw MediaApiException(_friendly(error, login: true));
    }
  }

  Future<List<MediaLibrary>> libraries(MediaAccount account) async {
    if (account.isPlex) return _plexLibraries(account);
    final data = await _get(account, '/Users/${account.userId}/Views');
    return _items(data).map(MediaLibrary.fromJson).toList(growable: false);
  }

  Future<List<MediaItem>> favorites(
    MediaAccount account, {
    int limit = 200,
  }) async {
    if (account.isPlex) return const [];
    final data = await _get(
      account,
      '/Users/${account.userId}/Items',
      query: {
        'Filters': 'IsFavorite',
        'Recursive': 'true',
        'IncludeItemTypes': 'Movie,Series,Episode',
        'Fields': _fields,
        'EnableUserData': 'true',
        'ImageTypeLimit': '1',
        'EnableImageTypes': 'Primary,Backdrop',
        'SortBy': 'SortName',
        'SortOrder': 'Ascending',
        'Limit': '$limit',
      },
    );
    return _items(data).map(MediaItem.fromJson).toList(growable: false);
  }

  Future<List<MediaItem>> search(
    MediaAccount account,
    String query, {
    int limit = 40,
  }) async {
    final term = query.trim();
    if (term.isEmpty || account.isPlex) return const [];
    final data = await _get(
      account,
      '/Users/${account.userId}/Items',
      query: {
        'SearchTerm': term,
        'Recursive': 'true',
        'IncludeItemTypes': 'Movie,Series',
        'Fields': _fields,
        'EnableUserData': 'true',
        'ImageTypeLimit': '1',
        'EnableImageTypes': 'Primary,Backdrop',
        'SortBy': 'SortName',
        'SortOrder': 'Ascending',
        'Limit': '$limit',
      },
    );
    return _items(data).map(MediaItem.fromJson).toList(growable: false);
  }

  Future<List<MediaItem>> resume(MediaAccount account, {int limit = 12}) async {
    if (account.isPlex) {
      final data = await _plexGet(account, '/library/onDeck');
      final videos = _plexContainer(data)['Video'];
      if (videos is! List) return const [];
      return videos
          .whereType<Map>()
          .map((json) => _plexItemFromJson(json.cast<String, dynamic>()))
          .where((item) => item.positionTicks > 0 && !item.isPlayed)
          .take(limit)
          .toList(growable: false);
    }
    final data = await _get(
      account,
      '/Users/${account.userId}/Items/Resume',
      query: {
        'Limit': '$limit',
        'MediaTypes': 'Video',
        'Fields': _fields,
        'ImageTypeLimit': '1',
        'EnableImageTypes': 'Primary,Backdrop',
      },
    );
    return _items(data).map(MediaItem.fromJson).toList(growable: false);
  }

  Future<(List<MediaItem>, int)> items(
    MediaAccount account, {
    required String libraryId,
    int startIndex = 0,
    int limit = 30,
    String? searchTerm,
  }) async {
    if (account.isPlex) {
      return _plexItems(
        account,
        libraryId: libraryId,
        startIndex: startIndex,
        limit: limit,
        searchTerm: searchTerm,
      );
    }
    final query = <String, String>{
      'ParentId': libraryId,
      'IncludeItemTypes': 'Movie,Series',
      'Recursive': 'true',
      'Fields': _fields,
      'ImageTypeLimit': '1',
      'EnableImageTypes': 'Primary,Backdrop',
      'SortBy': searchTerm == null ? 'SortName' : 'SortName',
      'SortOrder': 'Ascending',
      'Limit': '$limit',
      'StartIndex': '$startIndex',
      if (searchTerm != null && searchTerm.trim().isNotEmpty)
        'SearchTerm': searchTerm.trim(),
    };
    final data = await _get(
      account,
      '/Users/${account.userId}/Items',
      query: query,
    );
    final total = _int(data['TotalRecordCount']) ?? 0;
    return (
      _items(data).map(MediaItem.fromJson).toList(growable: false),
      total,
    );
  }

  Future<MediaItem> item(MediaAccount account, String id) async {
    if (account.isPlex) {
      final item = await _plexItem(account, id);
      return item;
    }
    final data = await _get(
      account,
      '/Users/${account.userId}/Items/$id',
      query: {'Fields': _fields},
    );
    return MediaItem.fromJson(data);
  }

  Future<MediaDetailData> detail(MediaAccount account, MediaItem base) async {
    if (account.isPlex) {
      final item = await _plexItem(account, base.id);
      if (!item.isSeries) return MediaDetailData(item: item);
      final children = await _plexChildren(account, base.id);
      if (children.isEmpty) return MediaDetailData(item: item);
      if (children.every((child) => child.isEpisode)) {
        return MediaDetailData(item: item, episodes: children);
      }
      final seasons = children.where((child) => child.isSeason).toList();
      final episodes = <MediaItem>[];
      for (final season in seasons) {
        final items = await _plexChildren(account, season.id);
        episodes.addAll(items.where((child) => child.isEpisode));
      }
      return MediaDetailData(
        item: item,
        seasons: seasons.isEmpty ? children : seasons,
        episodes: episodes,
      );
    }
    final item = base.overview.isEmpty || base.runtimeTicks == 0
        ? await this.item(account, base.id)
        : base;
    if (!item.isSeries) return MediaDetailData(item: item);
    final seasonsData = await _get(
      account,
      '/Shows/${item.id}/Seasons',
      query: {
        'userId': account.userId,
        'Fields': _fields,
        'EnableImages': 'true',
      },
    );
    final seasons = _items(seasonsData)
        .map(MediaItem.fromJson)
        .toList(growable: false);
    final episodesData = await _get(
      account,
      '/Shows/${item.id}/Episodes',
      query: {
        'userId': account.userId,
        'Fields': _fields,
        'EnableImages': 'true',
        'EnableUserData': 'true',
      },
    );
    final episodes = _items(episodesData)
        .map(MediaItem.fromJson)
        .toList(growable: false);
    return MediaDetailData(item: item, seasons: seasons, episodes: episodes);
  }

  String streamUrl(MediaAccount account, MediaItem item) {
    final base = account.baseUrl;
    if (account.isPlex) {
      return '$base/library/parts/${item.mediaSourceId ?? item.id}/stream'
          '?X-Plex-Token=${Uri.encodeQueryComponent(account.accessToken)}';
    }
    final query = Uri(
      queryParameters: {
        'static': 'true',
        'api_key': account.accessToken,
        if (item.mediaSourceId != null && item.mediaSourceId!.isNotEmpty)
          'mediaSourceId': item.mediaSourceId!,
        'DeviceId': account.deviceId,
      },
    ).query;
    return '$base/Videos/${item.id}/stream?$query';
  }

  Future<void> reportStart(
    MediaAccount account,
    MediaItem item,
    Duration position,
  ) async {
    if (account.isPlex) {
      await _plexTimeline(account, item, position, state: 'playing');
      return;
    }
    await _post(account, '/Sessions/Playing', {
      ..._sessionBody(account, item, position),
      'CanSeek': true,
    });
  }

  Future<void> reportProgress(
    MediaAccount account,
    MediaItem item,
    Duration position, {
    bool paused = false,
    Duration? duration,
  }) async {
    if (account.isPlex) {
      await _plexTimeline(
        account,
        item,
        position,
        state: paused ? 'paused' : 'playing',
        duration: duration,
      );
      return;
    }
    await _post(account, '/Sessions/Playing/Progress', {
      ..._sessionBody(account, item, position),
      'IsPaused': paused,
    });
  }

  Future<void> reportStopped(
    MediaAccount account,
    MediaItem item,
    Duration position,
  ) async {
    if (account.isPlex) {
      await _plexTimeline(account, item, position, state: 'stopped');
      return;
    }
    await _post(account, '/Sessions/Playing/Stopped', {
      ..._sessionBody(account, item, position),
      'PositionTicks': position.inMicroseconds * 10,
    });
  }

  Future<void> setFavorite(
    MediaAccount account,
    MediaItem item,
    bool favorite,
  ) async {
    if (account.isPlex) {
      throw const MediaApiException('Plex 的收藏请在 Plex 客户端中管理');
    }
    try {
      await _dio.request<dynamic>(
        '${account.baseUrl}/Users/${account.userId}/FavoriteItems/${item.id}',
        options: Options(
          method: favorite ? 'POST' : 'DELETE',
          headers: _headers(account),
          responseType: ResponseType.plain,
        ),
      );
    } on DioException catch (error) {
      throw MediaApiException(_friendly(error));
    }
  }

  Future<void> _plexTimeline(
    MediaAccount account,
    MediaItem item,
    Duration position, {
    required String state,
    Duration? duration,
  }) async {
    final totalMs =
        duration?.inMilliseconds ??
        (item.runtimeTicks > 0 ? item.runtimeTicks ~/ 10000 : 0);
    try {
      await _dio.get<dynamic>(
        '${account.baseUrl}/:/timeline',
        queryParameters: {
          'ratingKey': item.id,
          'key': '/library/metadata/${item.id}',
          'state': state,
          'time': '${position.inMilliseconds}',
          if (totalMs > 0) 'duration': '$totalMs',
        },
        options: Options(
          headers: {
            'X-Plex-Token': account.accessToken,
            'X-Plex-Product': 'MoonTV',
          },
        ),
      );
    } on DioException {
      // Plex still records progress for some server versions even when the
      // timeline endpoint returns an empty/non-JSON response.
    }
  }

  Map<String, dynamic> _sessionBody(
    MediaAccount account,
    MediaItem item,
    Duration position,
  ) => {
    'ItemId': item.id,
    'MediaSourceId': item.mediaSourceId,
    'PositionTicks': position.inMicroseconds * 10,
    'PlayMethod': 'DirectPlay',
    'PlaySessionId': 'moonbox-${account.deviceId}-${item.id}',
    'CanSeek': true,
  };

  Future<Map<String, dynamic>> _get(
    MediaAccount account,
    String path, {
    Map<String, String>? query,
  }) async {
    try {
      final response = await _dio.get<Map<String, dynamic>>(
        '${account.baseUrl}$path',
        queryParameters: query,
        options: Options(headers: _headers(account)),
      );
      return response.data ?? const <String, dynamic>{};
    } on DioException catch (error) {
      throw MediaApiException(_friendly(error));
    }
  }

  Future<Map<String, dynamic>> _post(
    MediaAccount account,
    String path,
    Map<String, dynamic> body,
  ) async {
    try {
      final response = await _dio.post<Map<String, dynamic>>(
        '${account.baseUrl}$path',
        data: body,
        options: Options(headers: _headers(account)),
      );
      return response.data ?? const <String, dynamic>{};
    } on DioException catch (error) {
      throw MediaApiException(_friendly(error));
    }
  }

  Map<String, String> _headers(MediaAccount account) => {
    'X-Emby-Token': account.accessToken,
    'X-Emby-Authorization': _authHeader(account.deviceId, account.accessToken),
  };

  String _authHeader(String deviceId, String? token) =>
      'MediaBrowser Client="MoonTV", Device="Android", '
      'DeviceId="$deviceId", Version="1.4.0"'
      '${token == null ? '' : ', Token="$token"'}';

  Future<String> _serverName(String base, String token) async {
    try {
      final response = await _dio.get<Map<String, dynamic>>(
        '$base/System/Info/Public',
        options: Options(headers: {'X-Emby-Token': token}),
      );
      return _str(response.data?['ServerName'], fallback: '媒体服务器');
    } catch (_) {
      return '媒体服务器';
    }
  }

  List<Map<String, dynamic>> _items(Map<String, dynamic> data) {
    final items = data['Items'];
    if (items is! List) return const [];
    return items
        .whereType<Map>()
        .map((item) => item.cast<String, dynamic>())
        .toList();
  }

  String _normalizeBase(String input) {
    var value = input.trim();
    if (value.isEmpty) throw const MediaApiException('请输入服务器地址');
    if (!value.contains('://')) value = 'https://$value';
    final uri = Uri.tryParse(value);
    if (uri == null || (uri.scheme != 'http' && uri.scheme != 'https')) {
      throw const MediaApiException('只支持 HTTP/HTTPS 服务器地址');
    }
    return value.replaceAll(RegExp(r'/+$'), '');
  }

  String _friendly(DioException error, {bool login = false}) {
    final status = error.response?.statusCode;
    if (status == 401) {
      return login ? '用户名或密码不正确' : '登录已过期，请重新连接服务器';
    }
    if (status == 404) {
      return login ? '地址不是可用的 Jellyfin/Emby/Plex 服务器' : '服务器接口不存在';
    }
    if (status != null) return '服务器返回 HTTP $status';
    switch (error.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.receiveTimeout:
      case DioExceptionType.sendTimeout:
        return '连接超时，请检查服务器地址或网络';
      case DioExceptionType.connectionError:
        return '无法连接服务器，请检查地址和网络';
      case DioExceptionType.badCertificate:
        return '服务器证书无效';
      default:
        return '请求失败：${error.message ?? error.type.name}';
    }
  }

  // ---- Plex JSON endpoints -------------------------------------------------

  Future<List<MediaLibrary>> _plexLibraries(MediaAccount account) async {
    final data = await _plexGet(account, '/library/sections');
    final dirs = _plexContainer(data)['Directory'];
    if (dirs is! List) return const [];
    return dirs
        .whereType<Map>()
        .map((json) {
          final map = json.cast<String, dynamic>();
          final kind = _str(map['type']);
          return MediaLibrary(
            id: _str(map['key']),
            name: _str(map['title'], fallback: 'Plex 媒体库'),
            collectionType: switch (kind) {
              'movie' => 'movies',
              'show' => 'tvshows',
              'artist' => 'music',
              _ => kind,
            },
          );
        })
        .toList(growable: false);
  }

  Future<(List<MediaItem>, int)> _plexItems(
    MediaAccount account, {
    required String libraryId,
    required int startIndex,
    required int limit,
    String? searchTerm,
  }) async {
    final data = await _plexGet(
      account,
      searchTerm != null && searchTerm.trim().isNotEmpty
          ? '/library/sections/$libraryId/search'
          : '/library/sections/$libraryId/all',
      query: {
        'X-Plex-Container-Start': '$startIndex',
        'X-Plex-Container-Size': '$limit',
        if (searchTerm != null && searchTerm.trim().isNotEmpty)
          'query': searchTerm.trim(),
      },
    );
    final container = _plexContainer(data);
    final videos = container['Video'];
    final directories = container['Directory'];
    final raw = <Map>[
      if (videos is List) ...videos.whereType<Map>(),
      if (directories is List) ...directories.whereType<Map>(),
    ];
    final items = raw
        .map((json) {
          return _plexItemFromJson(json.cast<String, dynamic>());
        })
        .toList(growable: false);
    return (items, _int(container['totalSize']) ?? items.length);
  }

  Future<MediaItem> _plexItem(MediaAccount account, String id) async {
    final data = await _plexGet(
      account,
      '/library/metadata/$id',
      query: {'includeMediaSources': '1'},
    );
    final container = _plexContainer(data);
    final videos = container['Video'];
    if (videos is List && videos.isNotEmpty) {
      return _plexItemFromJson((videos.first as Map).cast<String, dynamic>());
    }
    final directories = container['Directory'];
    if (directories is List && directories.isNotEmpty) {
      return _plexItemFromJson(
        (directories.first as Map).cast<String, dynamic>(),
      );
    }
    throw const MediaApiException('Plex 没有返回这个条目');
  }

  Future<List<MediaItem>> _plexChildren(MediaAccount account, String id) async {
    final data = await _plexGet(account, '/library/metadata/$id/children');
    final container = _plexContainer(data);
    final raw = <Map>[
      if (container['Video'] is List)
        ...(container['Video'] as List).whereType<Map>(),
      if (container['Directory'] is List)
        ...(container['Directory'] as List).whereType<Map>(),
    ];
    return raw
        .map((json) => _plexItemFromJson(json.cast<String, dynamic>()))
        .toList(growable: false);
  }

  Future<Map<String, dynamic>> _plexGet(
    MediaAccount account,
    String path, {
    Map<String, String>? query,
  }) async {
    try {
      final response = await _dio.get<Map<String, dynamic>>(
        '${account.baseUrl}$path',
        queryParameters: query,
        options: Options(
          headers: {
            'X-Plex-Token': account.accessToken,
            'X-Plex-Product': 'MoonTV',
            'Accept': 'application/json',
          },
        ),
      );
      return response.data ?? const <String, dynamic>{};
    } on DioException catch (error) {
      throw MediaApiException(_friendly(error));
    }
  }

  Map<String, dynamic> _plexContainer(Map<String, dynamic> data) {
    final value = data['MediaContainer'];
    return value is Map ? value.cast<String, dynamic>() : const {};
  }

  MediaItem _plexItemFromJson(Map<String, dynamic> json) {
    final type = _str(json['type']);
    final media = json['Media'];
    final firstMedia = media is List && media.isNotEmpty ? media.first : null;
    final part = firstMedia is Map ? firstMedia['Part'] : null;
    final firstPart = part is List && part.isNotEmpty ? part.first : null;
    final image = _str(json['thumb']);
    final backdrop = _str(json['art']);
    return MediaItem(
      id: _str(json['ratingKey']),
      name: _str(json['title'], fallback: '未命名'),
      type: type == 'show'
          ? 'Series'
          : type == 'season'
          ? 'Season'
          : type == 'episode'
          ? 'Episode'
          : 'Movie',
      overview: _str(json['summary']),
      productionYear: _int(json['year']),
      runtimeTicks: (_int(json['duration']) ?? 0) * 10000,
      imageTag: image.isEmpty ? null : image,
      backdropTag: backdrop.isEmpty ? null : backdrop,
      seriesId: _str(json['grandparentRatingKey']).isEmpty
          ? null
          : _str(json['grandparentRatingKey']),
      seriesName: _str(json['grandparentTitle']).isEmpty
          ? null
          : _str(json['grandparentTitle']),
      seasonId: _str(json['parentRatingKey']).isEmpty
          ? null
          : _str(json['parentRatingKey']),
      seasonName: _str(json['parentTitle']).isEmpty
          ? null
          : _str(json['parentTitle']),
      indexNumber: _int(json['index']),
      parentIndexNumber: _int(json['parentIndex']),
      officialRating: _str(json['contentRating']),
      communityRating: _double(json['rating']),
      genres: const [],
      mediaSourceId: firstPart is Map ? _str(firstPart['id']) : null,
      positionTicks: (_int(json['viewOffset']) ?? 0) * 10000,
      playedPercentage: null,
      isPlayed:
          _int(json['viewCount']) != null && (_int(json['viewCount']) ?? 0) > 0,
      mediaType: 'Video',
    );
  }
}

const _fields =
    'PrimaryImageAspectRatio,Overview,ProductionYear,RunTimeTicks,Genres,'
    'CommunityRating,OfficialRating,MediaSources,UserData,SeriesId,SeriesName,'
    'SeasonId,SeasonName,IndexNumber,ParentIndexNumber,BackdropImageTags,'
    'ParentBackdropItemId,ParentBackdropImageTags';

String _str(Object? value, {String fallback = ''}) {
  if (value == null) return fallback;
  final text = value.toString();
  return text.isEmpty ? fallback : text;
}

int? _int(Object? value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  return int.tryParse(value?.toString() ?? '');
}

double? _double(Object? value) {
  if (value is num) return value.toDouble();
  return double.tryParse(value?.toString() ?? '');
}

final _random = Random.secure();

String makeDeviceId() {
  final stamp = DateTime.now().microsecondsSinceEpoch;
  final suffix = List.generate(
    6,
    (_) => _random.nextInt(16).toRadixString(16),
  ).join();
  return 'moonbox-$stamp-$suffix';
}
