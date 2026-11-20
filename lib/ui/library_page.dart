import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../media/media_models.dart';
import '../media/media_store.dart';
import '../models.dart';
import '../tv_mode.dart';
import 'library_detail_page.dart';
import 'player_page.dart';
import 'theme.dart';
import 'tv_focus.dart';

class LibraryPage extends StatelessWidget {
  const LibraryPage({super.key, required this.store});

  final MediaStore store;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: store,
      builder: (context, _) {
        final account = store.account;
        if (account == null) {
          return _MediaLogin(store: store);
        }
        return _LibraryBrowser(
          key: ValueKey('${account.baseUrl}|${account.userId}'),
          store: store,
          account: account,
        );
      },
    );
  }
}

class _MediaLogin extends StatefulWidget {
  const _MediaLogin({required this.store});

  final MediaStore store;

  @override
  State<_MediaLogin> createState() => _MediaLoginState();
}

class _MediaLoginState extends State<_MediaLogin> {
  final _url = TextEditingController();
  final _user = TextEditingController();
  final _password = TextEditingController();
  MediaServerType _type = MediaServerType.jellyfin;
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _url.dispose();
    _user.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _connect() async {
    final url = _url.text.trim();
    if (url.isEmpty) {
      setState(() => _error = '请输入服务器地址');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await widget.store.login(
        type: _type,
        baseUrl: url,
        username: _user.text.trim(),
        password: _password.text,
        plexToken: _type == MediaServerType.plex ? _password.text : null,
      );
      if (!mounted) return;
      if (widget.store.error != null) {
        setState(() => _error = widget.store.error);
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.sizeOf(context).width >= 850;
    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(wide ? 36 : 20, 30, wide ? 36 : 20, 40),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1120),
          child: wide
              ? Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Expanded(flex: 11, child: _MediaIntro()),
                    const SizedBox(width: 46),
                    Expanded(flex: 9, child: _buildCard()),
                  ],
                )
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const _MediaIntro(compact: true),
                    const SizedBox(height: 26),
                    _buildCard(),
                  ],
                ),
        ),
      ),
    );
  }

  Widget _buildCard() {
    final isPlex = _type == MediaServerType.plex;
    return GlassCard(
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 22),
      radius: 24,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.lock_open_rounded,
                color: MoonColors.accent,
                size: 18,
              ),
              const SizedBox(width: 9),
              Text('连接媒体服务器', style: Theme.of(context).textTheme.titleLarge),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'Jellyfin / Emby 账号密码，或 Plex 的 X-Plex-Token。',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 18),
          Wrap(
            spacing: 8,
            children: [
              for (final type in MediaServerType.values)
                _TypeChip(
                  label: type.label,
                  selected: _type == type,
                  onTap: () => setState(() {
                    _type = type;
                    _error = null;
                  }),
                ),
            ],
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _url,
            keyboardType: TextInputType.url,
            textInputAction: TextInputAction.next,
            decoration: InputDecoration(
              labelText: '服务器地址',
              hintText: isPlex
                  ? 'http://192.168.1.20:32400'
                  : 'http://192.168.1.20:8096',
              prefixIcon: const Icon(Icons.dns_outlined, size: 19),
            ),
          ),
          const SizedBox(height: 11),
          TextField(
            controller: _user,
            textInputAction: TextInputAction.next,
            decoration: InputDecoration(
              labelText: isPlex ? '账号名（可选）' : '用户名',
              prefixIcon: const Icon(Icons.person_outline_rounded, size: 19),
            ),
          ),
          const SizedBox(height: 11),
          TextField(
            controller: _password,
            obscureText: !isPlex,
            onSubmitted: (_) => _busy ? null : _connect(),
            decoration: InputDecoration(
              labelText: isPlex ? 'X-Plex-Token' : '密码',
              prefixIcon: Icon(
                isPlex ? Icons.key_rounded : Icons.password_rounded,
                size: 19,
              ),
            ),
          ),
          if (_error != null) ...[
            const SizedBox(height: 12),
            Text(
              _error!,
              style: const TextStyle(
                color: MoonColors.danger,
                fontSize: 11.5,
                height: 1.4,
              ),
            ),
          ],
          const SizedBox(height: 18),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: _busy ? null : _connect,
              icon: _busy
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Color(0xFF03141D),
                      ),
                    )
                  : const Icon(Icons.arrow_forward_rounded, size: 19),
              label: Text(_busy ? '正在连接…' : '进入媒体库'),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            '凭据只保存在本机，用于直接访问你的服务器。',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    );
  }
}

