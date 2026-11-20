enum MediaServerType { jellyfin, emby, plex }

extension MediaServerTypeLabel on MediaServerType {
  String get label => switch (this) {
    MediaServerType.jellyfin => 'Jellyfin',
    MediaServerType.emby => 'Emby',
    MediaServerType.plex => 'Plex',
  };

  String get hint => switch (this) {
    MediaServerType.jellyfin => 'Jellyfin 10.x',
    MediaServerType.emby => 'Emby 4.x',
    MediaServerType.plex => 'Plex Media Server',
  };
}

class MediaAccount {
  const MediaAccount({
    required this.type,
    required this.baseUrl,
    required this.serverName,
    required this.userId,
    required this.userName,
    required this.accessToken,
    required this.deviceId,
  });

  final MediaServerType type;
  final String baseUrl;
  final String serverName;
  final String userId;
  final String userName;
  final String accessToken;
  final String deviceId;

  bool get isPlex => type == MediaServerType.plex;

  Map<String, dynamic> toJson() => {
    'type': type.name,
    'baseUrl': baseUrl,
    'serverName': serverName,
    'userId': userId,
    'userName': userName,
    'accessToken': accessToken,
    'deviceId': deviceId,
  };

  factory MediaAccount.fromJson(Map<String, dynamic> json) {
    final typeName = _str(json['type']);
    return MediaAccount(
      type: MediaServerType.values.firstWhere(
        (value) => value.name == typeName,
        orElse: () => MediaServerType.jellyfin,
      ),
      baseUrl: _str(json['baseUrl']),
      serverName: _str(json['serverName']),
      userId: _str(json['userId']),
      userName: _str(json['userName']),
      accessToken: _str(json['accessToken']),
      deviceId: _str(json['deviceId']),
    );
  }
}

class MediaLibrary {
  const MediaLibrary({
    required this.id,
    required this.name,
    required this.collectionType,
    this.imageTag,
  });

  final String id;
  final String name;
  final String collectionType;
  final String? imageTag;

  String get kindLabel => switch (collectionType) {
    'movies' => '电影',
    'tvshows' => '剧集',
    'music' => '音乐',
    'boxsets' => '合集',
    'playlists' => '播放列表',
    'livetv' => '直播',
    _ => '媒体库',
  };

  factory MediaLibrary.fromJson(Map<String, dynamic> json) {
    final tags = json['ImageTags'];
    return MediaLibrary(
      id: _str(json['Id']),
      name: _str(json['Name'], fallback: '未命名媒体库'),
      collectionType: _str(json['CollectionType']),
      imageTag: tags is Map ? _str(tags['Primary']) : null,
    );
  }
}

class MediaItem {
  const MediaItem({
    required this.id,
    required this.name,
    required this.type,
    this.overview = '',
    this.productionYear,
    this.runtimeTicks = 0,
    this.imageTag,
    this.backdropTag,
    this.seriesId,
    this.seriesName,
    this.seasonId,
    this.seasonName,
    this.indexNumber,
    this.parentIndexNumber,
    this.officialRating = '',
    this.communityRating,
    this.genres = const [],
    this.mediaSourceId,
    this.positionTicks = 0,
    this.playedPercentage,
    this.isPlayed = false,
    this.isFavorite = false,
    this.mediaType = '',
    this.albumArtist = '',
  });

  final String id;
  final String name;
  final String type;
  final String overview;
  final int? productionYear;
  final int runtimeTicks;
  final String? imageTag;
  final String? backdropTag;
  final String? seriesId;
  final String? seriesName;
  final String? seasonId;
  final String? seasonName;
  final int? indexNumber;
  final int? parentIndexNumber;
  final String officialRating;
  final double? communityRating;
  final List<String> genres;
  final String? mediaSourceId;
  final int positionTicks;
  final double? playedPercentage;
  final bool isPlayed;
  final bool isFavorite;
  final String mediaType;
  final String albumArtist;

  bool get isSeries => type == 'Series';
  bool get isSeason => type == 'Season';
  bool get isEpisode => type == 'Episode';
  bool get isMovie => type == 'Movie';
  bool get isPlayable => isMovie || isEpisode || type == 'Video';
  bool get hasProgress => positionTicks > 0 && !isPlayed;

  int? get runtimeMinutes =>
      runtimeTicks > 0 ? (runtimeTicks / 600000000).round() : null;

  double get progressFraction {
    if (playedPercentage != null) return (playedPercentage! / 100).clamp(0, 1);
    if (runtimeTicks <= 0) return 0;
    return (positionTicks / runtimeTicks).clamp(0, 1);
  }

