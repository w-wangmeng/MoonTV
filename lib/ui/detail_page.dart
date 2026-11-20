import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models.dart';
import '../store/app_store.dart';
import '../tv_mode.dart';
import 'player_page.dart';
import 'theme.dart';
import 'tv_focus.dart';

class DetailPage extends StatefulWidget {
  const DetailPage({
    super.key,
    required this.store,
    required this.site,
    required this.initialItem,
  });

  final AppStore store;
  final SourceSite site;
  final VodItem initialItem;

  @override
  State<DetailPage> createState() => _DetailPageState();
}

class _DetailPageState extends State<DetailPage> {
  late VodItem _item;
  final _playFocus = FocusNode(debugLabel: 'detail-play');
  final _playKey = GlobalKey();
  bool _loading = true;
  String? _error;
  int _groupIndex = 0;

  @override
  void initState() {
    super.initState();
    _item = widget.initialItem;
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
    // The route's FocusScope claims the first focusable widget (the back
    // button) during the push transition. Wait until that settles, then put
    // the remote on the primary action.
    Future<void>.delayed(const Duration(milliseconds: 420), () {
      if (mounted && TvMode.of(context).isTv) _playFocus.requestFocus();
    });
  }

  void _revealPlay() {
    if (!_playFocus.hasFocus) return;
    final target = _playKey.currentContext;
    if (target != null) {
      ensureTvFocusVisible(target, alignment: 0.82);
    }
  }

