import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import '../models.dart';
import '../tv_mode.dart';
import 'theme.dart';

class PlayerPage extends StatefulWidget {
  const PlayerPage({
    super.key,
    required this.title,
    required this.episodes,
    required this.initialIndex,
    this.sourceName = '',
    this.referer = '',
    this.initialPosition = Duration.zero,
    this.onOpened,
    this.onProgress,
    this.onStopped,
  });

  final String title;
  final List<Episode> episodes;
  final int initialIndex;
  final String sourceName;
  final String referer;
  final Duration initialPosition;
  final void Function(int index)? onOpened;
  final void Function(
    int index,
    Duration position,
    Duration duration,
    bool paused,
  )?
  onProgress;
  final void Function(int index, Duration position)? onStopped;

  @override
  State<PlayerPage> createState() => _PlayerPageState();
}

class _PlayerPageState extends State<PlayerPage> {
  late final Player _player;
  late final VideoController _controller;
  late int _index;
  bool _opening = true;
  String? _error;
  Timer? _hideTimer;
  Timer? _hintTimer;
  Timer? _progressTimer;
  final _tvFocus = FocusNode(debugLabel: 'player-tv');
  bool _uiVisible = true;
  bool _playing = false;
  String? _hint;
  Duration _lastPosition = Duration.zero;

  Episode get _episode => widget.episodes[_index];

  @override
  void initState() {
    super.initState();
    _index = widget.initialIndex.clamp(0, widget.episodes.length - 1).toInt();
    _player = Player();
    _controller = VideoController(_player);
    _enterFullscreen();
    _listen();
    _open(_index);
    _scheduleHide();
    _progressTimer = Timer.periodic(const Duration(seconds: 10), (_) {
      final callback = widget.onProgress;
      if (callback == null) return;
      callback(
        _index,
        _player.state.position,
        _player.state.duration,
        !_playing,
      );
    });
  }

  void _listen() {
    _player.stream.error.listen((message) {
      if (!mounted) return;
      setState(() {
        _error = message;
        _opening = false;
      });
    });
    _player.stream.completed.listen((completed) {
      if (!mounted || !completed) return;
      if (_index + 1 < widget.episodes.length) {
        _openAt(_index + 1);
      }
    });
    _player.stream.playing.listen((playing) {
      _playing = playing;
      if (!mounted) return;
      if (playing && _opening) setState(() => _opening = false);
    });
    _player.stream.position.listen((position) {
      _lastPosition = position;
    });
  }

  Future<void> _enterFullscreen() async {
    await SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    await SystemChrome.setPreferredOrientations(const [
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    await WakelockPlus.enable();
  }

  Future<void> _open(int index) async {
    final safeIndex = index.clamp(0, widget.episodes.length - 1).toInt();
    setState(() {
      _index = safeIndex;
      _opening = true;
      _error = null;
    });
    try {
      await _player.open(
        Media(
          widget.episodes[safeIndex].url,
          start: safeIndex == widget.initialIndex
              ? widget.initialPosition
              : Duration.zero,
          httpHeaders: {
            'User-Agent':
                'Mozilla/5.0 (Linux; Android 12) AppleWebKit/537.36 '
                '(KHTML, like Gecko) Chrome/120.0 Mobile Safari/537.36',
            if (widget.referer.isNotEmpty) 'Referer': widget.referer,
          },
        ),
        play: true,
      );
      widget.onOpened?.call(safeIndex);
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error.toString();
        _opening = false;
      });
    }
  }

  Future<void> _openAt(int index) async {
    if (index != _index) {
      widget.onStopped?.call(_index, _lastPosition);
    }
    await _open(index);
    _scheduleHide();
  }

  void _scheduleHide() {
    _hideTimer?.cancel();
    _hideTimer = Timer(const Duration(seconds: 4), () {
      if (!mounted) return;
      setState(() => _uiVisible = false);
    });
  }

  void _showUi() {
    if (!_uiVisible) setState(() => _uiVisible = true);
    _scheduleHide();
  }