  String get subtitle {
    final bits = <String>[];
    if (isEpisode && parentIndexNumber != null && indexNumber != null) {
      bits.add('S${parentIndexNumber!}E${indexNumber!}');
    }
    if (productionYear != null) bits.add('${productionYear!}');
    if (isEpisode && seasonName != null && seasonName!.isNotEmpty) {
      bits.add(seasonName!);
    } else if (isSeries && seriesName != null && seriesName!.isNotEmpty) {
      bits.add(seriesName!);
    }
    if (runtimeMinutes != null) bits.add('${runtimeMinutes!} 分钟');
    return bits.join(' · ');
  }

  String imageUrl(
    MediaAccount account, {
    int maxHeight = 600,
    bool backdrop = false,
  }) {
    final base = account.baseUrl.endsWith('/')
        ? account.baseUrl.substring(0, account.baseUrl.length - 1)
        : account.baseUrl;
    final tag = backdrop ? backdropTag : imageTag;
    if (account.isPlex) {
      if (tag == null || tag.isEmpty) return '';
      final separator = tag.contains('?') ? '&' : '?';
      return '$base$tag${separator}X-Plex-Token='
          '${Uri.encodeQueryComponent(account.accessToken)}&height=$maxHeight';
    }
    final idForImage =
        (imageTag == null || imageTag!.isEmpty) &&
            seriesId != null &&
            seriesId!.isNotEmpty
        ? seriesId!
        : id;
    final path = backdrop ? 'Backdrop/0' : 'Primary';
    final query = Uri(
      queryParameters: {
        'maxHeight': '$maxHeight',
        'quality': '90',
        'api_key': account.accessToken,
        if (tag != null && tag.isNotEmpty) 'tag': tag,
      },
    ).query;
    return '$base/Items/$idForImage/Images/$path?$query';
  }

  factory MediaItem.fromJson(Map<String, dynamic> json) {
    final tags = json['ImageTags'];
    final backdropTags = json['BackdropImageTags'];
    final userData = json['UserData'];
    final sources = json['MediaSources'];
    final genres = json['Genres'];
    final seriesId = _str(json['SeriesId']);
    final seriesName = _str(json['SeriesName']);
    final mediaSources = sources is List && sources.isNotEmpty
        ? sources.first
        : null;
    return MediaItem(
      id: _str(json['Id']),
      name: _str(json['Name'], fallback: '未命名'),
      type: _str(json['Type']),
      overview: _str(json['Overview']),
      productionYear: _int(json['ProductionYear']),
      runtimeTicks: _int(json['RunTimeTicks']) ?? 0,
      imageTag: tags is Map ? _str(tags['Primary']) : null,
      backdropTag: backdropTags is List && backdropTags.isNotEmpty
          ? _str(backdropTags.first)
          : (json['ParentBackdropImageTags'] is List &&
                    (json['ParentBackdropImageTags'] as List).isNotEmpty
                ? _str((json['ParentBackdropImageTags'] as List).first)
                : null),
      seriesId: seriesId.isEmpty ? null : seriesId,
      seriesName: seriesName.isEmpty ? null : seriesName,
      seasonId: _str(json['SeasonId']).isEmpty ? null : _str(json['SeasonId']),
      seasonName: _str(json['SeasonName']).isEmpty
          ? null
          : _str(json['SeasonName']),
      indexNumber: _int(json['IndexNumber']),
      parentIndexNumber: _int(json['ParentIndexNumber']),
      officialRating: _str(json['OfficialRating']),
      communityRating: _double(json['CommunityRating']),
      genres: genres is List
          ? genres.map((value) => value.toString()).toList(growable: false)
          : const [],
      mediaSourceId: mediaSources is Map ? _str(mediaSources['Id']) : null,
      positionTicks: userData is Map
          ? _int(userData['PlaybackPositionTicks']) ?? 0
          : 0,
      playedPercentage: userData is Map
          ? _double(userData['PlayedPercentage'])
          : null,
      isPlayed: userData is Map && userData['Played'] == true,
      isFavorite: userData is Map && userData['IsFavorite'] == true,
      mediaType: _str(json['MediaType']),
      albumArtist: _str(json['AlbumArtist']),
    );
  }
}

class MediaDetailData {
  const MediaDetailData({
    required this.item,
    this.seasons = const [],
    this.episodes = const [],
  });

  final MediaItem item;
  final List<MediaItem> seasons;
  final List<MediaItem> episodes;
}

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
