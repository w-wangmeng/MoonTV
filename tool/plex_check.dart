import 'package:moonbox/media/media_api.dart';
import 'package:moonbox/media/media_models.dart';

Future<void> main() async {
  final api = MediaApi();
  final account = await api.login(
    type: MediaServerType.plex,
    baseUrl: 'http://127.0.0.1:8099',
    username: 'PlexUser',
    password: 'mock-plex-token',
    deviceId: 'plex-test-device',
  );
  print('login: ${account.serverName} / ${account.userName}');

  final libraries = await api.libraries(account);
  for (final library in libraries) {
    print('library: ${library.id} ${library.name} ${library.collectionType}');
  }

  final movies = await api.items(
    account,
    libraryId: libraries.firstWhere((l) => l.collectionType == 'movies').id,
  );
  print('movies: ${movies.$2}');
  for (final item in movies.$1) {
    print('  ${item.id} ${item.name} ${item.type} ${item.mediaSourceId}');
  }

  final showLibrary = libraries.firstWhere(
    (l) => l.collectionType == 'tvshows',
  );
  final shows = await api.items(account, libraryId: showLibrary.id);
  final show = shows.$1.first;
  print('show: ${show.id} ${show.name} ${show.type}');
  final detail = await api.detail(account, show);
  print(
    'detail: seasons=${detail.seasons.length} episodes=${detail.episodes.length}',
  );
  for (final episode in detail.episodes) {
    print(
      '  episode: ${episode.id} ${episode.name} part=${episode.mediaSourceId}',
    );
    print('  stream: ${api.streamUrl(account, episode)}');
  }

  final movie = movies.$1.first;
  print('movie detail: ${(await api.detail(account, movie)).item.name}');
  print('movie stream: ${api.streamUrl(account, movie)}');

  final resume = await api.resume(account);
  print('resume: ${resume.length}');
  for (final item in resume) {
    print('  ${item.id} ${item.name} ${item.positionTicks}');
  }

  await api.reportStart(account, movie, const Duration(seconds: 3));
  await api.reportProgress(
    account,
    movie,
    const Duration(seconds: 4),
    duration: const Duration(seconds: 60),
  );
  await api.reportStopped(account, movie, const Duration(seconds: 5));
  print('plex progress calls completed');

  final emby = await api.login(
    type: MediaServerType.emby,
    baseUrl: 'http://127.0.0.1:8099',
    username: 'demo',
    password: 'demo',
    deviceId: 'emby-test-device',
  );
  final embyLibraries = await api.libraries(emby);
  print('emby: ${emby.serverName} / libraries=${embyLibraries.length}');
  final embyMovies = await api.items(emby, libraryId: embyLibraries.first.id);
  print('emby movies: ${embyMovies.$2}');
}
