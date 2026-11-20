import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../store/app_store.dart';
import 'theme.dart';

class OnboardingPage extends StatefulWidget {
  const OnboardingPage({super.key, required this.store});

  final AppStore store;

  @override
  State<OnboardingPage> createState() => _OnboardingPageState();
}

class _OnboardingPageState extends State<OnboardingPage> {
  final _controller = TextEditingController();
  final _focusNode = FocusNode();
  bool _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _focusNode.requestFocus();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  Future<void> _connect() async {
    final url = _controller.text.trim();
    if (url.isEmpty) {
      setState(() => _error = '先粘贴一个配置地址');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final result = await widget.store.addConfig(url);
      if (!mounted) return;
      final warning = result.warnings.isEmpty
          ? ''
          : '（${result.warnings.first}）';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('已连接 ${result.sites.length} 个点播源 $warning')),
      );
    } catch (error) {
      if (!mounted) return;
      setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _useExample(String value) {
    _controller.text = value;
    _controller.selection = TextSelection.fromPosition(
      TextPosition(offset: _controller.text.length),
    );
    setState(() => _error = null);
    _focusNode.requestFocus();
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final wide = width >= 980;
    return Scaffold(
      body: MoonBackdrop(
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(28, 26, 28, 34),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1180),
                child: wide
                    ? Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          const Expanded(flex: 11, child: _Intro()),
                          const SizedBox(width: 70),
                          Expanded(flex: 9, child: _buildConnectCard()),
                        ],
                      )
                    : Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const _Intro(compact: true),
                          const SizedBox(height: 34),
                          _buildConnectCard(),
                        ],
                      ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildConnectCard() {
    return GlassCard(
      padding: const EdgeInsets.fromLTRB(26, 26, 26, 24),
      radius: 26,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: MoonColors.accent.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: MoonColors.accent.withValues(alpha: 0.25),
                  ),
                ),
                child: const Icon(
                  Icons.link_rounded,
                  color: MoonColors.accent,
                  size: 20,
                ),
              ),
              const SizedBox(width: 13),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '连接你的内容源',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 3),
                    Text(
                      'MoonTV / LunaTV / TVBox 配置都可以',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
              const AccentPill(label: '第一步', icon: Icons.bolt_rounded),
            ],
          ),
          const SizedBox(height: 22),
          TextField(
            controller: _controller,
            focusNode: _focusNode,
            enabled: !_busy,
            keyboardType: TextInputType.url,
            textInputAction: TextInputAction.go,
            onSubmitted: (_) => _busy ? null : _connect(),
            style: const TextStyle(fontSize: 13.5),
            decoration: const InputDecoration(
              hintText: 'https://example.com/config.json',
              prefixIcon: Icon(
                Icons.public_rounded,
                size: 19,
                color: MoonColors.faint,
              ),
            ),
          ),
          const SizedBox(height: 11),
          Text(
            '支持 MoonTV/LunaTV 的 api_site、TVBox 的 sites，以及 Base58 编码订阅。',
            style: Theme.of(context).textTheme.bodySmall
                ?.copyWith(color: MoonColors.faint),
          ),
          if (_error != null) ...[
            const SizedBox(height: 14),
            _InlineError(message: _error!),
          ],
          const SizedBox(height: 18),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: _busy ? null : _connect,
              child: _busy
                  ? const SizedBox(
                      width: 19,
                      height: 19,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.2,
                        color: Color(0xFF03141D),
                      ),
                    )
                  : const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.arrow_forward_rounded, size: 18),
                        SizedBox(width: 8),
                        Text('开始使用'),
                      ],
                    ),
            ),
          ),
          const SizedBox(height: 21),
          Divider(color: Colors.white.withValues(alpha: 0.07), height: 1),
          const SizedBox(height: 18),
          Text(
            '快速填入示例',
            style: Theme.of(context).textTheme.labelMedium
                ?.copyWith(color: MoonColors.faint, letterSpacing: 0.8),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _ExampleChip(
                label: 'MoonTV / LunaTV',
                onTap: () => _useExample('https://你的域名/?format=0&source=full'),
              ),
              _ExampleChip(
                label: 'TVBox JSON',
                onTap: () => _useExample('https://你的域名/config.json'),
              ),
              _ExampleChip(
                label: 'Base58 订阅',
                onTap: () => _useExample('https://你的域名/subscription.txt'),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(
                Icons.lock_outline_rounded,
                size: 14,
                color: MoonColors.faint,
              ),
              const SizedBox(width: 7),
              Expanded(
                child: Text(
                  '配置只保存在本机。MoonTV 不内置、不托管任何影片，内容由你的第三方源提供。',
                  style: Theme.of(context).textTheme.bodySmall
                      ?.copyWith(fontSize: 10.5, height: 1.5),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Intro extends StatelessWidget {
  const _Intro({this.compact = false});

  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        const MoonLogo(size: 44),
        SizedBox(height: compact ? 28 : 52),
        const Eyebrow('A QUIET PLACE FOR EVERYTHING'),
        const SizedBox(height: 14),
        Text(
          '把所有片源，\n收进一个夜晚。',
          style: Theme.of(context).textTheme.displayLarge
              ?.copyWith(fontSize: compact ? 38 : 58, height: 1.02),
        ),
        const SizedBox(height: 20),
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 530),
          child: Text(
            'MoonTV 把你的 api_site、TVBox 与 Base58 订阅聚合成一套干净、专注的观影界面。'
            '不注册、不登录，粘贴配置就能开始。',
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
              color: MoonColors.muted,
              fontSize: compact ? 14 : 15.5,
              height: 1.7,
            ),
          ),
        ),
        SizedBox(height: compact ? 22 : 38),
        if (!compact) ...[
          const _Feature(
            icon: Icons.layers_outlined,
            title: '多源聚合',
            text: '一个界面管理所有 api_site 与 TVBox 站源。',
          ),
          const _Feature(
            icon: Icons.search_rounded,
            title: '全源搜索',
            text: '一次输入，在多个源里同时找片。',
          ),
          const _Feature(
            icon: Icons.play_circle_outline_rounded,
            title: '直接播放',
            text: 'm3u8 / HLS 原生播放，适配平板与电视。',
          ),
        ] else
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: const [
              AccentPill(label: '多源聚合', icon: Icons.layers_outlined),
              AccentPill(label: '全源搜索', icon: Icons.search_rounded),
              AccentPill(label: 'HLS 播放', icon: Icons.play_circle_outline),
            ],
          ),
      ],
    );
  }
}

class _Feature extends StatelessWidget {
  const _Feature({required this.icon, required this.title, required this.text});

  final IconData icon;
  final String title;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 18),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 35,
            height: 35,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.04),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.white.withValues(alpha: 0.07)),
            ),
            child: Icon(icon, size: 17, color: MoonColors.accent),
          ),
          const SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: Theme.of(context).textTheme.titleMedium
                      ?.copyWith(fontSize: 13.5),
                ),
                const SizedBox(height: 2),
                Text(text, style: Theme.of(context).textTheme.bodySmall),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ExampleChip extends StatelessWidget {
  const _ExampleChip({required this.label, required this.onTap});

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
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.035),
            borderRadius: BorderRadius.circular(30),
            border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
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

class _InlineError extends StatelessWidget {
  const _InlineError({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 11),
      decoration: BoxDecoration(
        color: MoonColors.danger.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(11),
        border: Border.all(color: MoonColors.danger.withValues(alpha: 0.2)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.error_outline_rounded,
            color: MoonColors.danger,
            size: 17,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(
                color: MoonColors.danger,
                fontSize: 11.5,
                height: 1.45,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