class _MediaIntro extends StatelessWidget {
  const _MediaIntro({this.compact = false});

  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Eyebrow('MEDIA LIBRARY / 媒体库'),
        const SizedBox(height: 14),
        Text(
          '你的媒体库，\n回到原生体验。',
          style: Theme.of(context).textTheme.displayMedium
              ?.copyWith(fontSize: compact ? 31 : 44, height: 1.12),
        ),
        const SizedBox(height: 16),
        Text(
          '连接 Jellyfin、Emby 或 Plex，浏览电影与剧集、继续观看、记录播放进度。片源聚合模式仍然保留，随时切换。',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(height: 1.7),
        ),
        const SizedBox(height: 22),
        Wrap(
          spacing: 9,
          runSpacing: 9,
          children: const [
            AccentPill(label: '原生媒体库', icon: Icons.video_library_outlined),
            AccentPill(
              label: '继续观看',
              icon: Icons.history_rounded,
              color: MoonColors.violet,
            ),
            AccentPill(
              label: '进度同步',
              icon: Icons.sync_rounded,
              color: MoonColors.success,
            ),
          ],
        ),
      ],
    );
  }
}

class _TypeChip extends StatefulWidget {
  const _TypeChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  State<_TypeChip> createState() => _TypeChipState();
}

class _TypeChipState extends State<_TypeChip> {
  bool _focused = false;

