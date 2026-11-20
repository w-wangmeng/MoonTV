import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../media/media_models.dart';
import '../media/media_store.dart';
import '../models.dart';
import '../store/app_store.dart';
import '../tv_mode.dart';
import 'detail_page.dart';
import 'library_detail_page.dart';
import 'poster_card.dart';
import 'theme.dart';

class SearchPage extends StatefulWidget {
  const SearchPage({super.key, required this.store, required this.mediaStore});

  final AppStore store;
  final MediaStore mediaStore;

  @override
  State<SearchPage> createState() => _SearchPageState();
}

class _SearchPageState extends State<SearchPage> {
  final _controller = TextEditingController();
  final _focusNode = FocusNode();
  bool _allSources = false;
  bool _loading = false;
  bool _mediaLoading = false;
  String? _error;
  String? _mediaError;
  SearchOutcome? _outcome;
  List<MediaItem> _mediaHits = const [];
  String _query = '';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      // On a TV the remote should first land on the top navigation. The user
      // presses Down to enter the query field instead of opening the keyboard
      // every time the search page is selected.
      if (!TvMode.of(context).isTv) _focusNode.requestFocus();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  Future<void> _search([String? value]) async {
    final query = (value ?? _controller.text).trim();
    final hasSources = widget.store.hasPlayableSources;
    final hasMedia = widget.mediaStore.hasServer;
    if (query.isEmpty) {
      setState(() => _error = '输入片名、演员或关键词');
      return;
    }
    if (!hasSources && !hasMedia) {
      setState(() => _error = '还没有连接媒体库或站源');
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
      _query = query;
      _outcome = null;
      _mediaHits = const [];
      _mediaError = null;
      _mediaLoading = hasMedia;
    });

    SearchOutcome? outcome;
    String? sourceError;
    if (hasSources) {
      try {
        outcome = await widget.store.search(query, allSources: _allSources);
      } catch (error) {
        sourceError = error.toString();
      }
    } else {
      outcome = const SearchOutcome(hits: [], errors: 0, searched: 0);
    }

    var mediaHits = const <MediaItem>[];
    String? mediaError;
    if (hasMedia) {
      try {
        mediaHits = await widget.mediaStore.searchItems(query);
      } catch (error) {
        mediaError = error.toString();
      }
    }

