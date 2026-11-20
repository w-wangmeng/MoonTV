import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../media/media_models.dart';
import '../media/media_store.dart';
import '../models.dart';
import '../tv_mode.dart';
import 'player_page.dart';
import 'theme.dart';
import 'tv_focus.dart';

class LibraryDetailPage extends StatefulWidget {
  const LibraryDetailPage({
    super.key,
    required this.store,
    required this.account,
    required this.initialItem,
  });

  final MediaStore store;
  final MediaAccount account;
  final MediaItem initialItem;

  @override
  State<LibraryDetailPage> createState() => _LibraryDetailPageState();
}

class _LibraryDetailPageState extends State<LibraryDetailPage> {
  late MediaItem _item;
  final _playFocus = FocusNode(debugLabel: 'library-detail-play');
  final _playKey = GlobalKey();
  MediaDetailData? _detail;
  bool _loading = true;
  String? _error;
  String? _seasonId;
  String? _initialEpisodeId;

  @override
  void initState() {
    super.initState();
    _item = widget.initialItem;
    _initialEpisodeId = _item.isEpisode ? _item.id : null;
    _playFocus.addListener(_revealPlay);
    _load();
    WidgetsBinding.instance.addPostFrameCallback((_) => _focusPlay());
  }

  @override
  void dispose() {
    _playFocus.dispose();
    super.dispose();
  }

  void _focusPlay() {
    if (!mounted || !TvMode.of(context).isTv) return;
    Future<void>.delayed(const Duration(milliseconds: 420), () {
      if (mounted && TvMode.of(context).isTv) _playFocus.requestFocus();
    });
  }