  @override
  Widget build(BuildContext context) {
    return FocusableActionDetector(
      onFocusChange: (value) {
        setState(() => _focused = value);
        if (value) ensureTvFocusVisible(context, alignment: 0.5);
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
      child: InkWell(
        canRequestFocus: false,
        onTap: widget.onTap,
        borderRadius: BorderRadius.circular(30),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
          decoration: BoxDecoration(
            color: widget.selected
                ? MoonColors.accent.withValues(alpha: 0.16)
                : Colors.white.withValues(alpha: 0.035),
            borderRadius: BorderRadius.circular(30),
            border: Border.all(
              color: _focused
                  ? MoonColors.accentStrong
                  : widget.selected
                  ? MoonColors.accent.withValues(alpha: 0.4)
                  : Colors.white.withValues(alpha: 0.08),
              width: _focused ? 1.5 : 1,
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
    );
  }
}

class _LibraryBrowser extends StatefulWidget {
  const _LibraryBrowser({
    super.key,
    required this.store,
    required this.account,
  });

  final MediaStore store;
  final MediaAccount account;

  @override
  State<_LibraryBrowser> createState() => _LibraryBrowserState();
}

class _LibraryBrowserState extends State<_LibraryBrowser> {
  final _scroll = ScrollController();
  String? _libraryId;
  List<MediaItem> _items = const [];
  int _total = 0;
  bool _loading = true;
  bool _loadingMore = false;
  String? _error;
  int _requestId = 0;

  List<MediaLibrary> get _libraries => widget.store.libraries;

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_onScroll);
    _bootstrap();
  }

  @override
  void dispose() {
    _scroll.removeListener(_onScroll);
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _bootstrap() async {
    if (_libraries.isEmpty) {
      await widget.store.refresh();
    }
    if (!mounted) return;
    final libraries = widget.store.libraries;
    if (libraries.isEmpty) {
      setState(() {
        _loading = false;
        _error = widget.store.error;
      });
      return;
    }
    _libraryId ??= libraries.first.id;
    await _load(reset: true);
  }

  void _onScroll() {
    if (!_scroll.hasClients || _loading || _loadingMore) return;
    if (_scroll.position.pixels >= _scroll.position.maxScrollExtent - 700) {
      _load(reset: false);
    }
  }

  Future<void> _selectLibrary(MediaLibrary library) async {
    if (_libraryId == library.id) return;
    setState(() {
      _libraryId = library.id;
      _items = const [];
      _total = 0;
      _error = null;
    });
    await _load(reset: true);
  }

  Future<void> _load({required bool reset}) async {
    final libraryId = _libraryId;
    if (libraryId == null) return;
    final request = ++_requestId;
    if (reset) {
      setState(() {
        _loading = true;
        _error = null;
      });
    } else {
      if (_loadingMore) return;
      setState(() => _loadingMore = true);
    }
    try {
      final result = await widget.store.api.items(
        widget.account,
        libraryId: libraryId,
        startIndex: reset ? 0 : _items.length,
        limit: 30,
      );
      if (!mounted || request != _requestId) return;
      setState(() {
        if (reset) {
          _items = result.$1;
        } else {
          final seen = _items.map((item) => item.id).toSet();
          _items = [..._items, ...result.$1.where((item) => seen.add(item.id))];
        }
        _total = result.$2;
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

  void _openItem(MediaItem item) {
    Navigator.of(context)
        .push(
          MaterialPageRoute(
            builder: (_) => LibraryDetailPage(
              store: widget.store,
              account: widget.account,
              initialItem: item,
            ),
          ),
        )
        .then((_) {
          if (!mounted) return;
          widget.store.refresh();
          _load(reset: true);
        });
  }

  Future<void> _playResume(MediaItem item) async {
    if (!item.isPlayable) {
      _openItem(item);
      return;
    }
    final account = widget.account;
    final position = Duration(microseconds: item.positionTicks ~/ 10);
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => PlayerPage(
          title: item.name,
          episodes: [
            Episode(
              name: item.name,
              url: widget.store.api.streamUrl(account, item),
            ),
          ],
          initialIndex: 0,
          initialPosition: position,
          sourceName: account.serverName,
          onOpened: (_) {
            unawaited(
              widget.store.api
                  .reportStart(account, item, position)
                  .catchError((_) {}),
            );
          },
          onProgress: (current, position, duration, paused) {
            unawaited(
              widget.store.api
                  .reportProgress(
                    account,
                    item,
                    position,
                    paused: paused,
                    duration: duration,
                  )
                  .catchError((_) {}),
            );
          },
          onStopped: (current, position) {
            unawaited(
              widget.store.api
                  .reportStopped(account, item, position)
                  .catchError((_) {}),
            );
          },
        ),
      ),
    );
    if (!mounted) return;
    unawaited(widget.store.refresh());
    await _load(reset: true);
  }

  Future<void> _showResumeMenu(MediaItem item, Rect anchor) async {
    final overlay = Overlay.of(context).context.findRenderObject();
    if (overlay is! RenderBox) return;
    final size = overlay.size;
    const menuWidth = 232.0;
    const gap = 10.0;
    final opensRight = anchor.right + gap + menuWidth <= size.width;
    final left =
        (opensRight ? anchor.right + gap : anchor.left - gap - menuWidth)
            .clamp(8.0, size.width - menuWidth - 8)
            .toDouble();
    final top = anchor.top.clamp(8.0, size.height - 320).toDouble();
    final isFavorite = widget.store.isFavorite(item);
    final action = await showGeneralDialog<_ResumeAction>(
      context: context,
      barrierDismissible: true,
      barrierLabel: '关闭菜单',
      barrierColor: Colors.black.withValues(alpha: 0.12),
      transitionDuration: const Duration(milliseconds: 120),
      transitionBuilder: (context, animation, secondaryAnimation, child) =>
          FadeTransition(opacity: animation, child: child),
      pageBuilder: (dialogContext, animation, secondaryAnimation) {
        return _ResumePopup(
          left: left,
          top: top,
          width: menuWidth,
          isFavorite: isFavorite,
          onSelected: (value) => Navigator.of(dialogContext).pop(value),
        );
      },
    );
    if (!mounted || action == null) return;
    switch (action) {
      case _ResumeAction.play:
        await _playResume(item);
        break;
      case _ResumeAction.favorite:
        await _toggleFavorite(item);
        break;
      case _ResumeAction.hide:
        _hideResume(item);
        break;
      case _ResumeAction.details:
        _openItem(item);
        break;
    }
  }

  Future<void> _toggleFavorite(MediaItem item) async {
    final wasFavorite = widget.store.isFavorite(item);
    try {
      await widget.store.toggleFavorite(item);
      if (!mounted) return;
      _showMessage(wasFavorite ? '已取消收藏' : '已收藏');
    } catch (error) {
      if (!mounted) return;
      _showMessage('收藏失败：$error');
    }
  }

  void _hideResume(MediaItem item) {
    unawaited(widget.store.hideResume(item));
  }

  void _showMessage(String message) {
    final messenger = ScaffoldMessenger.of(context);
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final tv = TvMode.of(context).isTv;
    final wide = width >= 900;
    final pad = tv ? 56.0 : (wide ? 36.0 : 20.0);
    return RefreshIndicator(
      color: MoonColors.accent,
      backgroundColor: MoonColors.surface,
      onRefresh: () => _load(reset: true),
      child: CustomScrollView(
        controller: _scroll,
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          SliverPadding(
            padding: EdgeInsets.fromLTRB(pad, 26, pad, 0),
            sliver: SliverToBoxAdapter(child: _buildHeader()),
          ),
          if (widget.store.resume.isNotEmpty)
            SliverPadding(
              padding: EdgeInsets.fromLTRB(pad, 24, pad, 0),
              sliver: SliverToBoxAdapter(child: _buildResume()),
            ),
          SliverPadding(
            padding: EdgeInsets.fromLTRB(pad, 22, pad, 0),
            sliver: SliverToBoxAdapter(child: _buildLibraryBar()),
          ),
          SliverPadding(
            padding: EdgeInsets.fromLTRB(pad, 18, pad, 8),
            sliver: SliverToBoxAdapter(child: _buildSectionHeader()),
          ),
          ..._buildBody(pad),
          const SliverToBoxAdapter(child: SizedBox(height: 46)),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    final account = widget.account;
    final tv = TvMode.of(context).isTv;
    final wide = MediaQuery.sizeOf(context).width >= 900;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Eyebrow('MEDIA / 媒体库'),
              const SizedBox(height: 9),
              Text(
                '你的私人影院。',
                style: Theme.of(context).textTheme.displayMedium
                    ?.copyWith(fontSize: tv ? 44 : (wide ? 38 : 29)),
              ),
              const SizedBox(height: 7),
              Text(
                '${account.serverName} · ${account.userName}',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ],
          ),
        ),
        _ToolbarButton(
          icon: Icons.refresh_rounded,
          label: '刷新',
          onTap: () => _load(reset: true),
        ),
        const SizedBox(width: 8),
        _ToolbarButton(
          icon: Icons.logout_rounded,
          label: '断开',
          onTap: () => widget.store.logout(),
        ),
      ],
    );
  }

  Widget _buildResume() {
    final items = widget.store.resume.take(12).toList();
    final tv = TvMode.of(context).isTv;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionHeader(
          title: '继续观看',
          subtitle: '从上次停下的地方继续',
          trailing: AccentPill(label: '${items.length} 部'),
        ),
        const SizedBox(height: 14),
        SizedBox(
          height: tv ? 238 : 205,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: items.length,
            separatorBuilder: (_, _) => const SizedBox(width: 12),
            itemBuilder: (context, index) {
              final item = items[index];
              return SizedBox(
                width: tv ? 156 : 132,
                child: _MediaPosterCard(
                  item: item,
                  account: widget.account,
                  onTap: () => _openItem(item),
                  onLongPress: (anchor) => _showResumeMenu(item, anchor),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildLibraryBar() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          for (final library in _libraries) ...[
            _LibraryChip(
              library: library,
              selected: library.id == _libraryId,
              onTap: () => _selectLibrary(library),
            ),
            const SizedBox(width: 8),
          ],
        ],
      ),
    );
  }

  Widget _buildSectionHeader() {
    final selected = _libraries
        .where((library) => library.id == _libraryId)
        .firstOrNull;
    return SectionHeader(
      title: selected?.name ?? '媒体库',
      subtitle: _total > 0
          ? '共 $_total 部 · ${selected?.kindLabel ?? '媒体'} '
          : '正在读取媒体库',
      trailing: _loading
          ? const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : null,
    );
  }

  List<Widget> _buildBody(double pad) {
    final tv = TvMode.of(context).isTv;
    if (_loading && _items.isEmpty) {
      return const [
        SliverFillRemaining(
          hasScrollBody: false,
          child: LoadingView(label: '正在读取媒体库'),
        ),
      ];
    }
    if (_error != null && _items.isEmpty) {
      return [
        SliverPadding(
          padding: EdgeInsets.fromLTRB(pad, 20, pad, 0),
          sliver: SliverToBoxAdapter(
            child: ErrorPanel(
              message: _error!,
              onRetry: () => _load(reset: true),
            ),
          ),
        ),
      ];
    }
    if (_items.isEmpty) {
      return [
        SliverFillRemaining(
          hasScrollBody: false,
          child: const EmptyState(
            icon: Icons.video_library_outlined,
            title: '这个媒体库还是空的',
            message: '到服务器上添加媒体后，下拉刷新即可。',
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
            final item = _items[index];
            return _MediaPosterCard(
              item: item,
              account: widget.account,
              onTap: () => _openItem(item),
            );
          }, childCount: _items.length),
        ),
      ),
      if (_loadingMore)
        const SliverToBoxAdapter(
          child: Padding(
            padding: EdgeInsets.all(18),
            child: Center(
              child: SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
          ),
        )
      else if (_items.length < _total)
        SliverToBoxAdapter(
          child: Center(
            child: TextButton(
              onPressed: () => _load(reset: false),
              child: const Text('加载更多'),
            ),
          ),
        ),
    ];
  }
}

class _LibraryChip extends StatefulWidget {
  const _LibraryChip({
    required this.library,
    required this.selected,
    required this.onTap,
  });

  final MediaLibrary library;
  final bool selected;
  final VoidCallback onTap;

  @override
  State<_LibraryChip> createState() => _LibraryChipState();
}

class _LibraryChipState extends State<_LibraryChip> {
  bool _focused = false;

  @override
  Widget build(BuildContext context) {
    return FocusableActionDetector(
      onFocusChange: (value) {
        setState(() => _focused = value);
        if (value) ensureTvFocusVisible(context, alignment: 0.5);
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
      child: InkWell(
        canRequestFocus: false,
        onTap: widget.onTap,
        borderRadius: BorderRadius.circular(30),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 8),
          decoration: BoxDecoration(
            color: widget.selected
                ? MoonColors.accent.withValues(alpha: 0.14)
                : Colors.white.withValues(alpha: 0.035),
            borderRadius: BorderRadius.circular(30),
            border: Border.all(
              color: _focused
                  ? MoonColors.accentStrong
                  : widget.selected
                  ? MoonColors.accent.withValues(alpha: 0.38)
                  : Colors.white.withValues(alpha: 0.07),
              width: _focused ? 1.5 : 1,
            ),
          ),
          child: Text(
            widget.library.name,
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
    );
  }
}

class _MediaPosterCard extends StatefulWidget {
  const _MediaPosterCard({
    required this.item,
    required this.account,
    required this.onTap,
    this.onLongPress,
  });

  final MediaItem item;
  final MediaAccount account;
  final VoidCallback onTap;
  final ValueChanged<Rect>? onLongPress;

  @override
  State<_MediaPosterCard> createState() => _MediaPosterCardState();
}

class _MediaPosterCardState extends State<_MediaPosterCard> {
  bool _focused = false;

  void _handleLongPress() {
    final box = context.findRenderObject();
    final overlay = Overlay.of(context).context.findRenderObject();
    if (box is! RenderBox || overlay is! RenderBox) return;
    final origin = box.localToGlobal(Offset.zero, ancestor: overlay);
    widget.onLongPress?.call(origin & box.size);
  }

  @override
  Widget build(BuildContext context) {
    final item = widget.item;
    final tv = TvMode.of(context).isTv;
    final card = Focus(
      canRequestFocus: false,
      skipTraversal: true,
      onKeyEvent: (node, event) {
        if (event is KeyDownEvent &&
            event.logicalKey == LogicalKeyboardKey.contextMenu) {
          _handleLongPress();
          return KeyEventResult.handled;
        }
        return KeyEventResult.ignored;
      },
      child: FocusableActionDetector(
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
          scale: _focused && tv ? 1.055 : (_focused ? 1.035 : 1),
          duration: const Duration(milliseconds: 160),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 160),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: _focused
                    ? MoonColors.accent
                    : Colors.white.withValues(alpha: 0.07),
                width: _focused ? (tv ? 2.5 : 2) : 1,
              ),
              boxShadow: _focused
                  ? [
                      BoxShadow(
                        color: MoonColors.accent.withValues(alpha: 0.25),
                        blurRadius: 24,
                        spreadRadius: 2,
                      ),
                    ]
                  : null,
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(17),
              child: Material(
                color: MoonColors.surface,
                child: InkWell(
                  canRequestFocus: false,
                  onTap: widget.onTap,
                  onLongPress: widget.onLongPress == null
                      ? null
                      : _handleLongPress,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      _MediaPosterImage(
                        url: item.imageUrl(widget.account, maxHeight: 560),
                        title: item.name,
                      ),
                      const _PosterShade(),
                      if (item.isSeries)
                        const Positioned(
                          top: 9,
                          left: 9,
                          child: _MiniBadge(
                            label: '剧集',
                            color: MoonColors.violet,
                          ),
                        ),
                      if (item.isPlayed)
                        const Positioned(
                          top: 9,
                          right: 9,
                          child: _MiniBadge(
                            label: '已看',
                            color: MoonColors.success,
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
                                  color: Colors.white.withValues(alpha: 0.62),
                                  fontSize: 10,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                      if (item.hasProgress)
                        Positioned(
                          left: 0,
                          right: 0,
                          bottom: 0,
                          child: LinearProgressIndicator(
                            value: item.progressFraction,
                            minHeight: 3,
                            backgroundColor: Colors.white.withValues(
                              alpha: 0.12,
                            ),
                            color: MoonColors.accent,
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    if (!tv || widget.onLongPress == null) return card;
    return Stack(
      clipBehavior: Clip.none,
      children: [
        card,
        Positioned(
          top: 6,
          right: 6,
          child: _TvCardMenuButton(onTap: _handleLongPress),
        ),
      ],
    );
  }
}

class _TvCardMenuButton extends StatefulWidget {
  const _TvCardMenuButton({required this.onTap});

  final VoidCallback onTap;

  @override
  State<_TvCardMenuButton> createState() => _TvCardMenuButtonState();
}

class _TvCardMenuButtonState extends State<_TvCardMenuButton> {
  bool _focused = false;

  @override
  Widget build(BuildContext context) {
    return FocusableActionDetector(
      onFocusChange: (value) {
        setState(() => _focused = value);
        if (value) ensureTvFocusVisible(context, alignment: 0.5);
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
      child: Material(
        color: Colors.black.withValues(alpha: 0.58),
        shape: const CircleBorder(),
        child: InkWell(
          customBorder: const CircleBorder(),
          canRequestFocus: false,
          onTap: widget.onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 120),
            width: 30,
            height: 30,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: _focused
                    ? MoonColors.accentStrong
                    : Colors.white.withValues(alpha: 0.25),
                width: _focused ? 2 : 1,
              ),
            ),
            child: Icon(
              Icons.more_horiz_rounded,
              size: 18,
              color: _focused ? Colors.white : Colors.white70,
            ),
          ),
        ),
      ),
    );
  }
}

class _MediaPosterImage extends StatelessWidget {
  const _MediaPosterImage({required this.url, required this.title});

  final String url;
  final String title;

  @override
  Widget build(BuildContext context) {
    if (url.isEmpty) return _PosterFallback(title: title);
    return CachedNetworkImage(
      imageUrl: url,
      fit: BoxFit.cover,
      fadeInDuration: const Duration(milliseconds: 200),
      placeholder: (_, _) => _PosterFallback(title: title, loading: true),
      errorWidget: (_, _, _) => _PosterFallback(title: title),
    );
  }
}

class _PosterFallback extends StatelessWidget {
  const _PosterFallback({required this.title, this.loading = false});

  final String title;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    final hue = (title.hashCode.abs() % 120) + 185;
    final top = HSLColor.fromAHSL(1, hue.toDouble(), 0.42, 0.25).toColor();
    final bottom = HSLColor.fromAHSL(1, (hue + 26) % 360, 0.4, 0.08).toColor();
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [top, bottom],
        ),
      ),
      child: Center(
        child: loading
            ? const SizedBox(
                width: 19,
                height: 19,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: MoonColors.faint,
                ),
              )
            : Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.local_movies_outlined,
                    color: Colors.white.withValues(alpha: 0.28),
                    size: 30,
                  ),
                  if (title.isNotEmpty) ...[
                    const SizedBox(height: 7),
                    Text(
                      title.substring(0, 1),
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.35),
                        fontSize: 24,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ],
              ),
      ),
    );
  }
}

class _PosterShade extends StatelessWidget {
  const _PosterShade();

  @override
  Widget build(BuildContext context) {
    return const DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0x00000000), Color(0x22000000), Color(0xE6000000)],
          stops: [0.42, 0.7, 1],
        ),
      ),
    );
  }
}

