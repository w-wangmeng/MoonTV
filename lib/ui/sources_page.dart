import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models.dart';
import '../store/app_store.dart';
import '../tv_mode.dart';
import 'theme.dart';
import 'tv_focus.dart';

class SourcesPage extends StatefulWidget {
  const SourcesPage({super.key, required this.store});

  final AppStore store;

  @override
  State<SourcesPage> createState() => _SourcesPageState();
}

class _SourcesPageState extends State<SourcesPage> {
  final _search = TextEditingController();

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.sizeOf(context).width >= 900;
    final tv = TvMode.of(context).isTv;
    final horizontal = tv ? 56.0 : (wide ? 36.0 : 20.0);
    return AnimatedBuilder(
      animation: widget.store,
      builder: (context, _) {
        final query = _search.text.trim().toLowerCase();
        final sites = widget.store.sites.where((site) {
          if (query.isEmpty) return true;
          return site.displayName.toLowerCase().contains(query) ||
              site.host.toLowerCase().contains(query);
        }).toList();
        final enabledCount = widget.store.enabledSites.length;
        final disabledCount = widget.store.disabledSiteCount;
        return CustomScrollView(
          slivers: [
            SliverPadding(
              padding: EdgeInsets.fromLTRB(horizontal, 26, horizontal, 0),
              sliver: SliverToBoxAdapter(child: _buildHeader(context, wide)),
            ),
            SliverPadding(
              padding: EdgeInsets.fromLTRB(horizontal, 22, horizontal, 0),
              sliver: SliverToBoxAdapter(child: _buildConfigSection(context)),
            ),
            SliverPadding(
              padding: EdgeInsets.fromLTRB(horizontal, 26, horizontal, 0),
              sliver: SliverToBoxAdapter(
                child: SectionHeader(
                  title: '点播站源',
                  subtitle: widget.store.sites.isEmpty
                      ? '添加配置后，这里会列出可用的站源'
                      : disabledCount > 0
                      ? '$enabledCount 个启用 · $disabledCount 个已禁用 · 点击切换当前源'
                      : '$enabledCount 个站源可用 · 点击切换当前源',
                  trailing: widget.store.sites.isEmpty
                      ? null
                      : SizedBox(
                          width: 220,
                          child: TextField(
                            controller: _search,
                            onChanged: (_) => setState(() {}),
                            style: const TextStyle(fontSize: 12),
                            decoration: const InputDecoration(
                              hintText: '筛选站源',
                              prefixIcon: Icon(Icons.search_rounded, size: 17),
                              contentPadding: EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 10,
                              ),
                            ),
                          ),
                        ),
                ),
              ),
            ),
            if (widget.store.sites.isEmpty)
              SliverFillRemaining(
                hasScrollBody: false,
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: EmptyState(
                    icon: Icons.dns_outlined,
                    title: '还没有站源',
                    message: '添加 MoonTV/LunaTV 或 TVBox 配置，MoonTV 会自动提取其中的点播接口。',
                    action: FilledButton.icon(
                      onPressed: () =>
                          showAddConfigDialog(context, widget.store),
                      icon: const Icon(Icons.add_rounded, size: 18),
                      label: const Text('添加配置'),
                    ),
                  ),
                ),
              )
            else
              SliverPadding(
                padding: EdgeInsets.fromLTRB(horizontal, 14, horizontal, 0),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) => Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: _SiteRow(
                        site: sites[index],
                        index: widget.store.sites.indexWhere(
                          (entry) => entry.key == sites[index].key,
                        ),
                        enabled: widget.store.isSiteEnabled(sites[index]),
                        selected:
                            widget.store.isSiteEnabled(sites[index]) &&
                            widget.store.current?.key == sites[index].key,
                        onTap: widget.store.isSiteEnabled(sites[index])
                            ? () => widget.store.selectSite(sites[index])
                            : null,
                        onToggle: () => widget.store.setSiteEnabled(
                          sites[index],
                          !widget.store.isSiteEnabled(sites[index]),
                        ),
                        onDelete: () =>
                            _confirmDeleteSite(context, sites[index]),
                      ),
                    ),
                    childCount: sites.length,
                  ),
                ),
              ),
            const SliverToBoxAdapter(child: SizedBox(height: 42)),
          ],
        );
      },
    );
  }

  Widget _buildHeader(BuildContext context, bool wide) {
    final tv = TvMode.of(context).isTv;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Eyebrow('SOURCES / 站源'),
              const SizedBox(height: 9),
              Text(
                '你的片源，你的规则。',
                style: Theme.of(context).textTheme.displayMedium
                    ?.copyWith(fontSize: tv ? 44 : (wide ? 38 : 29)),
              ),
              const SizedBox(height: 7),
              Text(
                'MoonTV / LunaTV 的 api_site，TVBox 的 sites，Base58 订阅都能直接添加。',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ],
          ),
        ),
        if (wide) ...[
          _HeaderButton(
            icon: Icons.refresh_rounded,
            label: widget.store.refreshing ? '刷新中' : '刷新全部',
            onTap: widget.store.refreshing
                ? null
                : () => widget.store.refreshAll(),
          ),
          const SizedBox(width: 9),
          _HeaderButton(
            icon: Icons.add_rounded,
            label: '添加配置',
            filled: true,
            onTap: () => showAddConfigDialog(context, widget.store),
          ),
        ],
      ],
    );
  }

  Widget _buildConfigSection(BuildContext context) {
    final configs = widget.store.configs;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text('配置', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(width: 9),
            AccentPill(label: '${configs.length} 个'),
            const Spacer(),
          ],
        ),
        const SizedBox(height: 11),
        if (configs.isEmpty)
          GlassCard(
            padding: const EdgeInsets.all(18),
            child: Row(
              children: [
                const Icon(
                  Icons.info_outline_rounded,
                  color: MoonColors.faint,
                  size: 19,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    '还没有配置文件。支持 MoonTV/LunaTV 的 api_site、TVBox 的 sites、以及 Base58 订阅。',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
                TextButton(
                  onPressed: () => showAddConfigDialog(context, widget.store),
                  child: const Text('添加'),
                ),
              ],
            ),
          )
        else
          for (final config in configs)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: _ConfigRow(
                config: config,
                siteCount: widget.store.sites
                    .where((site) => site.origin == config.url)
                    .length,
                onDelete: () => _confirmDelete(context, config),
                onRefresh: () => widget.store.refreshAll(),
              ),
            ),
        if (widget.store.lastError != null) ...[
          const SizedBox(height: 6),
          ErrorPanel(
            message: widget.store.lastError!,
            onRetry: () => widget.store.refreshAll(),
          ),
        ],
        if (widget.store.lastWarnings.isNotEmpty) ...[
          const SizedBox(height: 6),
          _WarningPanel(warnings: widget.store.lastWarnings),
        ],
        if (MediaQuery.sizeOf(context).width < 900) ...[
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: widget.store.refreshing
                      ? null
                      : () => widget.store.refreshAll(),
                  icon: const Icon(Icons.refresh_rounded, size: 18),
                  label: Text(widget.store.refreshing ? '刷新中…' : '刷新全部'),
                ),
              ),
              const SizedBox(width: 9),
              Expanded(
                child: FilledButton.icon(
                  onPressed: () => showAddConfigDialog(context, widget.store),
                  icon: const Icon(Icons.add_rounded, size: 18),
                  label: const Text('添加配置'),
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }

  Future<void> _confirmDelete(BuildContext context, SavedConfig config) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('删除配置？'),
        content: Text('将移除「${config.label}」以及它带来的站源。已保存的收藏与历史不会受影响。'),
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
            child: const Text('删除'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await widget.store.removeConfig(config.id);
    }
  }

  Future<void> _confirmDeleteSite(BuildContext context, SourceSite site) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('删除站源？'),
        content: Text(
          '将从本地移除「${site.displayName}」。删除后刷新配置不会恢复；'
          '如需找回，请删除对应配置后重新添加。',
        ),
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
            child: const Text('删除'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await widget.store.removeSite(site);
    }
  }
}

