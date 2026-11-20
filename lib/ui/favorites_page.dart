import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../media/media_models.dart';
import '../media/media_store.dart';
import '../tv_mode.dart';
import 'library_detail_page.dart';
import 'theme.dart';
import 'tv_focus.dart';

class FavoritesPage extends StatefulWidget {
  const FavoritesPage({
    super.key,
    required this.store,
    required this.onOpenLibrary,
  });

  final MediaStore store;
  final VoidCallback onOpenLibrary;

  @override
  State<FavoritesPage> createState() => _FavoritesPageState();
}

class _FavoritesPageState extends State<FavoritesPage> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _load();
    });
  }

  Future<void> _load() async {
    if (widget.store.account != null) {
      await widget.store.loadFavorites();
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: widget.store,
      builder: (context, _) {
        final account = widget.store.account;
        final tv = TvMode.of(context).isTv;
        final pad = tv
            ? 56.0
            : (MediaQuery.sizeOf(context).width >= 900 ? 36.0 : 20.0);
        return CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            SliverPadding(
              padding: EdgeInsets.fromLTRB(pad, 28, pad, 18),
              sliver: SliverToBoxAdapter(
                child: _Header(
                  account: account,
                  count: widget.store.favorites.length,
                  loading: widget.store.favoritesLoading,
                  onRefresh: account == null ? null : _load,
                ),
              ),
            ),
            ..._body(pad, account),
            const SliverToBoxAdapter(child: SizedBox(height: 46)),
          ],
        );
      },
    );
  }

  List<Widget> _body(double pad, MediaAccount? account) {
    final tv = TvMode.of(context).isTv;
    if (account == null) {
      return [
        SliverFillRemaining(
          hasScrollBody: false,
          child: EmptyState(
            icon: Icons.favorite_border_rounded,
            title: '还没有连接媒体库',
            message: '连接 Jellyfin、Emby 或 Plex 后，这里会显示服务端的收藏影片。',
            action: FilledButton.icon(
              onPressed: widget.onOpenLibrary,
              icon: const Icon(Icons.video_library_outlined, size: 18),
              label: const Text('去媒体库'),
            ),
          ),
        ),
      ];
    }

    final store = widget.store;
    if (store.favoritesLoading && store.favorites.isEmpty) {
      return const [
        SliverFillRemaining(
          hasScrollBody: false,
          child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
        ),
      ];
    }

    if (store.favoritesError != null && store.favorites.isEmpty) {
      return [
        SliverPadding(
          padding: EdgeInsets.fromLTRB(pad, 0, pad, 0),
          sliver: SliverToBoxAdapter(
            child: ErrorPanel(
              message: '读取收藏失败：${store.favoritesError}',
              onRetry: _load,
            ),
          ),
        ),
      ];
    }

    if (store.favorites.isEmpty) {
      return [
        SliverFillRemaining(
          hasScrollBody: false,
          child: EmptyState(
            icon: Icons.favorite_border_rounded,
            title: '还没有收藏',
            message: '在继续观看中长按影片即可收藏，收藏会同步到你的媒体服务器。',
            action: OutlinedButton.icon(
              onPressed: _load,
              icon: const Icon(Icons.refresh_rounded, size: 18),
              label: const Text('刷新'),
            ),
          ),
        ),
      ];
    }

    return [
      SliverPadding(
        padding: EdgeInsets.fromLTRB(pad, 0, pad, 10),
        sliver: SliverGrid(
          gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
            maxCrossAxisExtent: tv ? 245 : 215,
            mainAxisSpacing: 16,
            crossAxisSpacing: 14,
            childAspectRatio: 0.64,
          ),
          delegate: SliverChildBuilderDelegate((context, index) {
            final item = store.favorites[index];
            return _FavoriteCard(
              item: item,
              account: account,
              onTap: () => _openItem(item),
              onUnfavorite: () => _unfavorite(item),
            );
          }, childCount: store.favorites.length),
        ),
      ),
    ];
  }

  Future<void> _unfavorite(MediaItem item) async {
    try {
      await widget.store.toggleFavorite(item);
      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(const SnackBar(content: Text('已取消收藏')));
      await _load();
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text('取消收藏失败：$error')));
    }
  }

  void _openItem(MediaItem item) {
    final account = widget.store.account;
    if (account == null) return;
    Navigator.of(context)
        .push(
          MaterialPageRoute(
            builder: (_) => LibraryDetailPage(
              store: widget.store,
              account: account,
              initialItem: item,
            ),
          ),
        )
        .then((_) {
          if (mounted) _load();
        });
  }
}