  Future<void> _load() async {
    if (_item.id.isEmpty) {
      setState(() => _loading = false);
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      var detail = await widget.store.api.fetchDetail(widget.site, _item.id);
      if (detail.groups.isEmpty && _item.groups.isNotEmpty) {
        detail = detail.copyWith(groups: _item.groups);
      }
      if (detail.pic.isEmpty) {
        detail = VodItem(
          id: detail.id,
          name: detail.name,
          pic: _item.pic,
          remarks: detail.remarks,
          year: detail.year,
          area: detail.area,
          typeId: detail.typeId,
          typeName: detail.typeName,
          actor: detail.actor,
          director: detail.director,
          content: detail.content.isEmpty ? _item.content : detail.content,
          groups: detail.groups,
        );
      }
      if (!mounted) return;
      setState(() {
        _item = detail;
        _loading = false;
        _groupIndex = 0;
      });
      WidgetsBinding.instance.addPostFrameCallback((_) => _focusPlay());
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = '详情接口没有响应，正在使用列表信息。\n$error';
      });
    }
  }

  Future<void> _play(Episode episode, int index, List<Episode> episodes) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => PlayerPage(
          title: _item.name,
          episodes: episodes,
          initialIndex: index,
          sourceName: widget.site.displayName,
          referer: widget.site.detail.isNotEmpty
              ? widget.site.detail
              : 'https://${widget.site.host}/',
        ),
      ),
    );
    if (!mounted) return;
    _focusPlay();
  }

  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.sizeOf(context).width >= 900;
    final tv = TvMode.of(context).isTv;
    final horizontal = tv ? 56.0 : (wide ? 40.0 : 20.0);
    final currentGroup = _item.groups.isEmpty
        ? null
        : _item.groups[_groupIndex.clamp(0, _item.groups.length - 1)];
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: MoonBackdrop(
        child: CustomScrollView(
          physics: const BouncingScrollPhysics(),
          slivers: [
            SliverAppBar(
              pinned: true,
              stretch: true,
              expandedHeight: tv ? 360 : (wide ? 430 : 330),
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
                    ImageBackdrop(url: _item.pic),
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
                child: _buildHeroInfo(context, wide),
              ),
            ),
            if (_error != null)
              SliverPadding(
                padding: EdgeInsets.fromLTRB(horizontal, 16, horizontal, 0),
                sliver: SliverToBoxAdapter(
                  child: ErrorPanel(message: _error!, onRetry: _load),
                ),
              ),
            if (_item.content.isNotEmpty)
              SliverPadding(
                padding: EdgeInsets.fromLTRB(horizontal, 22, horizontal, 0),
                sliver: SliverToBoxAdapter(
                  child: GlassCard(
                    padding: const EdgeInsets.all(18),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Eyebrow('STORY'),
                        const SizedBox(height: 8),
                        Text(
                          _item.content,
                          style: Theme.of(context).textTheme.bodyMedium
                              ?.copyWith(height: 1.65, color: MoonColors.muted),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            SliverPadding(
              padding: EdgeInsets.fromLTRB(horizontal, 24, horizontal, 0),
              sliver: SliverToBoxAdapter(
                child: _buildEpisodesHeader(context, currentGroup),
              ),
            ),
            SliverPadding(
              padding: EdgeInsets.fromLTRB(horizontal, 14, horizontal, 0),
              sliver: SliverToBoxAdapter(child: _buildEpisodes(currentGroup)),
            ),
            const SliverToBoxAdapter(child: SizedBox(height: 50)),
          ],
        ),
      ),
    );
  }

  Widget _buildHeroInfo(BuildContext context, bool wide) {
    final tv = TvMode.of(context).isTv;
    final poster = ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: Container(
        width: wide ? 178 : 118,
        height: wide ? 264 : 176,
        decoration: BoxDecoration(
          color: MoonColors.surface2,
          border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.35),
              blurRadius: 28,
              offset: const Offset(0, 12),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(15),
          child: _item.pic.isEmpty
              ? const _PosterPlaceholder()
              : CachedNetworkImage(
                  imageUrl: _item.pic,
                  fit: BoxFit.cover,
                  placeholder: (_, _) => const _PosterPlaceholder(),
                  errorWidget: (_, _, _) => const _PosterPlaceholder(),
                ),
        ),
      ),
    );

    final info = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 7,
          runSpacing: 7,
          children: [
            AccentPill(
              label: widget.site.displayName,
              icon: Icons.dns_outlined,
              filled: true,
            ),
            if (_item.typeName.isNotEmpty) AccentPill(label: _item.typeName),
            if (_item.year.isNotEmpty) AccentPill(label: _item.year),
            if (_item.area.isNotEmpty) AccentPill(label: _item.area),
            if (_item.remarks.isNotEmpty)
              AccentPill(label: _item.remarks, color: MoonColors.gold),
          ],
        ),
        const SizedBox(height: 14),
        Text(
          _item.name,
          style: Theme.of(context).textTheme.displayMedium
              ?.copyWith(fontSize: tv ? 46 : (wide ? 40 : 26), height: 1.1),
        ),
        if (_item.actor.isNotEmpty) ...[
          const SizedBox(height: 9),
          _MetaLine(label: '主演', value: _item.actor),
        ],
        if (_item.director.isNotEmpty) ...[
          const SizedBox(height: 4),
          _MetaLine(label: '导演', value: _item.director),
        ],
        const SizedBox(height: 18),
        Row(
          children: [
            KeyedSubtree(
              key: _playKey,
              child: FilledButton.icon(
                focusNode: _playFocus,
                onPressed: _item.firstEpisode == null
                    ? null
                    : () {
                        final group = _item.groups.firstWhere(
                          (group) => group.episodes.any((ep) => ep.isPlayable),
                          orElse: () => _item.groups.first,
                        );
                        final index = group.episodes.indexWhere(
                          (ep) => ep.isPlayable,
                        );
                        _play(
                          group.episodes[index.clamp(
                            0,
                            group.episodes.length - 1,
                          )],
                          index.clamp(0, group.episodes.length - 1),
                          group.episodes,
                        );
                      },
                icon: const Icon(Icons.play_arrow_rounded, size: 22),
                label: const Text('立即播放'),
              ),
            ),
            const SizedBox(width: 10),
            OutlinedButton.icon(
              onPressed: () => _showSourceInfo(context),
              icon: const Icon(Icons.info_outline_rounded, size: 17),
              label: const Text('源信息'),
            ),
          ],
        ),
      ],
    );

    if (!wide) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              poster,
              const SizedBox(width: 15),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _item.name,
                      style: Theme.of(context).textTheme.headlineMedium
                          ?.copyWith(fontSize: 21),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        if (_item.year.isNotEmpty)
                          AccentPill(label: _item.year),
                        if (_item.typeName.isNotEmpty)
                          AccentPill(label: _item.typeName),
                      ],
                    ),
                    const SizedBox(height: 10),
                    if (_item.remarks.isNotEmpty)
                      Text(
                        _item.remarks,
                        style: const TextStyle(
                          color: MoonColors.gold,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: KeyedSubtree(
              key: _playKey,
              child: FilledButton.icon(
                focusNode: _playFocus,
                onPressed: _item.firstEpisode == null
                    ? null
                    : () {
                        final group = _item.groups.firstWhere(
                          (group) => group.episodes.any((ep) => ep.isPlayable),
                          orElse: () => _item.groups.first,
                        );
                        final index = group.episodes.indexWhere(
                          (ep) => ep.isPlayable,
                        );
                        _play(
                          group.episodes[index.clamp(
                            0,
                            group.episodes.length - 1,
                          )],
                          index.clamp(0, group.episodes.length - 1),
                          group.episodes,
                        );
                      },
                icon: const Icon(Icons.play_arrow_rounded, size: 21),
                label: const Text('立即播放'),
              ),
            ),
          ),
          if (_item.actor.isNotEmpty) ...[
            const SizedBox(height: 13),
            _MetaLine(label: '主演', value: _item.actor),
          ],
        ],
      );
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        poster,
        const SizedBox(width: 24),
        Expanded(child: info),
      ],
    );
  }

  Widget _buildEpisodesHeader(BuildContext context, PlayGroup? group) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text('选集', style: Theme.of(context).textTheme.titleLarge),
            if (group != null) ...[
              const SizedBox(width: 9),
              AccentPill(label: '${group.episodes.length} 集'),
            ],
          ],
        ),
        if (_item.groups.length > 1) ...[
          const SizedBox(height: 11),
          SizedBox(
            height: 34,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: _item.groups.length,
              separatorBuilder: (_, _) => const SizedBox(width: 8),
              itemBuilder: (context, index) {
                final selected = index == _groupIndex;
                return _GroupChip(
                  label: _item.groups[index].name,
                  selected: selected,
                  onTap: () => setState(() => _groupIndex = index),
                );
              },
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildEpisodes(PlayGroup? group) {
    if (group == null || group.episodes.isEmpty) {
      return GlassCard(
        padding: const EdgeInsets.all(20),
        child: Row(
          children: [
            const Icon(
              Icons.info_outline_rounded,
              color: MoonColors.gold,
              size: 18,
            ),
            const SizedBox(width: 9),
            Expanded(
              child: Text(
                '这个源没有返回播放地址。可以回到列表换一个源，或在「站源」里切换。',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
          ],
        ),
      );
    }
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (var i = 0; i < group.episodes.length; i++)
          _EpisodeChip(
            label: group.episodes[i].name,
            disabled: !group.episodes[i].isPlayable,
            onTap: () => _play(group.episodes[i], i, group.episodes),
          ),
      ],
    );
  }

  void _showSourceInfo(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('源信息'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _DialogLine(label: '站源', value: widget.site.displayName),
            const SizedBox(height: 8),
            _DialogLine(label: '接口', value: widget.site.api),
            const SizedBox(height: 8),
            _DialogLine(
              label: '格式',
              value: widget.site.type == 0 ? 'XML' : 'JSON',
            ),
            const SizedBox(height: 8),
            _DialogLine(label: '详情页', value: widget.site.detail),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('知道了'),
          ),
        ],
      ),
    );
  }
}

