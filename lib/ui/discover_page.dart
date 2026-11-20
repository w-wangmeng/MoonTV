import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models.dart';
import '../store/app_store.dart';
import '../tv_mode.dart';
import 'app_shell.dart';
import 'detail_page.dart';
import 'poster_card.dart';
import 'theme.dart';

class DiscoverPage extends StatefulWidget {
  const DiscoverPage({
    super.key,
    required this.store,
    required this.onOpenSources,
  });

  final AppStore store;
  final VoidCallback onOpenSources;

  @override
  State<DiscoverPage> createState() => _DiscoverPageState();
}

class _DiscoverPageState extends State<DiscoverPage> {
  SourceSite? _site;
  VodPage? _page;
  String? _error;
  String? _categoryId;
  List<Category> _categories = const [];
  bool _loading = false;
  bool _loadingMore = false;
  int _requestId = 0;

  @override
  void initState() {
    super.initState();
    _site = widget.store.current;
    widget.store.addListener(_onStoreChanged);
    _load();
  }

  @override
  void dispose() {
    widget.store.removeListener(_onStoreChanged);
    super.dispose();
  }

  void _onStoreChanged() {
    final next = widget.store.current;
    if (next?.key == _site?.key) {
      setState(() {});
      return;
    }
    setState(() {
      _site = next;
      _page = null;
      _categories = const [];
      _categoryId = null;
    });
    _load();
  }

  Future<void> _load({bool append = false}) async {
    final site = _site;
    if (site == null) {
      setState(() {
        _page = null;
        _loading = false;
        _error = null;
      });
      return;
    }
    final request = ++_requestId;
    setState(() {
      if (append) {
        _loadingMore = true;
      } else {
        _loading = true;
        _error = null;
      }
    });
    try {
      final nextPage = await widget.store.api.fetchPage(
        site,
        page: append ? (_page?.page ?? 1) + 1 : 1,
        categoryId: _categoryId,
      );
      if (!mounted || request != _requestId) return;
      setState(() {
        if (append && _page != null) {
          final seen = _page!.items.map((item) => item.id).toSet();
          final merged = [
            ..._page!.items,
            ...nextPage.items.where((item) => seen.add(item.id)),
          ];
          _page = VodPage(
            items: merged,
            categories: _page!.categories,
            page: nextPage.page,
            pageCount: nextPage.pageCount,
            total: nextPage.total,
          );
        } else {
          _page = nextPage;
        }
        if (nextPage.categories.isNotEmpty) {
          _categories = nextPage.categories;
        } else if (_categories.isEmpty) {
          _categories = _deriveCategories(nextPage.items);
        }
        _loading = false;
        _loadingMore = false;
      });
    } catch (error) {
      if (!mounted || request != _requestId) return;
      setState(() {
        _error = error.toString();
        _loading = false;
        _loadingMore = false;
      });
    }
  }

  List<Category> _deriveCategories(List<VodItem> items) {
    final seen = <String>{};
    final result = <Category>[];
    for (final item in items) {
      if (item.typeId.isEmpty || item.typeName.isEmpty) continue;
      if (seen.add(item.typeId)) {
        result.add(Category(id: item.typeId, name: item.typeName));
      }
    }
    return result;
  }

  Future<void> _selectCategory(String? id) async {
    if (_categoryId == id) return;
    setState(() {
      _categoryId = id;
      _page = null;
    });
    await _load();
  }