class _ConfigRow extends StatelessWidget {
  const _ConfigRow({
    required this.config,
    required this.siteCount,
    required this.onDelete,
    required this.onRefresh,
  });

  final SavedConfig config;
  final int siteCount;
  final VoidCallback onDelete;
  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
      radius: 16,
      child: Row(
        children: [
          Container(
            width: 37,
            height: 37,
            decoration: BoxDecoration(
              color: MoonColors.violet.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(11),
              border: Border.all(
                color: MoonColors.violet.withValues(alpha: 0.2),
              ),
            ),
            child: const Icon(
              Icons.description_outlined,
              size: 18,
              color: MoonColors.violet,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        config.label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(fontSize: 13),
                      ),
                    ),
                    const SizedBox(width: 8),
                    AccentPill(label: config.format, color: MoonColors.violet),
                  ],
                ),
                const SizedBox(height: 3),
                Text(
                  config.url,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          AccentPill(label: '$siteCount 源', icon: Icons.layers_outlined),
          const SizedBox(width: 4),
          IconButton(
            tooltip: '刷新',
            onPressed: onRefresh,
            icon: const Icon(Icons.refresh_rounded, size: 18),
          ),
          IconButton(
            tooltip: '删除',
            onPressed: onDelete,
            icon: const Icon(Icons.delete_outline_rounded, size: 18),
          ),
        ],
      ),
    );
  }
}

