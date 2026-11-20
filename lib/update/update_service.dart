import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/services.dart';

/// 当前应用版本（跟随每个版本号的发布更新，与 pubspec 保持一致）。
const String kAppVersion = '1.4.0';

/// 发布更新所用的 GitHub 仓库（常用格式 owner/repo）。
const String kGitHubRepo = 'w-wangmeng/MoonTV';

/// 检查更新走 Android 侧目录/安装通道。
const MethodChannel _updateChannel = MethodChannel('moonbox/update');

String get _apiBase =>
    'https://api.github.com/repos/$kGitHubRepo/releases/latest';

/// GitHub 最新 Release 中解析出的可下载信息。
class ReleaseInfo {
  const ReleaseInfo({
    required this.tagName,
    required this.version,
    required this.name,
    required this.body,
    required this.apkUrl,
    this.apkSize,
  });

  final String tagName;
  final String version;
  final String name;
  final String body;
  final String apkUrl;
  final int? apkSize;

  bool get isNewer => compareVersions(version, kAppVersion) > 0;
}

/// 逐段比较形如 "1.4.0" 的版本号，a>b 返回正数。
int compareVersions(String a, String b) {
  final aa = a.replaceFirst(RegExp(r'^v'), '').split('.');
  final bb = b.replaceFirst(RegExp(r'^v'), '').split('.');
  final n = aa.length > bb.length ? aa.length : bb.length;
  for (var i = 0; i < n; i++) {
    final x = int.tryParse(i < aa.length ? aa[i] : '0') ?? 0;
    final y = int.tryParse(i < bb.length ? bb[i] : '0') ?? 0;
    if (x != y) return x.compareTo(y);
  }
  return 0;
}

/// 负责查询 GitHub 最新版本、下载并调用系统安装器。
class UpdateService {
  UpdateService()
    : _dio = Dio(
        BaseOptions(
          headers: const {
            'User-Agent': 'MoonTV/$kAppVersion (Android)',
            'Accept': 'application/vnd.github+json',
          },
          connectTimeout: const Duration(seconds: 12),
          receiveTimeout: const Duration(seconds: 20),
        ),
      );

  final Dio _dio;

  /// 查询最新 Release；失败或没有可用 APK 时返回 null。
  Future<ReleaseInfo?> checkLatest() async {
    try {
      final resp = await _dio.get<Map<String, dynamic>>(_apiBase);
      if (resp.statusCode != 200) return null;
      final data = resp.data;
      if (data == null) return null;
      final tag = data['tag_name'] as String? ?? '';
      if (tag.isEmpty) return null;

      Map<String, dynamic>? apkAsset;
      final assets = data['assets'] as List? ?? const [];
      for (final raw in assets) {
        final name = (raw is Map ? raw['name'] as String? : null) ?? '';
        // 优先 arm64 通用包，其次任意 .apk。
        if (name.endsWith('-arm64.apk') || name.endsWith('.apk')) {
          apkAsset = raw as Map<String, dynamic>?;
          break;
        }
      }
      final url = apkAsset?['browser_download_url'] as String? ?? '';
      if (url.isEmpty) return null;

      return ReleaseInfo(
        tagName: tag,
        version: tag.replaceFirst(RegExp(r'^v'), ''),
        name: data['name'] as String? ?? tag,
        body: data['body'] as String? ?? '',
        apkUrl: url,
        apkSize: apkAsset?['size'] as int?,
      );
    } catch (_) {
      return null;
    }
  }

  /// 下载 APK 到应用内部目录，返回本地完整路径。
  ///
  /// [onProgress] 收到 (已下载字节, 总字节)。
  Future<String> downloadApk(
    ReleaseInfo info, {
    void Function(int received, int? total)? onProgress,
  }) async {
    final dir = await getDownloadDirectory();
    final path = '$dir/MoonTV-${info.version}.apk';
    await _dio.download(
      info.apkUrl,
      path,
      onReceiveProgress: onProgress,
      deleteOnError: true,
    );
    return path;
  }

  /// 请求 Android 侧的安装器目录；非 Android 或异常时退回系统临时目录。
  Future<String> getDownloadDirectory() async {
    try {
      final dir = await _updateChannel.invokeMethod<String>(
        'getDownloadDirectory',
      );
      if (dir != null && dir.isNotEmpty) return dir;
    } catch (_) {
      // 忽略，走兜底。
    }
    return Directory.systemTemp.path;
  }

  /// 调用系统安装器安装指定 APK；返回是否成功唤起安装界面。
  Future<bool> requestInstall(String apkPath) async {
    if (apkPath.isEmpty || !File(apkPath).existsSync()) return false;
    try {
      final ok = await _updateChannel.invokeMethod<bool>('installApk', {
        'path': apkPath,
      });
      return ok ?? false;
    } catch (_) {
      return false;
    }
  }
}