  void _openItem(VodItem item) {
    final site = _site;
    if (site == null) return;
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) =>
            DetailPage(store: widget.store, site: site, initialItem: item),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.sizeOf(context).width >= 900;
    final tv = TvMode.of(context).isTv;
    final horizontal = tv ? 56.0 : (wide ? 36.0 : 20.0);
    return RefreshIndicator(
      color: MoonColors.accent,
      backgroundColor: MoonColors.surface,
      onRefresh: () => _load(),
      child: CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          SliverPadding(
            padding: EdgeInsets.fromLTRB(horizontal, 26, horizontal, 0),
            sliver: SliverToBoxAdapter(child: _buildHeader(context, wide)),
          ),
          if (widget.store.hasPlayableSources)
            SliverPadding(
              padding: EdgeInsets.fromLTRB(horizontal, 24, horizontal, 0),
              sliver: SliverToBoxAdapter(child: _buildCategories()),
            ),
          SliverPadding(
            padding: EdgeInsets.fromLTRB(horizontal, 24, horizontal, 8),
            sliver: SliverToBoxAdapter(child: _buildSectionHeader(context)),
          ),
          ..._buildBody(context),
          const SliverToBoxAdapter(child: SizedBox(height: 46)),
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context, bool wide) {
    final current = _site;
    final tv = TvMode.of(context).isTv;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Eyebrow('SOURCE LIBRARY / 站源库'),
              const SizedBox(height: 9),
              Text(
                '今晚，想看点什么？',
                style: Theme.of(context).textTheme.displayMedium
                    ?.copyWith(fontSize: tv ? 44 : (wide ? 38 : 29)),
              ),
              const SizedBox(height: 7),
              Text(
                current == null
                    ? '连接一个源，开始你的私人放映室。'
                    : '正在浏览 ${current.displayName} · '
                          '${widget.store.enabledSites.length} 个站源可用',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ],
          ),
        ),
        if (wide) ...[
          _ToolbarButton(
            icon: Icons.swap_horiz_rounded,
            label: '换源',
            onTap: current == null
                ? widget.onOpenSources
                : () => showSourcePicker(context, widget.store),
          ),
          const SizedBox(width: 9),
          _ToolbarButton(
            icon: Icons.refresh_rounded,
            label: '刷新',
            onTap: _loading ? null : () => _load(),
          ),
        ],
      ],
    );
  }

  Widget _buildCategories() {
    if (_categories.isEmpty) {
      return const SizedBox(height: 36);
    }
    return SizedBox(
      height: 36,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: _categories.length + 1,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final category = index == 0 ? null : _categories[index - 1];
          final selected = category == null
              ? _categoryId == null
              : _categoryId == category.id;
          return _CategoryChip(
            label: category?.name ?? '最新',
            selected: selected,
            onTap: () => _selectCategory(category?.id),
          );
        },
      ),
    );
  }

  Widget _buildSectionHeader(BuildContext context) {
    final page = _page;
    return SectionHeader(
      title: _categoryId == null ? '最新上线' : '筛选结果',
      subtitle: page == null
          ? '从当前站源拉取内容'
          : '${page.items.length} 部作品${page.total > 0 ? ' · 共 ${page.total} 部' : ''}',
      trailing: page != null && page.items.isNotEmpty
          ? Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                AccentPill(
                  label: _buildPageLabel(page),
                  icon: Icons.layers_outlined,
                ),
                const SizedBox(width: 8),
                IconButton(
                  tooltip: '刷新',
                  onPressed: _loading ? null : () => _load(),
                  icon: const Icon(Icons.refresh_rounded, size: 20),
                ),
              ],
            )
          : null,
    );
  }

  String _buildPageLabel(VodPage page) {
    if (page.pageCount <= 1) return '单页';
    return '第 ${page.page} / ${page.pageCount} 页';
  }

  List<Widget> _buildBody(BuildContext context) {
    if (!widget.store.isConfigured) {
      return [
        SliverFillRemaining(
          hasScrollBody: false,
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: EmptyState(
              icon: Icons.link_rounded,
              title: '还没有连接内容源',
              message: 'MoonTV 不内置片源。添加 MoonTV/LunaTV 或 TVBox 配置后，这里会出现你的内容。',
              action: FilledButton.icon(
                onPressed: widget.onOpenSources,
                icon: const Icon(Icons.add_link_rounded, size: 18),
                label: const Text('添加第一个源'),
              ),
            ),
          ),
        ),
      ];
    }
    if (!widget.store.hasPlayableSources) {
      return [
        SliverFillRemaining(
          hasScrollBody: false,
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: EmptyState(
              icon: Icons.pause_circle_outline_rounded,
              title: '站源已全部禁用',
              message: '到「设置 → 站源管理」启用至少一个站源，或添加新的配置。',
              action: FilledButton.icon(
                onPressed: widget.onOpenSources,
                icon: const Icon(Icons.tune_rounded, size: 18),
                label: const Text('管理站源'),
              ),
            ),
          ),
        ),
      ];
    }
    if (_loading) {
      return [
        SliverPadding(
          padding: EdgeInsets.symmetric(
            horizontal: MediaQuery.sizeOf(context).width >= 900 ? 36 : 20,
          ),
          sliver: SliverGrid(
            gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
              maxCrossAxisExtent: 215,
              mainAxisSpacing: 16,
              crossAxisSpacing: 14,
              childAspectRatio: 0.64,
            ),
            delegate: SliverChildBuilderDelegate(
              (context, _) => const PosterSkeleton(),
              childCount: 12,
            ),
          ),
        ),
      ];
    }
    if (_error != null) {
      return [
        SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
          sliver: SliverToBoxAdapter(
            child: ErrorPanel(message: _error!, onRetry: () => _load()),
          ),
        ),
      ];
    }
    final page = _page;
    if (page == null || page.items.isEmpty) {
      return [
        SliverFillRemaining(
          hasScrollBody: false,
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: EmptyState(
              icon: Icons.movie_filter_outlined,
              title: '这个分类暂时没有内容',
              message: '换一个分类，或刷新当前站源试试。',
              action: OutlinedButton.icon(
                onPressed: () => _selectCategory(null),
                icon: const Icon(Icons.refresh_rounded, size: 18),
                label: const Text('回到最新'),
              ),
            ),
          ),
        ),
      ];
    }

    final horizontal = MediaQuery.sizeOf(context).width >= 900 ? 36.0 : 20.0;
    return [
      SliverPadding(
        padding: EdgeInsets.symmetric(horizontal: horizontal),
        sliver: SliverGrid(
          gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
            maxCrossAxisExtent: 215,
            mainAxisSpacing: 16,
            crossAxisSpacing: 14,
            childAspectRatio: 0.64,
          ),
          delegate: SliverChildBuilderDelegate((context, index) {
            final item = page.items[index];
            return PosterCard(item: item, onTap: () => _openItem(item));
          }, childCount: page.items.length),
        ),
      ),
      if (page.page < page.pageCount)
        SliverPadding(
          padding: EdgeInsets.fromLTRB(horizontal, 26, horizontal, 0),
          sliver: SliverToBoxAdapter(
            child: Center(
              child: OutlinedButton.icon(
                onPressed: _loadingMore ? null : () => _load(append: true),
                icon: _loadingMore
                    ? const SizedBox(
                        width: 15,
                        height: 15,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.expand_more_rounded, size: 19),
                label: Text(_loadingMore ? '加载中…' : '加载更多'),
              ),
            ),
          ),
        ),
    ];
  }
}

