import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../media/media_store.dart';
import '../models.dart';
import '../store/app_store.dart';
import '../tv_mode.dart';
import '../update/update_dialog.dart';
import 'discover_page.dart';
import 'favorites_page.dart';
import 'library_page.dart';
import 'search_page.dart';
import 'settings_page.dart';
import 'sources_page.dart';
import 'theme.dart';
import 'tv_focus.dart';

class AppShell extends StatefulWidget {
  const AppShell({super.key, required this.store, required this.mediaStore});

  final AppStore store;
  final MediaStore mediaStore;

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  late int _index;
  bool _barHidden = false;
  double _scrollPixels = 0;

  @override
  void initState() {
    super.initState();
    _index = widget.mediaStore.hasServer ? 0 : (widget.store.hasConfig ? 1 : 0);
    // 启动后稍作延迟静默检查更新；入口页渲染完成后再弹窗。
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Future<void>.delayed(const Duration(seconds: 2), () {
        if (!mounted) return;
        unawaited(maybePromptUpdate(context));
      });
    });
  }

  void _select(int index) {
    FocusManager.instance.primaryFocus?.unfocus();
    if (_index == index) return;
    setState(() {
      _index = index;
      _barHidden = false;
    });
  }

  /// 统一的滚动处理：页面下滑时收起顶栏，上滑或回到顶部时展开。
  /// 电视模式（遥控器）下始终保留顶栏导航，不做折叠。
  bool _onScrollNotification(ScrollNotification notification) {
    if (TvMode.of(context).isTv) return false;
    if (notification.metrics.axis != Axis.vertical) return false;
    final current = notification.metrics.pixels;
    final delta = current - _scrollPixels;
    _scrollPixels = current;
    if (notification is ScrollUpdateNotification ||
        notification is OverscrollNotification) {
      if (delta > 8 && !_barHidden) {
        setState(() => _barHidden = true);
      } else if ((delta < -8 || current <= 4) && _barHidden) {
        setState(() => _barHidden = false);
      }
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final store = widget.store;
    final mediaStore = widget.mediaStore;

    return AnimatedBuilder(
      animation: Listenable.merge([store, mediaStore]),
      builder: (context, _) {
        final page = _pageFor(context, store, mediaStore, _index);
        final tv = TvMode.of(context).isTv;
        return Scaffold(
          backgroundColor: Colors.transparent,
          body: MoonBackdrop(
            child: Column(
              children: [
                AnimatedSize(
                  duration: const Duration(milliseconds: 220),
                  curve: Curves.easeOutCubic,
                  alignment: Alignment.topCenter,
                  child: _barHidden && !tv
                      ? const SizedBox(width: double.infinity, height: 0)
                      : _TopBar(width: width, index: _index, onSelect: _select),
                ),
                Expanded(
                  child: NotificationListener<ScrollNotification>(
                    onNotification: _onScrollNotification,
                    child: SafeArea(top: false, child: page),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _pageFor(
    BuildContext context,
    AppStore store,
    MediaStore mediaStore,
    int index,
  ) {
    switch (index) {
      case 0:
        return LibraryPage(store: mediaStore);
      case 1:
        return DiscoverPage(store: store, onOpenSources: () => _select(3));
      case 2:
        return SearchPage(store: store, mediaStore: mediaStore);
      case 3:
        return SourcesPage(store: store);
      case 4:
        return SettingsPage(
          store: store,
          mediaStore: mediaStore,
          tvMode: TvMode.of(context),
          onOpenSources: () => _select(3),
          onOpenLibrary: () => _select(0),
        );
      case 5:
        return FavoritesPage(
          store: mediaStore,
          onOpenLibrary: () => _select(0),
        );
      default:
        return LibraryPage(store: mediaStore);
    }
  }
}

class _TopBar extends StatelessWidget {
  const _TopBar({
    required this.width,
    required this.index,
    required this.onSelect,
  });

  final double width;
  final int index;
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context) {
    final tv = TvMode.of(context).isTv;
    final compact = !tv && width < 560;
    final tiny = !tv && width < 430;
    final showLogo = width >= 340;
    final showClock = width >= 500;
    final logoSize = tv ? 32.0 : (tiny ? 26.0 : (compact ? 28.0 : 30.0));
    final iconSize = tv ? 25.0 : (tiny ? 20.0 : (compact ? 21.0 : 22.0));
    final boxSize = tv ? 44.0 : (tiny ? 30.0 : (compact ? 32.0 : 34.0));
    final gap = tv ? 28.0 : (tiny ? 10.0 : (compact ? 14.0 : 18.0));
    final edge = tv ? 40.0 : (tiny ? 10.0 : (compact ? 14.0 : 24.0));

    final nav = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _TopIcon(
          icon: Icons.home_rounded,
          label: '媒体库',
          selected: index == 0,
          autofocus: tv && index == 0,
          onTap: () => onSelect(0),
          size: iconSize,
          boxSize: boxSize,
        ),
        SizedBox(width: gap),
        _TopIcon(
          icon: Icons.movie_filter_rounded,
          label: '站源库',
          selected: index == 1,
          autofocus: tv && index == 1,
          onTap: () => onSelect(1),
          size: iconSize,
          boxSize: boxSize,
        ),
        SizedBox(width: gap),
        _TopIcon(
          icon: Icons.search_rounded,
          label: '搜索',
          selected: index == 2,
          autofocus: tv && index == 2,
          onTap: () => onSelect(2),
          size: iconSize,
          boxSize: boxSize,
        ),
        SizedBox(width: gap),
        _TopIcon(
          icon: Icons.favorite_rounded,
          label: '收藏',
          selected: index == 5,
          autofocus: tv && index == 5,
          onTap: () => onSelect(5),
          size: iconSize,
          boxSize: boxSize,
        ),
        SizedBox(width: gap),
        _TopIcon(
          icon: Icons.settings_rounded,
          label: '设置',
          selected: index == 3 || index == 4,
          autofocus: tv && (index == 3 || index == 4),
          onTap: () => onSelect(4),
          size: iconSize,
          boxSize: boxSize,
        ),
      ],
    );

    return SafeArea(
      bottom: false,
      child: SizedBox(
        height: tv ? 72 : 60,
        child: Stack(
          children: [
            if (showLogo)
              Positioned(
                left: edge,
                top: 0,
                bottom: 0,
                child: Center(child: _TopLogo(size: logoSize)),
              ),
            Center(child: nav),
            if (showClock)
              Positioned(
                right: edge,
                top: 0,
                bottom: 0,
                child: const Center(child: _TopClock()),
              ),
          ],
        ),
      ),
    );
  }
}

class _TopLogo extends StatelessWidget {
  const _TopLogo({required this.size});

  final double size;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: Image.asset(
        'assets/logo_mark.png',
        fit: BoxFit.contain,
        filterQuality: FilterQuality.high,
      ),
    );
  }
}

class _TopIcon extends StatefulWidget {
  const _TopIcon({
    required this.icon,
    required this.label,
    required this.onTap,
    required this.size,
    required this.boxSize,
    this.selected = false,
    this.autofocus = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final double size;
  final double boxSize;
  final bool selected;
  final bool autofocus;

  @override
  State<_TopIcon> createState() => _TopIconState();
}

class _TopIconState extends State<_TopIcon> {
  final _focusNode = FocusNode(debugLabel: 'top-nav');
  bool _focused = false;

  @override
  void didUpdateWidget(covariant _TopIcon oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.autofocus && !oldWidget.autofocus) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _focusNode.requestFocus();
      });
    }
  }

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: widget.selected,
      label: widget.label,
      child: Tooltip(
        message: widget.label,
        excludeFromSemantics: true,
        child: FocusableActionDetector(
          focusNode: _focusNode,
          autofocus: widget.autofocus,
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
              customBorder: const CircleBorder(),
              onTap: widget.onTap,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 140),
                width: widget.boxSize,
                height: widget.boxSize,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: _focused
                      ? Colors.white.withValues(alpha: 0.16)
                      : Colors.transparent,
                  border: _focused
                      ? Border.all(
                          color: MoonColors.accentStrong.withValues(alpha: 0.8),
                          width: 1.4,
                        )
                      : null,
                ),
                child: Icon(
                  widget.icon,
                  size: widget.size,
                  color: widget.selected || _focused
                      ? Colors.white
                      : Colors.white.withValues(alpha: 0.6),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _SourceOption extends StatefulWidget {
  const _SourceOption({
    required this.site,
    required this.selected,
    required this.autofocus,
    required this.onTap,
  });

  final SourceSite site;
  final bool selected;
  final bool autofocus;
  final VoidCallback onTap;

  @override
  State<_SourceOption> createState() => _SourceOptionState();
}

class _SourceOptionState extends State<_SourceOption> {
  bool _focused = false;

  @override
  Widget build(BuildContext context) {
    final selected = widget.selected;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: FocusableActionDetector(
        autofocus: widget.autofocus,
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
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            canRequestFocus: false,
            onTap: widget.onTap,
            borderRadius: BorderRadius.circular(13),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 120),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: _focused
                    ? Colors.white.withValues(alpha: 0.08)
                    : selected
                    ? MoonColors.accent.withValues(alpha: 0.08)
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(13),
                border: Border.all(
                  color: _focused
                      ? MoonColors.accentStrong
                      : selected
                      ? MoonColors.accent.withValues(alpha: 0.2)
                      : Colors.transparent,
                  width: _focused ? 1.5 : 1,
                ),
              ),
              child: Row(
                children: [
                  SourceGlyph(name: widget.site.displayName, size: 34),
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
                            color: selected
                                ? MoonColors.accentStrong
                                : MoonColors.text,
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
                  if (selected)
                    const Icon(
                      Icons.check_circle_rounded,
                      color: MoonColors.accent,
                      size: 19,
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

class _TopClock extends StatefulWidget {
  const _TopClock();

  @override
  State<_TopClock> createState() => _TopClockState();
}

class _TopClockState extends State<_TopClock> {
  Timer? _timer;
  DateTime _now = DateTime.now();

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() => _now = DateTime.now());
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final hour = _now.hour.toString().padLeft(2, '0');
    final minute = _now.minute.toString().padLeft(2, '0');
    return Text(
      '$hour:$minute',
      style: const TextStyle(
        color: Colors.white,
        fontSize: 17,
        fontWeight: FontWeight.w500,
        letterSpacing: 0.4,
      ),
    );
  }
}

Future<void> showSourcePicker(BuildContext context, AppStore store) async {
  if (store.enabledSites.isEmpty) return;
  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (context) {
      return _SourcePickerSheet(store: store);
    },
  );
}

class _SourcePickerSheet extends StatefulWidget {
  const _SourcePickerSheet({required this.store});

  final AppStore store;

  @override
  State<_SourcePickerSheet> createState() => _SourcePickerSheetState();
}

class _SourcePickerSheetState extends State<_SourcePickerSheet> {
  final _search = TextEditingController();

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final query = _search.text.trim().toLowerCase();
    final sites = widget.store.enabledSites.where((site) {
      if (query.isEmpty) return true;
      return site.displayName.toLowerCase().contains(query) ||
          site.host.toLowerCase().contains(query);
    }).toList();

    return FractionallySizedBox(
      heightFactor: 0.78,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(22, 4, 22, 12),
            child: Row(
              children: [
                Text('切换站源', style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(width: 9),
                AccentPill(label: '${widget.store.enabledSites.length} 个'),
                const Spacer(),
                IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close_rounded),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 22),
            child: TextField(
              controller: _search,
              onChanged: (_) => setState(() {}),
              decoration: const InputDecoration(
                hintText: '搜索站源名称或域名',
                prefixIcon: Icon(Icons.search_rounded, size: 19),
                contentPadding: EdgeInsets.symmetric(
                  horizontal: 15,
                  vertical: 13,
                ),
              ),
            ),
          ),
          const SizedBox(height: 10),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.fromLTRB(14, 4, 14, 26),
              itemCount: sites.length,
              itemBuilder: (context, index) {
                final site = sites[index];
                final selected = widget.store.current?.key == site.key;
                return _SourceOption(
                  site: site,
                  selected: selected,
                  autofocus: selected,
                  onTap: () {
                    widget.store.selectSite(site);
                    Navigator.of(context).pop();
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
