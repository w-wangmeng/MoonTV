import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'update_service.dart';

const String _notifiedKey = 'moonbox.update.notified.v1';
final UpdateService _service = UpdateService();

/// 手动检查（设置页）：总是弹出结果。
Future<void> checkForUpdates(BuildContext context) => _showCheck(context);

/// 启动时自动检查：仅在有新版本且本机尚未针对该版本提示过时才弹窗，
/// 避免每次启动都打扰用户；失败或已是最新则静默。
Future<void> maybePromptUpdate(BuildContext context) async {
  final latest = await _service.checkLatest();
  if (latest == null || !latest.isNewer || !context.mounted) return;
  final prefs = await SharedPreferences.getInstance();
  final notified = prefs.getString(_notifiedKey) ?? '';
  if (notified == latest.version) return;
  // 先记录版本：即使本次下载/忽略，也不再重复打扰。
  await prefs.setString(_notifiedKey, latest.version);
  if (!context.mounted) return;
  final confirmed = await _showUpdateDialog(context, latest);
  if (!context.mounted) return;
  if (confirmed) await _startDownload(context, latest);
}

Future<void> _showCheck(BuildContext context) async {
  final latest = await _service.checkLatest();
  if (!context.mounted) return;
  if (latest == null) {
    await _showMessage(
      context,
      icon: Icons.cloud_off_rounded,
      title: '暂时无法检查更新',
      body: '连接 GitHub 失败，或仓库里没有可用的安装包。请检查网络后重试。',
    );
    return;
  }
  if (!latest.isNewer) {
    await _showMessage(
      context,
      icon: Icons.check_circle_outline_rounded,
      color: _UpdateColors.success,
      title: '已是最新版本',
      body: '当前版本 v$kAppVersion，无需更新。',
    );
    return;
  }
  final confirmed = await _showUpdateDialog(context, latest);
  if (!context.mounted) return;
  if (confirmed) await _startDownload(context, latest);
}

Future<void> _startDownload(BuildContext context, ReleaseInfo latest) async {
  final progress = ValueNotifier<double>(0);
  showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (_) =>
        _DownloadDialog(progress: progress, version: latest.version),
  );

  String? apkPath;
  try {
    apkPath = await _service.downloadApk(
      latest,
      onProgress: (received, total) {
        final size = total ?? latest.apkSize ?? 0;
        progress.value = size > 0 ? (received / size).clamp(0.0, 1.0) : 0.0;
      },
    );
  } catch (_) {
    progress.value = -1; // 标记失败
  }
  if (!context.mounted) return;

  final succeeded = apkPath != null && await _service.requestInstall(apkPath);
  if (!context.mounted) return;
  Navigator.of(context, rootNavigator: true).pop(); // 关掉进度框

  await _showMessage(
    context,
    icon: succeeded
        ? Icons.system_update_alt_rounded
        : Icons.error_outline_rounded,
    color: succeeded ? _UpdateColors.success : _UpdateColors.danger,
    title: succeeded ? '正在安装新版本' : '更新未完成',
    body: succeeded
        ? 'v${latest.version} 安装包已打开，请按系统提示完成安装。'
        : apkPath == null
        ? '下载失败，请稍后重试。'
        : 'APK 已下载，但无法唤起系统安装器。请在系统设置中允许安装未知来源应用后再试。',
  );
}

Future<bool> _showUpdateDialog(BuildContext context, ReleaseInfo latest) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text('发现新版本 v${latest.version}'),
      content: SizedBox(
        width: 480,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '当前版本 v$kAppVersion · ${latest.name}',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.04),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.white.withValues(alpha: 0.07)),
              ),
              child: Text(
                latest.body.trim().isEmpty ? '（本次更新没有说明）' : latest.body,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('以后再说'),
        ),
        FilledButton.icon(
          onPressed: () => Navigator.of(context).pop(true),
          icon: const Icon(Icons.download_rounded, size: 18),
          label: Text('立即更新'),
        ),
      ],
    ),
  );
  return confirmed ?? false;
}

Future<void> _showMessage(
  BuildContext context, {
  required IconData icon,
  required String title,
  required String body,
  Color color = _UpdateColors.accent,
}) {
  return showDialog<void>(
    context: context,
    builder: (context) => AlertDialog(
      icon: Icon(icon, color: color, size: 30),
      title: Text(title),
      content: SizedBox(width: 420, child: Text(body)),
      actions: [
        FilledButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('好'),
        ),
      ],
    ),
  );
}

class _DownloadDialog extends StatelessWidget {
  const _DownloadDialog({required this.progress, required this.version});

  final ValueNotifier<double> progress;
  final String version;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('正在下载 v$version'),
      content: SizedBox(
        width: 360,
        child: ValueListenableBuilder<double>(
          valueListenable: progress,
          builder: (context, value, _) {
            if (value < 0) {
              return const Text('下载失败，请稍后重试。');
            }
            final percent = (value * 100).clamp(0, 100).round();
            return Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('安装包下载中… $percent%'),
                const SizedBox(height: 12),
                LinearProgressIndicator(value: value.clamp(0.0, 1.0)),
              ],
            );
          },
        ),
      ),
      actions: const [
        Padding(
          padding: EdgeInsets.only(right: 8),
          child: Text('下载完成后会自动打开安装器', style: TextStyle(fontSize: 11)),
        ),
      ],
    );
  }
}

class _UpdateColors {
  static const accent = Color(0xFF32B9E8);
  static const success = Color(0xFF55D6A8);
  static const danger = Color(0xFFFF6B81);
}