class _MiniBadge extends StatelessWidget {
  const _MiniBadge({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.62),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 9,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
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
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: onTap,
      icon: Icon(icon, size: 17),
      label: Text(label),
      style: OutlinedButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 12),
      ),
    );
  }
}

enum _ResumeAction { play, favorite, hide, details }

class _ResumePopup extends StatelessWidget {
  const _ResumePopup({
    required this.left,
    required this.top,
    required this.width,
    required this.isFavorite,
    required this.onSelected,
  });

  final double left;
  final double top;
  final double width;
  final bool isFavorite;
  final ValueChanged<_ResumeAction> onSelected;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Positioned(
          left: left,
          top: top,
          width: width,
          child: Material(
            color: MoonColors.surface,
            elevation: 20,
            shadowColor: Colors.black,
            clipBehavior: Clip.antiAlias,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: BorderSide(color: Colors.white.withValues(alpha: 0.12)),
            ),
            child: FocusTraversalGroup(
              policy: ReadingOrderTraversalPolicy(),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _ResumeMenuButton(
                    icon: Icons.play_arrow_rounded,
                    label: '继续播放',
                    autofocus: true,
                    onTap: () => onSelected(_ResumeAction.play),
                  ),
                  _ResumeMenuButton(
                    icon: isFavorite
                        ? Icons.favorite_rounded
                        : Icons.favorite_border_rounded,
                    label: isFavorite ? '取消收藏' : '收藏',
                    color: isFavorite ? MoonColors.danger : MoonColors.accent,
                    onTap: () => onSelected(_ResumeAction.favorite),
                  ),
                  _ResumeMenuButton(
                    icon: Icons.visibility_off_outlined,
                    label: '隐藏',
                    color: MoonColors.muted,
                    onTap: () => onSelected(_ResumeAction.hide),
                  ),
                  _ResumeMenuButton(
                    icon: Icons.info_outline_rounded,
                    label: '查看详情',
                    onTap: () => onSelected(_ResumeAction.details),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _ResumeMenuButton extends StatelessWidget {
  const _ResumeMenuButton({
    required this.icon,
    required this.label,
    required this.onTap,
    this.color = MoonColors.accent,
    this.autofocus = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Color color;
  final bool autofocus;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      autofocus: autofocus,
      onTap: onTap,
      focusColor: MoonColors.accent.withValues(alpha: 0.12),
      hoverColor: Colors.white.withValues(alpha: 0.06),
      child: SizedBox(
        height: 43,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 13),
          child: Row(
            children: [
              Icon(icon, size: 19, color: color),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: color == MoonColors.muted
                        ? MoonColors.muted
                        : MoonColors.text,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