class _WarningPanel extends StatelessWidget {
  const _WarningPanel({required this.warnings});

  final List<String> warnings;

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      padding: const EdgeInsets.all(14),
      borderColor: MoonColors.gold.withValues(alpha: 0.16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.warning_amber_rounded,
            size: 17,
            color: MoonColors.gold,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              warnings.join('  '),
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: MoonColors.gold.withValues(alpha: 0.9),
                fontSize: 10.5,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SiteRow extends StatefulWidget {
  const _SiteRow({
    required this.site,
    required this.index,
    required this.enabled,
    required this.selected,
    required this.onTap,
    required this.onToggle,
    required this.onDelete,
  });

  final SourceSite site;
  final int index;
  final bool enabled;
  final bool selected;
  final VoidCallback? onTap;
  final VoidCallback onToggle;
  final VoidCallback onDelete;

  @override
  State<_SiteRow> createState() => _SiteRowState();
}

class _SiteRowState extends State<_SiteRow> {
  bool _focused = false;

  @override
  Widget build(BuildContext context) {
    final enabled = widget.enabled;
    final compact = MediaQuery.sizeOf(context).width < 760;
    final toggleButton = Tooltip(
      message: enabled ? '禁用站源' : '启用站源',
      child: compact
          ? IconButton(
              tooltip: enabled ? '禁用站源' : '启用站源',
              onPressed: widget.onToggle,
              color: enabled ? MoonColors.muted : MoonColors.success,
              visualDensity: VisualDensity.compact,
              icon: Icon(
                enabled
                    ? Icons.pause_circle_outline_rounded
                    : Icons.play_circle_outline_rounded,
                size: 19,
              ),
            )
          : TextButton.icon(
              onPressed: widget.onToggle,
              style: TextButton.styleFrom(
                foregroundColor: enabled
                    ? MoonColors.muted
                    : MoonColors.success,
                minimumSize: const Size(0, 34),
                padding: const EdgeInsets.symmetric(horizontal: 8),
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              icon: Icon(
                enabled ? Icons.pause_rounded : Icons.play_arrow_rounded,
                size: 15,
              ),
              label: Text(
                enabled ? '禁用' : '启用',
                style: const TextStyle(
                  fontSize: 10.5,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
    );
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
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          canRequestFocus: false,
          onTap: widget.onTap,
          borderRadius: BorderRadius.circular(14),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 140),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
            decoration: BoxDecoration(
              color: widget.selected
                  ? MoonColors.accent.withValues(alpha: 0.075)
                  : _focused
                  ? Colors.white.withValues(alpha: 0.05)
                  : Colors.white.withValues(alpha: enabled ? 0.025 : 0.012),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: widget.selected
                    ? MoonColors.accent.withValues(alpha: 0.25)
                    : _focused
                    ? MoonColors.accent.withValues(alpha: 0.3)
                    : Colors.white.withValues(alpha: 0.06),
              ),
            ),
            child: Row(
              children: [
                SizedBox(
                  width: 24,
                  child: Text(
                    '${widget.index + 1}'.padLeft(2, '0'),
                    style: const TextStyle(
                      color: MoonColors.faint,
                      fontSize: 9.5,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                Opacity(
                  opacity: enabled ? 1 : 0.5,
                  child: SourceGlyph(name: widget.site.displayName, size: 32),
                ),
                const SizedBox(width: 11),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.site.displayName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: widget.selected
                              ? MoonColors.accentStrong
                              : enabled
                              ? MoonColors.text
                              : MoonColors.faint,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        widget.site.host,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: MoonColors.faint,
                          fontSize: 10,
                        ),
                      ),
                    ],
                  ),
                ),
                if (!enabled) ...[
                  const SizedBox(width: 7),
                  const AccentPill(label: '已禁用', color: MoonColors.gold),
                ],
                const SizedBox(width: 7),
                if (widget.site.type == 0)
                  AccentPill(
                    label: 'XML',
                    color: enabled ? MoonColors.gold : MoonColors.faint,
                  )
                else
                  AccentPill(
                    label: 'JSON',
                    color: enabled ? MoonColors.accent : MoonColors.faint,
                  ),
                if (widget.selected) ...[
                  const SizedBox(width: 8),
                  const Icon(
                    Icons.check_circle_rounded,
                    color: MoonColors.accent,
                    size: 18,
                  ),
                ],
                const SizedBox(width: 6),
                toggleButton,
                const SizedBox(width: 2),
                IconButton(
                  tooltip: '删除站源',
                  onPressed: widget.onDelete,
                  color: MoonColors.danger,
                  visualDensity: VisualDensity.compact,
                  icon: const Icon(Icons.delete_outline_rounded, size: 18),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _HeaderButton extends StatelessWidget {
  const _HeaderButton({
    required this.icon,
    required this.label,
    required this.onTap,
    this.filled = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onTap;
  final bool filled;

  @override
  Widget build(BuildContext context) {
    final child = Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
      decoration: BoxDecoration(
        color: filled
            ? MoonColors.accent
            : Colors.white.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(13),
        border: Border.all(
          color: filled
              ? Colors.transparent
              : Colors.white.withValues(alpha: 0.08),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 16,
            color: filled ? const Color(0xFF03141D) : MoonColors.muted,
          ),
          const SizedBox(width: 7),
          Text(
            label,
            style: TextStyle(
              color: filled ? const Color(0xFF03141D) : MoonColors.muted,
              fontSize: 11.5,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
    return FocusableActionDetector(
      shortcuts: const {
        SingleActivator(LogicalKeyboardKey.select): ActivateIntent(),
        SingleActivator(LogicalKeyboardKey.enter): ActivateIntent(),
      },
      actions: {
        ActivateIntent: CallbackAction<ActivateIntent>(
          onInvoke: (_) {
            onTap?.call();
            return null;
          },
        ),
      },
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          canRequestFocus: false,
          onTap: onTap,
          borderRadius: BorderRadius.circular(13),
          child: child,
        ),
      ),
    );
  }
}

Future<void> showAddConfigDialog(BuildContext context, AppStore store) async {
  final controller = TextEditingController();
  final labelController = TextEditingController();
  var busy = false;
  String? error;

  await showDialog<void>(
    context: context,
    barrierDismissible: !busy,
    builder: (context) {
      return StatefulBuilder(
        builder: (context, setState) {
          Future<void> submit() async {
            final url = controller.text.trim();
            if (url.isEmpty) {
              setState(() => error = '请输入配置地址');
              return;
            }
            setState(() {
              busy = true;
              error = null;
            });
            try {
              final result = await store.addConfig(
                url,
                label: labelController.text,
              );
              if (!context.mounted) return;
              Navigator.of(context).pop();
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('已添加 ${result.sites.length} 个站源')),
              );
            } catch (e) {
              if (!context.mounted) return;
              setState(() {
                error = e.toString();
                busy = false;
              });
            }
          }

          return AlertDialog(
            title: const Text('添加配置'),
            content: SizedBox(
              width: 520,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '粘贴 MoonTV/LunaTV 或 TVBox 的配置地址，也支持 Base58 订阅。',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: controller,
                      autofocus: true,
                      enabled: !busy,
                      keyboardType: TextInputType.url,
                      textInputAction: TextInputAction.next,
                      decoration: const InputDecoration(
                        labelText: '配置地址',
                        hintText: 'https://example.com/config.json',
                        prefixIcon: Icon(Icons.link_rounded, size: 19),
                      ),
                    ),
                    const SizedBox(height: 11),
                    TextField(
                      controller: labelController,
                      enabled: !busy,
                      textInputAction: TextInputAction.done,
                      onSubmitted: (_) => submit(),
                      decoration: const InputDecoration(
                        labelText: '备注（可选）',
                        hintText: '例如：主配置 / 备用',
                        prefixIcon: Icon(Icons.label_outline_rounded, size: 19),
                      ),
                    ),
                    if (error != null) ...[
                      const SizedBox(height: 12),
                      Text(
                        error!,
                        style: const TextStyle(
                          color: MoonColors.danger,
                          fontSize: 11.5,
                          height: 1.45,
                        ),
                      ),
                    ],
                    const SizedBox(height: 14),
                    Text(
                      'TVBox 中需要 JAR/JS 爬虫的站源会被跳过；MoonTV 只接入 JSON/XML 点播接口。',
                      style: Theme.of(context).textTheme.bodySmall
                          ?.copyWith(fontSize: 10.5),
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: busy ? null : () => Navigator.of(context).pop(),
                child: const Text('取消'),
              ),
              FilledButton(
                onPressed: busy ? null : submit,
                child: busy
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Color(0xFF03141D),
                        ),
                      )
                    : const Text('添加'),
              ),
            ],
          );
        },
      );
    },
  );
  controller.dispose();
  labelController.dispose();
}