class _ToolbarButton extends StatelessWidget {
  const _ToolbarButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
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
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 11),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.04),
              borderRadius: BorderRadius.circular(13),
              border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, size: 16, color: MoonColors.muted),
                const SizedBox(width: 7),
                Text(
                  label,
                  style: const TextStyle(
                    color: MoonColors.muted,
                    fontSize: 11.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _CategoryChip extends StatefulWidget {
  const _CategoryChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  State<_CategoryChip> createState() => _CategoryChipState();
}

class _CategoryChipState extends State<_CategoryChip> {
  bool _focused = false;

  @override
  Widget build(BuildContext context) {
    return FocusableActionDetector(
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
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          canRequestFocus: false,
          onTap: widget.onTap,
          borderRadius: BorderRadius.circular(30),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 140),
            padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 8),
            decoration: BoxDecoration(
              color: widget.selected
                  ? MoonColors.accent.withValues(alpha: 0.16)
                  : Colors.white.withValues(alpha: 0.035),
              borderRadius: BorderRadius.circular(30),
              border: Border.all(
                color: widget.selected || _focused
                    ? MoonColors.accent.withValues(alpha: 0.38)
                    : Colors.white.withValues(alpha: 0.07),
              ),
            ),
            child: Text(
              widget.label,
              style: TextStyle(
                color: widget.selected
                    ? MoonColors.accentStrong
                    : MoonColors.muted,
                fontSize: 11.5,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