  void _revealPlay() {
    if (!_playFocus.hasFocus) return;
    final target = _playKey.currentContext;
    if (target != null) ensureTvFocusVisible(target, alignment: 0.82);
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      var base = _item;
      if (base.isEpisode && base.seriesId != null) {
        _initialEpisodeId = base.id;
        try {
          base = await widget.store.api.item(widget.account, base.seriesId!);
        } catch (_) {
          // Keep the episode if the parent series cannot be loaded.
        }
      }
      final detail = await widget.store.api.detail(widget.account, base);
      if (!mounted) return;
      setState(() {
        _detail = detail;
        _item = detail.item;
        _seasonId = _initialEpisodeId != null
            ? detail.episodes
                  .where((episode) => episode.id == _initialEpisodeId)
                  .map((episode) => episode.seasonId)
                  .whereType<String>()
                  .firstOrNull
            : (detail.seasons.isNotEmpty ? detail.seasons.first.id : null);
        _seasonId ??= detail.seasons.isNotEmpty
            ? detail.seasons.first.id
            : null;
        _loading = false;
      });
      WidgetsBinding.instance.addPostFrameCallback((_) => _focusPlay());
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error.toString();
        _loading = false;
      });
    }
  }

  List<MediaItem> get _episodes {
    final all = _detail?.episodes ?? const <MediaItem>[];
    if (_seasonId == null) return all;
    return all
        .where((episode) => episode.seasonId == _seasonId)
        .toList(growable: false);
  }

  List<MediaItem> get _playables {
    final episodes = _episodes;
    if (episodes.isNotEmpty) return episodes;
    final all = _detail?.episodes ?? const <MediaItem>[];
    return all.isNotEmpty ? all : [_item];
  }

  MediaItem get _playTarget {
    final initial = _initialEpisodeId;
    if (initial != null) {
      for (final item in _playables) {
        if (item.id == initial) return item;
      }
    }
    return _playables.first;
  }

  void _play(MediaItem item, {int? index}) {
    final playables = _playables;
    final selected = index ?? playables.indexWhere((e) => e.id == item.id);
    final safeIndex = selected < 0 ? 0 : selected;
    final episodes = [
      for (final media in playables)
        Episode(
          name: media.subtitle.isEmpty ? media.name : media.name,
          url: widget.store.api.streamUrl(widget.account, media),
        ),
    ];
    final initialPosition = Duration(
      microseconds: playables[safeIndex].positionTicks ~/ 10,
    );
    Navigator.of(context)
        .push(
          MaterialPageRoute(
            builder: (_) => PlayerPage(
              title: _item.name,
              episodes: episodes,
              initialIndex: safeIndex,
              initialPosition: initialPosition,
              sourceName: widget.account.serverName,
              onOpened: (current) {
                unawaited(
                  widget.store.api
                      .reportStart(
                        widget.account,
                        playables[current],
                        Duration(
                          microseconds: playables[current].positionTicks ~/ 10,
                        ),
                      )
                      .catchError((_) {}),
                );
              },
              onProgress: (current, position, duration, paused) {
                unawaited(
                  widget.store.api
                      .reportProgress(
                        widget.account,
                        playables[current],
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
                      .reportStopped(
                        widget.account,
                        playables[current],
                        position,
                      )
                      .catchError((_) {}),
                );
              },
            ),
          ),
        )
        .then((_) => _load());
  }

  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.sizeOf(context).width >= 900;
    final tv = TvMode.of(context).isTv;
    final horizontal = tv ? 56.0 : (wide ? 40.0 : 20.0);
    final detail = _detail;
    final backdropUrl = _item.imageUrl(
      widget.account,
      maxHeight: 900,
      backdrop: true,
    );
    final posterUrl = _item.imageUrl(widget.account, maxHeight: 650);
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: MoonBackdrop(
        child: CustomScrollView(
          physics: const BouncingScrollPhysics(),
          slivers: [
            SliverAppBar(
              pinned: true,
              stretch: true,
              expandedHeight: tv ? 360 : (wide ? 420 : 320),
              backgroundColor: MoonColors.background,
              surfaceTintColor: Colors.transparent,
              systemOverlayStyle: SystemUiOverlayStyle.light,
              leadingWidth: 66,
              leading: Padding(
                padding: const EdgeInsets.only(left: 14),
                child: _RoundButton(
                  icon: Icons.arrow_back_rounded,
                  focusable: !tv,
                  onTap: () => Navigator.of(context).pop(),
                ),
              ),
              actions: [
                if (_loading)
                  const Padding(
                    padding: EdgeInsets.only(right: 20),
                    child: Center(
                      child: SizedBox(
                        width: 17,
                        height: 17,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    ),
                  )
                else
                  Padding(
                    padding: const EdgeInsets.only(right: 18),
                    child: _RoundButton(
                      icon: Icons.refresh_rounded,
                      focusable: !tv,
                      onTap: _load,
                    ),
                  ),
              ],
              flexibleSpace: FlexibleSpaceBar(
                background: Stack(
                  fit: StackFit.expand,
                  children: [
                    ImageBackdrop(
                      url: backdropUrl.isNotEmpty ? backdropUrl : posterUrl,
                    ),
                    const DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Color(0x88060A13),
                            Color(0x33060A13),
                            Color(0xFF060A13),
                          ],
                          stops: [0, 0.45, 1],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.fromLTRB(horizontal, 8, horizontal, 0),
                child: _buildHero(posterUrl),
              ),
            ),
            if (_error != null)
              SliverPadding(
                padding: EdgeInsets.fromLTRB(horizontal, 16, horizontal, 0),
                sliver: SliverToBoxAdapter(
                  child: ErrorPanel(message: _error!, onRetry: _load),
                ),
              ),
            if (detail != null && detail.seasons.isNotEmpty)
              SliverPadding(
                padding: EdgeInsets.fromLTRB(horizontal, 22, horizontal, 0),
                sliver: SliverToBoxAdapter(child: _buildSeasons(detail)),
              ),
            if (detail != null && detail.episodes.isNotEmpty)
              SliverPadding(
                padding: EdgeInsets.fromLTRB(horizontal, 18, horizontal, 0),
                sliver: SliverToBoxAdapter(child: _buildEpisodesHeader()),
              ),
            if (detail != null && detail.episodes.isNotEmpty)
              SliverPadding(
                padding: EdgeInsets.fromLTRB(horizontal, 10, horizontal, 30),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) => _EpisodeTile(
                      item: _episodes[index],
                      index: index,
                      onTap: () => _play(_episodes[index], index: index),
                    ),
                    childCount: _episodes.length,
                  ),
                ),
              ),
            const SliverToBoxAdapter(child: SizedBox(height: 40)),
          ],
        ),
      ),
    );
  }

  Widget _buildHero(String posterUrl) {
    final wide = MediaQuery.sizeOf(context).width >= 900;
    final metadata = <String>[
      if (_item.productionYear != null) '${_item.productionYear}',
      if (_item.officialRating.isNotEmpty) _item.officialRating,
      if (_item.runtimeMinutes != null) '${_item.runtimeMinutes} 分钟',
      if (_item.genres.isNotEmpty) _item.genres.take(3).join(' / '),
    ];
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        if (wide)
          ClipRRect(
            borderRadius: BorderRadius.circular(14),
            child: SizedBox(width: 190, height: 285, child: _poster(posterUrl)),
          ),
        if (wide) const SizedBox(width: 24),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  AccentPill(
                    label: widget.account.type.label,
                    icon: Icons.dns_outlined,
                  ),
                  const SizedBox(width: 8),
                  if (_item.isSeries)
                    const AccentPill(label: '剧集', color: MoonColors.violet)
                  else
                    const AccentPill(label: '电影', color: MoonColors.gold),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                _item.name,
                style: Theme.of(context).textTheme.displayMedium
                    ?.copyWith(fontSize: wide ? 40 : 30),
              ),
              if (metadata.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(
                  metadata.join(' · '),
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ],
              if (_item.overview.isNotEmpty) ...[
                const SizedBox(height: 14),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 740),
                  child: Text(
                    _item.overview,
                    maxLines: 5,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodyMedium
                        ?.copyWith(height: 1.6),
                  ),
                ),
              ],
              const SizedBox(height: 20),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  KeyedSubtree(
                    key: _playKey,
                    child: FilledButton.icon(
                      focusNode: _playFocus,
                      onPressed: _loading ? null : () => _play(_playTarget),
                      icon: const Icon(Icons.play_arrow_rounded, size: 21),
                      label: Text(
                        _item.isSeries
                            ? (_playTarget.hasProgress ? '继续观看' : '播放第一集')
                            : '立即播放',
                      ),
                    ),
                  ),
                  if (_item.isSeries && _detail != null)
                    AccentPill(
                      label: '${_detail!.episodes.length} 集',
                      icon: Icons.playlist_play_rounded,
                      filled: true,
                    ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _poster(String url) {
    if (url.isEmpty) {
      return const DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF1A2B45), Color(0xFF0C1524)],
          ),
        ),
        child: Icon(
          Icons.movie_filter_outlined,
          color: MoonColors.faint,
          size: 44,
        ),
      );
    }
    return CachedNetworkImage(
      imageUrl: url,
      fit: BoxFit.cover,
      placeholder: (_, _) => const ColoredBox(color: MoonColors.surface),
      errorWidget: (_, _, _) => const ColoredBox(
        color: MoonColors.surface,
        child: Icon(Icons.movie_filter_outlined, color: MoonColors.faint),
      ),
    );
  }

  Widget _buildSeasons(MediaDetailData detail) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final season in detail.seasons)
          _SeasonChip(
            label: season.name,
            selected: season.id == _seasonId,
            onTap: () => setState(() => _seasonId = season.id),
          ),
      ],
    );
  }

  Widget _buildEpisodesHeader() {
    return SectionHeader(
      title: '选集',
      subtitle: _seasonId == null
          ? '选择一集开始播放'
          : '${_episodes.length} 集 · 进度会自动同步',
      trailing: AccentPill(label: '${_episodes.length} 集'),
    );
  }
}