    if (!mounted) return;
    setState(() {
      _outcome = outcome;
      _error = sourceError;
      _mediaHits = mediaHits;
      _mediaError = mediaError;
      _loading = false;
      _mediaLoading = false;
    });
  }

  void _open(VodItem item, SourceSite site) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) =>
            DetailPage(store: widget.store, site: site, initialItem: item),
      ),
    );
  }

  void _openMedia(MediaItem item) {
    final account = widget.mediaStore.account;
    if (account == null) return;
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => LibraryDetailPage(
          store: widget.mediaStore,
          account: account,
          initialItem: item,
        ),
      ),
    );
  }

  void _suggestion(String value) {
    _controller.text = value;
    _controller.selection = TextSelection.fromPosition(
      TextPosition(offset: value.length),
    );
    _search(value);
  }

  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.sizeOf(context).width >= 900;
    final tv = TvMode.of(context).isTv;
    final horizontal = tv ? 56.0 : (wide ? 36.0 : 20.0);
    return CustomScrollView(
      slivers: [
        SliverPadding(
          padding: EdgeInsets.fromLTRB(horizontal, 26, horizontal, 0),
          sliver: SliverToBoxAdapter(child: _buildHeader(context)),
        ),
        SliverPadding(
          padding: EdgeInsets.fromLTRB(horizontal, 22, horizontal, 0),
          sliver: SliverToBoxAdapter(child: _buildSearchBar(context)),
        ),
        SliverPadding(
          padding: EdgeInsets.fromLTRB(horizontal, 24, horizontal, 0),
          sliver: SliverToBoxAdapter(child: _buildResultHeader(context)),
        ),
        ..._buildResults(context, horizontal),
        const SliverToBoxAdapter(child: SizedBox(height: 40)),
      ],
    );
  }

  Widget _buildHeader(BuildContext context) {
    final current = widget.store.current;
    final media = widget.mediaStore.account;
    final tv = TvMode.of(context).isTv;
    final wide = MediaQuery.sizeOf(context).width >= 900;
    final parts = <String>[
      if (media != null) '媒体库：${media.serverName}',
      if (current != null)
        '站源：${current.displayName} · ${widget.store.enabledSites.length} 个可用',
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Eyebrow('SEARCH / 搜索'),
        const SizedBox(height: 9),
        Text(
          '一次输入，媒体库与站源一起找。',
          style: Theme.of(context).textTheme.displayMedium
              ?.copyWith(fontSize: tv ? 44 : (wide ? 38 : 29)),
        ),
        const SizedBox(height: 7),
        Text(
          parts.isEmpty ? '先连接媒体库或内容源。' : parts.join(' · '),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: Theme.of(context).textTheme.bodyMedium,
        ),
      ],
    );
  }

  Widget _buildSearchBar(BuildContext context) {
    return GlassCard(
      padding: const EdgeInsets.all(14),
      radius: 18,
      child: Column(
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: TextField(
                  controller: _controller,
                  focusNode: _focusNode,
                  textInputAction: TextInputAction.search,
                  onSubmitted: _search,
                  style: const TextStyle(fontSize: 14),
                  decoration: const InputDecoration(
                    hintText: '搜索媒体库、片名或关键词',
                    prefixIcon: Icon(
                      Icons.search_rounded,
                      size: 20,
                      color: MoonColors.faint,
                    ),
                    contentPadding: EdgeInsets.symmetric(
                      horizontal: 15,
                      vertical: 15,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              SizedBox(
                height: 51,
                child: FilledButton(
                  onPressed: _loading ? null : () => _search(),
                  child: _loading
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Color(0xFF03141D),
                          ),
                        )
                      : const Icon(Icons.arrow_forward_rounded, size: 20),
                ),
              ),
            ],
          ),
          if (widget.store.hasPlayableSources) ...[
            const SizedBox(height: 11),
            Row(
              children: [
                _ModeChip(
                  label: '当前站源',
                  selected: !_allSources,
                  onTap: () => setState(() => _allSources = false),
                ),
                const SizedBox(width: 8),
                _ModeChip(
                  label: '全部站源',
                  selected: _allSources,
                  onTap: () => setState(() => _allSources = true),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    _allSources ? '媒体库始终参与 · 站源最多 24 个' : '媒体库始终参与 · 只搜当前站源',
                    textAlign: TextAlign.right,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodySmall
                        ?.copyWith(fontSize: 10.5),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildResultHeader(BuildContext context) {
    final outcome = _outcome;
    if (_query.isEmpty) {
      return SectionHeader(title: '开始搜索', subtitle: '输入关键词，同时搜索媒体库与站源。');
    }
    final loading = _loading || _mediaLoading;
    final mediaCount = _mediaHits.length;
    final sourceCount = outcome?.hits.length ?? 0;
    final total = mediaCount + sourceCount;
    final bits = <String>[
      if (mediaCount > 0) '媒体库 $mediaCount 个',
      if (sourceCount > 0) '站源 $sourceCount 个',
    ];
    final subtitle = loading && bits.isEmpty
        ? '正在检索…'
        : bits.isEmpty
        ? '没有找到匹配内容'
        : bits.join(' · ');
    return SectionHeader(
      title: '“$_query” 的结果',
      subtitle: subtitle,
      trailing: !loading && total > 0
          ? AccentPill(
              label: '$total 个结果',
              icon: Icons.search_rounded,
              filled: true,
            )
          : null,
    );
  }

  List<Widget> _buildResults(BuildContext context, double horizontal) {
    if (_loading) {
      return [
        SliverPadding(
          padding: EdgeInsets.fromLTRB(horizontal, 22, horizontal, 0),
          sliver: SliverGrid(
            gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
              maxCrossAxisExtent: 215,
              mainAxisSpacing: 16,
              crossAxisSpacing: 14,
              childAspectRatio: 0.64,
            ),
            delegate: SliverChildBuilderDelegate(
              (context, _) => const PosterSkeleton(),
              childCount: 8,
            ),
          ),
        ),
      ];
    }

    final outcome = _outcome;
    final media = _mediaHits;
    final hits = outcome?.hits ?? const <SearchHit>[];

    if (media.isEmpty && hits.isEmpty) {
      if (_error != null || _mediaError != null) {
        return [
          SliverPadding(
            padding: EdgeInsets.fromLTRB(horizontal, 14, horizontal, 0),
            sliver: SliverToBoxAdapter(
              child: ErrorPanel(
                message: _error ?? _mediaError!,
                onRetry: () => _search(),
              ),
            ),
          ),
        ];
      }
      if (outcome == null) {
        return [
          SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.fromLTRB(horizontal, 18, horizontal, 0),
              child: _SearchSuggestions(onTap: _suggestion),
            ),
          ),
        ];
      }
      return [
        SliverFillRemaining(
          hasScrollBody: false,
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: EmptyState(
              icon: Icons.search_off_rounded,
              title: '没有找到结果',
              message: widget.store.hasPlayableSources
                  ? (_allSources
                        ? '试试更短的关键词，或者切换到当前站源再搜一次。'
                        : '这个源可能没有收录，试试「全部站源」。')
                  : '试试更短的关键词，或换一个片名。',
              action: widget.store.hasPlayableSources
                  ? OutlinedButton.icon(
                      onPressed: () {
                        setState(() => _allSources = !_allSources);
                        _search();
                      },
                      icon: Icon(
                        _allSources
                            ? Icons.dns_outlined
                            : Icons.layers_outlined,
                        size: 18,
                      ),
                      label: Text(_allSources ? '只搜当前源' : '搜索全部源'),
                    )
                  : null,
            ),
          ),
        ),
      ];
    }

    final slivers = <Widget>[];
    if (media.isNotEmpty) {
      slivers.add(
        SliverPadding(
          padding: EdgeInsets.fromLTRB(horizontal, 18, horizontal, 0),
          sliver: SliverToBoxAdapter(
            child: SectionHeader(
              title: '媒体库',
              subtitle: '${media.length} 个匹配',
              trailing: const AccentPill(label: '媒体服务器'),
            ),
          ),
        ),
      );
      slivers.add(
        SliverPadding(
          padding: EdgeInsets.fromLTRB(horizontal, 14, horizontal, 0),
          sliver: SliverGrid(
            gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
              maxCrossAxisExtent: 215,
              mainAxisSpacing: 16,
              crossAxisSpacing: 14,
              childAspectRatio: 0.64,
            ),
            delegate: SliverChildBuilderDelegate((context, index) {
              final account = widget.mediaStore.account;
              if (account == null) return const SizedBox.shrink();
              final item = media[index];
              return _MediaResultCard(
                item: item,
                account: account,
                onTap: () => _openMedia(item),
              );
            }, childCount: media.length),
          ),
        ),
      );
    }
    if (hits.isNotEmpty) {
      if (media.isNotEmpty) {
        slivers.add(
          SliverPadding(
            padding: EdgeInsets.fromLTRB(horizontal, 24, horizontal, 0),
            sliver: SliverToBoxAdapter(
              child: SectionHeader(
                title: '站源',
                subtitle: '${hits.length} 个结果',
                trailing: AccentPill(
                  label: _allSources ? '全源' : '当前源',
                  icon: Icons.filter_alt_outlined,
                ),
              ),
            ),
          ),
        );
      }
      slivers.add(
        SliverPadding(
          padding: EdgeInsets.fromLTRB(
            horizontal,
            media.isEmpty ? 22 : 14,
            horizontal,
            0,
          ),
          sliver: SliverGrid(
            gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
              maxCrossAxisExtent: 215,
              mainAxisSpacing: 16,
              crossAxisSpacing: 14,
              childAspectRatio: 0.64,
            ),
            delegate: SliverChildBuilderDelegate((context, index) {
              final hit = hits[index];
              return PosterCard(
                item: hit.item,
                sourceName: hit.site.displayName,
                showSource: _allSources,
                onTap: () => _open(hit.item, hit.site),
              );
            }, childCount: hits.length),
          ),
        ),
      );
    }
    return slivers;
  }
}