class _GroupChip extends StatefulWidget {
  const _GroupChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  State<_GroupChip> createState() => _GroupChipState();
}

class _GroupChipState extends State<_GroupChip> {
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
          padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 7),
          decoration: BoxDecoration(
            color: widget.selected
                ? MoonColors.accent.withValues(alpha: 0.16)
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
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ),
    );
  }
}

class _EpisodeChip extends StatefulWidget {
  const _EpisodeChip({
    required this.label,
    required this.onTap,
    this.disabled = false,
  });

  final String label;
  final VoidCallback onTap;
  final bool disabled;

  @override
  State<_EpisodeChip> createState() => _EpisodeChipState();
}

class _EpisodeChipState extends State<_EpisodeChip> {
  bool _focused = false;

  @override
  Widget build(BuildContext context) {
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
            if (!widget.disabled) widget.onTap();
            return null;
          },
        ),
      },
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          canRequestFocus: false,
          onTap: widget.disabled ? null : widget.onTap,
          borderRadius: BorderRadius.circular(10),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 130),
            constraints: const BoxConstraints(minWidth: 68),
            padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 10),
            decoration: BoxDecoration(
              color: _focused
                  ? MoonColors.accent.withValues(alpha: 0.14)
                  : Colors.white.withValues(alpha: 0.035),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: _focused
                    ? MoonColors.accentStrong
                    : Colors.white.withValues(alpha: 0.07),
                width: _focused ? 2 : 1,
              ),
            ),
            child: Text(
              widget.label,
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: widget.disabled
                    ? MoonColors.faint
                    : _focused
                    ? MoonColors.accentStrong
                    : MoonColors.text,
                fontSize: 11.5,
                fontWeight: FontWeight.w600,
              ),
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
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(9),
          child: Icon(icon, color: Colors.white, size: 20),
        ),
      ),
    );
  }
}

class _PosterPlaceholder extends StatelessWidget {
  const _PosterPlaceholder();

  @override
  Widget build(BuildContext context) {
    return const DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF1A2B45), Color(0xFF0C1524)],
        ),
      ),
      child: Center(
        child: Icon(
          Icons.movie_filter_outlined,
          color: Colors.white24,
          size: 34,
        ),
      ),
    );
  }
}

class _MetaLine extends StatelessWidget {
  const _MetaLine({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Text.rich(
      TextSpan(
        children: [
          TextSpan(
            text: '$label  ',
            style: const TextStyle(
              color: MoonColors.faint,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
          TextSpan(
            text: value,
            style: const TextStyle(
              color: MoonColors.muted,
              fontSize: 11.5,
              height: 1.5,
            ),
          ),
        ],
      ),
      maxLines: 2,
      overflow: TextOverflow.ellipsis,
    );
  }
}

class _DialogLine extends StatelessWidget {
  const _DialogLine({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 50,
          child: Text(
            label,
            style: const TextStyle(color: MoonColors.faint, fontSize: 11),
          ),
        ),
        Expanded(
          child: SelectableText(
            value.isEmpty ? '—' : value,
            style: const TextStyle(
              color: MoonColors.text,
              fontSize: 11.5,
              height: 1.45,
            ),
          ),
        ),
      ],
    );
  }
}