class _Header extends StatelessWidget {
  const _Header({
    required this.account,
    required this.count,
    required this.loading,
    required this.onRefresh,
  });

  final MediaAccount? account;
  final int count;
  final bool loading;
  final VoidCallback? onRefresh;

  @override
  Widget build(BuildContext context) {
    final titleSize = TvMode.of(context).isTv
        ? 44.0
        : (MediaQuery.sizeOf(context).width >= 900 ? 38.0 : 29.0);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Eyebrow('MEDIA / 收藏'),
              const SizedBox(height: 9),
              Text(
                '我的收藏。',
                style: Theme.of(context).textTheme.displayMedium
                    ?.copyWith(fontSize: titleSize),
              ),
              const SizedBox(height: 7),
              Text(
                account == null
                    ? '连接媒体库后在这里查看收藏'
                    : '${account!.serverName} · $count 部收藏',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ],
          ),
        ),
        OutlinedButton.icon(
          onPressed: loading ? null : onRefresh,
          icon: loading
              ? const SizedBox(
                  width: 15,
                  height: 15,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.refresh_rounded, size: 17),
          label: const Text('刷新'),
        ),
      ],
    );
  }
}

class _FavoriteCard extends StatefulWidget {
  const _FavoriteCard({
    required this.item,
    required this.account,
    required this.onTap,
    required this.onUnfavorite,
  });

  final MediaItem item;
  final MediaAccount account;
  final VoidCallback onTap;
  final VoidCallback onUnfavorite;

  @override
  State<_FavoriteCard> createState() => _FavoriteCardState();
}

class _FavoriteCardState extends State<_FavoriteCard> {
  bool _focused = false;

  @override
  Widget build(BuildContext context) {
    final item = widget.item;
    final url = item.imageUrl(widget.account, maxHeight: 560);
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
            widget.onTap();
            return null;
          },
        ),
      },
      child: AnimatedScale(
        scale: _focused ? 1.025 : 1,
        duration: const Duration(milliseconds: 150),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: _focused
                  ? MoonColors.accent
                  : Colors.white.withValues(alpha: 0.07),
              width: _focused ? 2 : 1,
            ),
          ),
          child: LayoutBuilder(
            builder: (context, constraints) => GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTapUp: (details) {
                final local = details.localPosition;
                final onHeart =
                    local.dx >= constraints.maxWidth - 46 && local.dy <= 46;
                if (onHeart) {
                  widget.onUnfavorite();
                } else {
                  widget.onTap();
                }
              },
              child: Stack(
                children: [
                  Positioned.fill(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(17),
                      child: Material(
                        color: MoonColors.surface,
                        child: Stack(
                          fit: StackFit.expand,
                          children: [
                            if (url.isEmpty)
                              const _PosterFallback()
                            else
                              CachedNetworkImage(
                                imageUrl: url,
                                fit: BoxFit.cover,
                                fadeInDuration: const Duration(
                                  milliseconds: 180,
                                ),
                                placeholder: (_, _) =>
                                    Container(color: MoonColors.surface2),
                                errorWidget: (_, _, _) =>
                                    const _PosterFallback(),
                              ),
                            const DecoratedBox(
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  begin: Alignment.topCenter,
                                  end: Alignment.bottomCenter,
                                  stops: [0.45, 0.72, 1],
                                  colors: [
                                    Colors.transparent,
                                    Color(0xB3070B14),
                                    Color(0xF2070B14),
                                  ],
                                ),
                              ),
                            ),
                            Positioned(
                              left: 11,
                              right: 11,
                              bottom: 11,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    item.name,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 13,
                                      height: 1.25,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  if (item.subtitle.isNotEmpty) ...[
                                    const SizedBox(height: 4),
                                    Text(
                                      item.subtitle,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        color: Colors.white.withValues(
                                          alpha: 0.62,
                                        ),
                                        fontSize: 10,
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    top: 7,
                    right: 7,
                    child: Material(
                      color: Colors.black.withValues(alpha: 0.45),
                      shape: const CircleBorder(),
                      clipBehavior: Clip.antiAlias,
                      child: const Tooltip(
                        message: '取消收藏',
                        child: SizedBox(
                          width: 28,
                          height: 28,
                          child: Icon(
                            Icons.favorite_rounded,
                            size: 15,
                            color: MoonColors.danger,
                          ),
                        ),
                      ),
                    ),
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

class _PosterFallback extends StatelessWidget {
  const _PosterFallback();

  @override
  Widget build(BuildContext context) {
    return Container(
      color: MoonColors.surface2,
      child: const Center(
        child: Icon(
          Icons.movie_filter_rounded,
          size: 30,
          color: MoonColors.faint,
        ),
      ),
    );
  }
}