class _MediaResultCard extends StatefulWidget {
  const _MediaResultCard({
    required this.item,
    required this.account,
    required this.onTap,
  });

  final MediaItem item;
  final MediaAccount account;
  final VoidCallback onTap;

  @override
  State<_MediaResultCard> createState() => _MediaResultCardState();
}

class _MediaResultCardState extends State<_MediaResultCard> {
  bool _focused = false;

  @override
  Widget build(BuildContext context) {
    final item = widget.item;
    final url = item.imageUrl(widget.account, maxHeight: 560);
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
          child: ClipRRect(
            borderRadius: BorderRadius.circular(17),
            child: Material(
              color: MoonColors.surface,
              child: InkWell(
                canRequestFocus: false,
                onTap: widget.onTap,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    if (url.isEmpty)
                      const _MediaPosterFallback()
                    else
                      CachedNetworkImage(
                        imageUrl: url,
                        fit: BoxFit.cover,
                        fadeInDuration: const Duration(milliseconds: 180),
                        placeholder: (_, _) =>
                            Container(color: MoonColors.surface2),
                        errorWidget: (_, _, _) => const _MediaPosterFallback(),
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
                                color: Colors.white.withValues(alpha: 0.62),
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
        ),
      ),
    );
  }
}

class _MediaPosterFallback extends StatelessWidget {
  const _MediaPosterFallback();

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

class _ModeChip extends StatefulWidget {
  const _ModeChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  State<_ModeChip> createState() => _ModeChipState();
}

class _ModeChipState extends State<_ModeChip> {
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
      child: InkWell(
        canRequestFocus: false,
        onTap: widget.onTap,
        borderRadius: BorderRadius.circular(30),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
          decoration: BoxDecoration(
            color: widget.selected
                ? MoonColors.accent.withValues(alpha: 0.14)
                : Colors.white.withValues(alpha: 0.035),
            borderRadius: BorderRadius.circular(30),
            border: Border.all(
              color: _focused
                  ? MoonColors.accentStrong
                  : widget.selected
                  ? MoonColors.accent.withValues(alpha: 0.35)
                  : Colors.white.withValues(alpha: 0.07),
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

class _SearchSuggestions extends StatelessWidget {
  const _SearchSuggestions({required this.onTap});

  final ValueChanged<String> onTap;

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.wb_sunny_outlined,
                size: 18,
                color: MoonColors.gold,
              ),
              const SizedBox(width: 8),
              Text('不知道看什么？', style: Theme.of(context).textTheme.titleMedium),
            ],
          ),
          const SizedBox(height: 7),
          Text(
            '从这些关键词开始，MoonTV 会同时问你的每一个站源。',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 15),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final word in const ['庆余年', '奥本海默', '三体', '繁花', '沙丘', '周星驰'])
                _SuggestionChip(label: word, onTap: () => onTap(word)),
            ],
          ),
        ],
      ),
    );
  }
}

class _SuggestionChip extends StatelessWidget {
  const _SuggestionChip({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

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
            onTap();
            return null;
          },
        ),
      },
      child: InkWell(
        canRequestFocus: false,
        onTap: onTap,
        borderRadius: BorderRadius.circular(30),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.035),
            borderRadius: BorderRadius.circular(30),
            border: Border.all(color: Colors.white.withValues(alpha: 0.07)),
          ),
          child: Text(
            label,
            style: const TextStyle(
              color: MoonColors.muted,
              fontSize: 11.5,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }
}