  @override
  void dispose() {
    _hideTimer?.cancel();
    _hintTimer?.cancel();
    _progressTimer?.cancel();
    _tvFocus.dispose();
    widget.onStopped?.call(_index, _lastPosition);
    _player.dispose();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    SystemChrome.setPreferredOrientations(const [
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    WakelockPlus.disable();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tv = TvMode.of(context).isTv;
    return Scaffold(
      backgroundColor: Colors.black,
      body: Focus(
        focusNode: _tvFocus,
        autofocus: tv,
        onKeyEvent: tv ? _handleTvKey : null,
        child: Listener(
          behavior: HitTestBehavior.translucent,
          onPointerDown: (_) => _showUi(),
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: _showUi,
            child: Stack(
              fit: StackFit.expand,
              children: [
                Center(
                  child: Video(
                    controller: _controller,
                    controls: tv ? null : AdaptiveVideoControls,
                    fit: BoxFit.contain,
                  ),
                ),
                if (_opening && _error == null)
                  const IgnorePointer(
                    child: Center(
                      child: SizedBox(
                        width: 34,
                        height: 34,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.4,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                if (_error != null) _buildError(),
                AnimatedOpacity(
                  opacity: _uiVisible ? 1 : 0,
                  duration: const Duration(milliseconds: 220),
                  child: IgnorePointer(
                    ignoring: !_uiVisible,
                    child: _buildTopBar(context),
                  ),
                ),
                if (tv) ...[
                  if (_hint != null)
                    Center(
                      child: IgnorePointer(
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 22,
                            vertical: 13,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.66),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.14),
                            ),
                          ),
                          child: Text(
                            _hint!,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 20,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ),
                    ),
                  if (_uiVisible) _buildTvTimeline(),
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: 24,
                    child: IgnorePointer(
                      child: AnimatedOpacity(
                        opacity: _uiVisible ? 1 : 0,
                        duration: const Duration(milliseconds: 220),
                        child: Text(
                          'OK 播放/暂停   ← → 快进/快退 10 秒   菜单 选集',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.72),
                            fontSize: 12,
                            letterSpacing: 0.3,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  KeyEventResult _handleTvKey(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) {
      return KeyEventResult.ignored;
    }
    final key = event.logicalKey;
    if (key == LogicalKeyboardKey.select ||
        key == LogicalKeyboardKey.enter ||
        key == LogicalKeyboardKey.gameButtonA ||
        key == LogicalKeyboardKey.space ||
        key == LogicalKeyboardKey.mediaPlayPause) {
      _player.playOrPause();
      _showHint(_playing ? '暂停' : '播放');
      _showUi();
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.arrowLeft ||
        key == LogicalKeyboardKey.mediaRewind) {
      _seekBy(const Duration(seconds: -10));
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.arrowRight ||
        key == LogicalKeyboardKey.mediaFastForward) {
      _seekBy(const Duration(seconds: 10));
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.arrowUp ||
        key == LogicalKeyboardKey.arrowDown) {
      _showUi();
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.contextMenu) {
      _showPlaylist();
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.mediaTrackNext) {
      if (_index + 1 < widget.episodes.length) _openAt(_index + 1);
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.mediaTrackPrevious) {
      if (_index > 0) _openAt(_index - 1);
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  void _seekBy(Duration delta) {
    final position = _player.state.position;
    var target = position + delta;
    if (target < Duration.zero) target = Duration.zero;
    final duration = _player.state.duration;
    if (duration > Duration.zero && target > duration) target = duration;
    _player.seek(target);
    _showHint('${delta.isNegative ? '快退' : '快进'} ${delta.inSeconds.abs()} 秒');
  }

  void _showHint(String message) {
    _hintTimer?.cancel();
    setState(() => _hint = message);
    _hintTimer = Timer(const Duration(milliseconds: 1500), () {
      if (mounted) setState(() => _hint = null);
    });
  }

  Widget _buildTvTimeline() {
    return Positioned(
      left: 32,
      right: 32,
      bottom: 56,
      child: IgnorePointer(
        child: StreamBuilder<Duration>(
          stream: _player.stream.position,
          initialData: _player.state.position,
          builder: (context, snapshot) {
            final position = snapshot.data ?? Duration.zero;
            final duration = _player.state.duration;
            final value = duration.inMilliseconds <= 0
                ? 0.0
                : (position.inMilliseconds / duration.inMilliseconds).clamp(
                    0.0,
                    1.0,
                  );
            return Row(
              children: [
                Text(
                  _formatClock(position),
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.8),
                    fontSize: 12,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(2),
                    child: LinearProgressIndicator(
                      value: value,
                      minHeight: 3,
                      backgroundColor: Colors.white.withValues(alpha: 0.2),
                      valueColor: const AlwaysStoppedAnimation<Color>(
                        MoonColors.accentStrong,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  _formatClock(duration),
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.8),
                    fontSize: 12,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  String _formatClock(Duration value) {
    final total = value.inSeconds.clamp(0, 359999);
    final hours = total ~/ 3600;
    final minutes = (total % 3600) ~/ 60;
    final seconds = total % 60;
    final mm = minutes.toString().padLeft(2, '0');
    final ss = seconds.toString().padLeft(2, '0');
    return hours > 0 ? '$hours:$mm:$ss' : '$mm:$ss';
  }

  Widget _buildTopBar(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 8, 14, 34),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xCC000000), Color(0x00000000)],
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: Row(
          children: [
            _PlayerIconButton(
              icon: Icons.arrow_back_rounded,
              onTap: () => Navigator.of(context).pop(),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    widget.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${_episode.name}  ·  ${widget.sourceName}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white60,
                      fontSize: 10.5,
                    ),
                  ),
                ],
              ),
            ),
            if (_index > 0) ...[
              _PlayerIconButton(
                icon: Icons.skip_previous_rounded,
                onTap: () => _openAt(_index - 1),
              ),
              const SizedBox(width: 4),
            ],
            if (_index + 1 < widget.episodes.length) ...[
              _PlayerIconButton(
                icon: Icons.skip_next_rounded,
                onTap: () => _openAt(_index + 1),
              ),
              const SizedBox(width: 4),
            ],
            _PlayerIconButton(
              icon: Icons.playlist_play_rounded,
              onTap: _showPlaylist,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildError() {
    return Center(
      child: Container(
        constraints: const BoxConstraints(maxWidth: 440),
        margin: const EdgeInsets.all(24),
        padding: const EdgeInsets.all(22),
        decoration: BoxDecoration(
          color: const Color(0xEE101C31),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: MoonColors.danger.withValues(alpha: 0.3)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.error_outline_rounded,
              color: MoonColors.danger,
              size: 28,
            ),
            const SizedBox(height: 10),
            const Text(
              '无法播放这一集',
              style: TextStyle(
                color: Colors.white,
                fontSize: 15,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 7),
            Text(
              _error!,
              textAlign: TextAlign.center,
              maxLines: 4,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: MoonColors.muted,
                fontSize: 11,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 15),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                TextButton(
                  onPressed: () => _open(_index),
                  child: const Text('重试'),
                ),
                const SizedBox(width: 8),
                TextButton(onPressed: _showPlaylist, child: const Text('选集')),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showPlaylist() async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (context) => FractionallySizedBox(
        heightFactor: 0.72,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 4, 12, 10),
              child: Row(
                children: [
                  Text('选集', style: Theme.of(context).textTheme.titleLarge),
                  const SizedBox(width: 8),
                  AccentPill(label: '${widget.episodes.length} 集'),
                  const Spacer(),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close_rounded),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.fromLTRB(14, 0, 14, 24),
                itemCount: widget.episodes.length,
                itemBuilder: (context, index) {
                  final selected = index == _index;
                  return ListTile(
                    autofocus: selected && TvMode.of(context).isTv,
                    selected: selected,
                    selectedTileColor: MoonColors.accent.withValues(
                      alpha: 0.08,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(11),
                    ),
                    leading: Icon(
                      selected
                          ? Icons.play_circle_fill_rounded
                          : Icons.play_circle_outline_rounded,
                      color: selected ? MoonColors.accent : MoonColors.faint,
                      size: 21,
                    ),
                    title: Text(
                      widget.episodes[index].name,
                      style: TextStyle(
                        color: selected
                            ? MoonColors.accentStrong
                            : MoonColors.text,
                        fontSize: 12.5,
                      ),
                    ),
                    onTap: () {
                      Navigator.of(context).pop();
                      _openAt(index);
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
    if (mounted && TvMode.of(context).isTv) _tvFocus.requestFocus();
  }
}

class _PlayerIconButton extends StatelessWidget {
  const _PlayerIconButton({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.black.withValues(alpha: 0.3),
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(9),
          child: Icon(icon, color: Colors.white, size: 21),
        ),
      ),
    );
  }
}