class _EpisodeTile extends StatefulWidget {
  const _EpisodeTile({
    required this.item,
    required this.index,
    required this.onTap,
  });

  final MediaItem item;
  final int index;
  final VoidCallback onTap;

  @override
  State<_EpisodeTile> createState() => _EpisodeTileState();
}

class _EpisodeTileState extends State<_EpisodeTile> {
  bool _focused = false;

  @override
  Widget build(BuildContext context) {
    final item = widget.item;
    return Padding(
      padding: const EdgeInsets.only(bottom: 7),
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
        child: Material(
          color: _focused
              ? MoonColors.accent.withValues(alpha: 0.1)
              : Colors.white.withValues(alpha: 0.035),
          borderRadius: BorderRadius.circular(12),
          child: InkWell(
            canRequestFocus: false,
            onTap: widget.onTap,
            borderRadius: BorderRadius.circular(12),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 11),
              child: Row(
                children: [
                  SizedBox(
                    width: 38,
                    child: Text(
                      item.indexNumber?.toString().padLeft(2, '0') ??
                          '${widget.index + 1}'.padLeft(2, '0'),
                      style: const TextStyle(
                        color: MoonColors.accent,
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: MoonColors.text,
                            fontSize: 12.5,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        if (item.overview.isNotEmpty) ...[
                          const SizedBox(height: 3),
                          Text(
                            item.overview,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: MoonColors.faint,
                              fontSize: 10.5,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  if (item.hasProgress)
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: Text(
                        '${(item.progressFraction * 100).round()}%',
                        style: const TextStyle(
                          color: MoonColors.accent,
                          fontSize: 10.5,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  const Icon(
                    Icons.play_circle_outline_rounded,
                    color: MoonColors.muted,
                    size: 21,
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

class _SeasonChip extends StatefulWidget {
  const _SeasonChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  State<_SeasonChip> createState() => _SeasonChipState();
}

class _SeasonChipState extends State<_SeasonChip> {
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
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 140),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
          decoration: BoxDecoration(
            color: widget.selected || _focused
                ? MoonColors.accent.withValues(alpha: 0.15)
                : Colors.white.withValues(alpha: 0.035),
            borderRadius: BorderRadius.circular(30),
            border: Border.all(
              color: widget.selected || _focused
                  ? MoonColors.accent.withValues(alpha: 0.5)
                  : Colors.white.withValues(alpha: 0.07),
            ),
          ),
          child: Text(
            widget.label,
            style: TextStyle(
              color: widget.selected || _focused
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

class _RoundButton extends StatelessWidget {
  const _RoundButton({
    required this.icon,
    required this.onTap,
    this.focusable = true,
  });

  final IconData icon;
  final VoidCallback onTap;
  final bool focusable;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.black.withValues(alpha: 0.32),
      shape: const CircleBorder(),
      child: InkWell(
        canRequestFocus: focusable,
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: Padding(
          padding: const EdgeInsets.all(9),
          child: Icon(icon, color: Colors.white, size: 21),
        ),
      ),
    );
  }
}
