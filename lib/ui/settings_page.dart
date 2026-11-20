import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../media/media_models.dart';
import '../media/media_store.dart';
import '../store/app_store.dart';
import '../tv_mode.dart';
import '../update/update_dialog.dart';
import '../update/update_service.dart';
import 'sources_page.dart';
import 'theme.dart';
import 'tv_focus.dart';

class SettingsPage extends StatelessWidget {
  const SettingsPage({
    super.key,
    required this.store,
    required this.mediaStore,
    required this.tvMode,
    required this.onOpenSources,
    required this.onOpenLibrary,
  });

  final AppStore store;
  final MediaStore mediaStore;
  final TvModeController tvMode;
  final VoidCallback onOpenSources;
  final VoidCallback onOpenLibrary;

  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.sizeOf(context).width >= 900;
    return AnimatedBuilder(
      animation: Listenable.merge([store, mediaStore, tvMode]),
      builder: (context, _) {
        final tv = tvMode.isTv;
        final horizontal = tv ? 56.0 : (wide ? 36.0 : 20.0);
        return SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(horizontal, 26, horizontal, 44),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Eyebrow('SETTINGS / 设置'),
              const SizedBox(height: 9),
              Text(
                '简单一点，刚刚好。',
                style: Theme.of(context).textTheme.displayMedium
                    ?.copyWith(fontSize: tv ? 44 : (wide ? 38 : 29)),
              ),
              const SizedBox(height: 7),
              Text(
                '只保留必要的选项。配置、刷新、清除，都在这里。',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 30),
              _SectionLabel('媒体库'),
              _SettingTile(
                icon: Icons.video_library_outlined,
                title: mediaStore.account == null ? '连接媒体服务器' : '原生媒体库',
                subtitle: mediaStore.account == null
                    ? 'Jellyfin / Emby / Plex，浏览私人影库'
                    : '${mediaStore.account!.serverName} · ${mediaStore.account!.type.label}',
                trailing: mediaStore.hasServer ? '已连接' : '未连接',
                onTap: onOpenLibrary,
              ),
              const SizedBox(height: 26),
              _SectionLabel('内容源'),
              _SettingTile(
                icon: Icons.dns_outlined,
                title: '站源管理',
                subtitle: store.sites.isEmpty
                    ? '还没有连接站源'
                    : '${store.configs.length} 个配置 · '
                          '${store.enabledSites.length}/${store.sites.length} 个启用',
                trailing: '${store.enabledSites.length}',
                onTap: onOpenSources,
              ),
              const SizedBox(height: 9),
              _SettingTile(
                icon: Icons.refresh_rounded,
                title: '刷新全部配置',
                subtitle: store.refreshing ? '正在重新读取配置…' : '重新拉取最新的站源列表',
                trailing: store.refreshing ? '···' : '',
                onTap: store.refreshing ? null : () => store.refreshAll(),
              ),
              const SizedBox(height: 9),
              _SettingTile(
                icon: Icons.add_link_rounded,
                title: '添加另一个配置',
                subtitle: '可以同时聚合多份 MoonTV / LunaTV / TVBox 配置',
                onTap: () => showAddConfigDialog(context, store),
              ),
              const SizedBox(height: 26),
              _SectionLabel('电视与遥控器'),
              _SettingTile(
                icon: Icons.tv_rounded,
                title: '电视模式',
                subtitle:
                    '${tvMode.preference.label} · '
                    '${tvMode.isTv ? '遥控器优化已启用' : '当前为触控布局'}',
                trailing: tvMode.isTv ? '电视' : '平板',
                onTap: () => _chooseTvMode(context),
              ),
              const SizedBox(height: 26),
              _SectionLabel('播放'),
              const _StaticTile(
                icon: Icons.play_circle_outline_rounded,
                title: '播放器',
                subtitle: '内置 libmpv / HLS 播放器，适配平板与电视',
                trailing: '内置',
              ),
              const SizedBox(height: 9),
              const _StaticTile(
                icon: Icons.hd_outlined,
                title: '画质',
                subtitle: '跟随片源提供的最佳清晰度',
                trailing: '自动',
              ),
              const SizedBox(height: 26),
              _SectionLabel('数据'),
              _SettingTile(
                icon: Icons.delete_sweep_outlined,
                title: '清除全部配置',
                subtitle: '移除本机保存的配置与站源缓存',
                danger: true,
                onTap: () => _confirmClear(context),
              ),
              const SizedBox(height: 26),
              _SectionLabel('关于'),
              const _StaticTile(
                icon: Icons.nightlight_outlined,
                title: 'MoonTV',
                subtitle: '基于 Moonfin-Core 的界面与交互重构 · GPL-3.0',
                trailing: 'v$kAppVersion',
              ),
              const SizedBox(height: 9),
              _SettingTile(
                icon: Icons.system_update_alt_rounded,
                title: '检查更新',
                subtitle: '从 GitHub 检查并下载新版本，完成后自动打开安装器',
                trailing: 'v$kAppVersion',
                onTap: () => checkForUpdates(context),
              ),
              const SizedBox(height: 9),
              _SettingTile(
                icon: Icons.article_outlined,
                title: '开源许可',
                subtitle: '查看 MoonTV 与依赖组件的许可证文本',
                onTap: () => showLicensePage(
                  context: context,
                  applicationName: 'MoonTV',
                  applicationVersion: kAppVersion,
                ),
              ),
              const SizedBox(height: 9),
              const GlassCard(
                padding: EdgeInsets.all(16),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.info_outline_rounded,
                      size: 17,
                      color: MoonColors.faint,
                    ),
                    SizedBox(width: 9),
                    Expanded(
                      child: Text(
                        'MoonTV 不提供、不托管任何影片或直播源。所有内容来自用户自行配置的第三方接口，'
                        '请遵守当地法律法规，支持正版。',
                        style: TextStyle(
                          color: MoonColors.faint,
                          fontSize: 10.5,
                          height: 1.55,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              Center(
                child: Text(
                  'Made for a quiet night.',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    fontSize: 9.5,
                    letterSpacing: 1.4,
                    color: MoonColors.faint.withValues(alpha: 0.7),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _chooseTvMode(BuildContext context) async {
    final selected = await showDialog<TvPreference>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('电视模式'),
        content: SizedBox(
          width: 470,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '电视模式会放大焦点框、加大间距，并启用遥控器播放快捷键。',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 7),
              Text(
                tvMode.detectedLabel,
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: 14),
              for (final option in TvPreference.values) ...[
                _TvChoice(
                  option: option,
                  selected: tvMode.preference == option,
                  onTap: () => Navigator.of(context).pop(option),
                ),
                if (option != TvPreference.values.last)
                  const SizedBox(height: 7),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('取消'),
          ),
        ],
      ),
    );
    if (selected != null) await tvMode.setPreference(selected);
  }

  Future<void> _confirmClear(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('清除全部配置？'),
        content: const Text('这会删除本机保存的配置地址与站源缓存，下次打开需要重新添加。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('取消'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: MoonColors.danger,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('清除'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await store.clearAll();
    }
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 9),
      child: Text(
        text,
        style: Theme.of(context).textTheme.labelMedium?.copyWith(
          color: MoonColors.faint,
          letterSpacing: 1.3,
          fontSize: 9.5,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _SettingTile extends StatefulWidget {
  const _SettingTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.trailing,
    this.onTap,
    this.danger = false,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final String? trailing;
  final VoidCallback? onTap;
  final bool danger;

  @override
  State<_SettingTile> createState() => _SettingTileState();
}

class _SettingTileState extends State<_SettingTile> {
  bool _focused = false;

  @override
  Widget build(BuildContext context) {
    final color = widget.danger ? MoonColors.danger : MoonColors.accent;
    return FocusableActionDetector(
      onFocusChange: (value) {
        setState(() => _focused = value);
        if (value) ensureTvFocusVisible(context);
      },
      shortcuts: const {
        SingleActivator(LogicalKeyboardKey.select): ActivateIntent(),
        SingleActivator(LogicalKeyboardKey.enter): ActivateIntent(),
      },
      actions: {
        ActivateIntent: CallbackAction<ActivateIntent>(
          onInvoke: (_) {
            widget.onTap?.call();
            return null;
          },
        ),
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        decoration: BoxDecoration(
          color: _focused
              ? Colors.white.withValues(alpha: 0.06)
              : Colors.white.withValues(alpha: 0.025),
          borderRadius: BorderRadius.circular(15),
          border: Border.all(
            color: _focused
                ? color.withValues(alpha: 0.45)
                : Colors.white.withValues(alpha: 0.06),
          ),
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            canRequestFocus: false,
            onTap: widget.onTap,
            borderRadius: BorderRadius.circular(15),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 13),
              child: Row(
                children: [
                  Container(
                    width: 35,
                    height: 35,
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.09),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: color.withValues(alpha: 0.16)),
                    ),
                    child: Icon(widget.icon, size: 17, color: color),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.title,
                          style: TextStyle(
                            color: widget.danger
                                ? MoonColors.danger
                                : MoonColors.text,
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          widget.subtitle,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(fontSize: 10.5),
                        ),
                      ],
                    ),
                  ),
                  if (widget.trailing != null &&
                      widget.trailing!.isNotEmpty) ...[
                    const SizedBox(width: 8),
                    Text(
                      widget.trailing!,
                      style: const TextStyle(
                        color: MoonColors.faint,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                  const SizedBox(width: 4),
                  const Icon(
                    Icons.chevron_right_rounded,
                    size: 18,
                    color: MoonColors.faint,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _TvChoice extends StatefulWidget {
  const _TvChoice({
    required this.option,
    required this.selected,
    required this.onTap,
  });

  final TvPreference option;
  final bool selected;
  final VoidCallback onTap;

  @override
  State<_TvChoice> createState() => _TvChoiceState();
}

class _TvChoiceState extends State<_TvChoice> {
  bool _focused = false;

  @override
  Widget build(BuildContext context) {
    return FocusableActionDetector(
      autofocus: widget.selected,
      onFocusChange: (value) => setState(() => _focused = value),
      shortcuts: const {
        SingleActivator(LogicalKeyboardKey.select): ActivateIntent(),
        SingleActivator(LogicalKeyboardKey.enter): ActivateIntent(),
      },
      actions: {
        ActivateIntent: CallbackAction<ActivateIntent>(
          onInvoke: (_) {
            widget.onTap();
            return null;
          },
        ),
      },
      child: InkWell(
        canRequestFocus: false,
        onTap: widget.onTap,
        borderRadius: BorderRadius.circular(12),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 11),
          decoration: BoxDecoration(
            color: widget.selected
                ? MoonColors.accent.withValues(alpha: 0.13)
                : Colors.white.withValues(alpha: 0.03),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: _focused
                  ? MoonColors.accentStrong
                  : widget.selected
                  ? MoonColors.accent.withValues(alpha: 0.4)
                  : Colors.white.withValues(alpha: 0.07),
              width: _focused ? 2 : 1,
            ),
          ),
          child: Row(
            children: [
              Icon(
                widget.selected
                    ? Icons.radio_button_checked_rounded
                    : Icons.radio_button_off_rounded,
                size: 18,
                color: widget.selected
                    ? MoonColors.accentStrong
                    : MoonColors.faint,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.option.label,
                      style: TextStyle(
                        color: widget.selected
                            ? MoonColors.accentStrong
                            : MoonColors.text,
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      widget.option.description,
                      style: Theme.of(context).textTheme.bodySmall
                          ?.copyWith(fontSize: 10.5),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StaticTile extends StatelessWidget {
  const _StaticTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.trailing,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final String? trailing;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 13),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.02),
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: Colors.white.withValues(alpha: 0.055)),
      ),
      child: Row(
        children: [
          Container(
            width: 35,
            height: 35,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.035),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.white.withValues(alpha: 0.07)),
            ),
            child: Icon(icon, size: 17, color: MoonColors.muted),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: MoonColors.text,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodySmall
                      ?.copyWith(fontSize: 10.5),
                ),
              ],
            ),
          ),
          if (trailing != null)
            Text(
              trailing!,
              style: const TextStyle(
                color: MoonColors.faint,
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
        ],
      ),
    );
  }
}
