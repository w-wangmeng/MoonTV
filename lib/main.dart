import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:media_kit/media_kit.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'media/media_store.dart';
import 'store/app_store.dart';
import 'tv_mode.dart';
import 'ui/app_shell.dart';
import 'ui/theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  MediaKit.ensureInitialized();
  LicenseRegistry.addLicense(() async* {
    final license = await rootBundle.loadString('assets/MOONFIN_LICENSE.txt');
    yield LicenseEntryWithLineBreaks(['Moonfin-Core'], license);
  });

  final preferences = await SharedPreferences.getInstance();
  final store = AppStore(preferences: preferences);
  final mediaStore = MediaStore(preferences: preferences);
  final tvMode = TvModeController(preferences);
  runApp(MoonTVApp(store: store, mediaStore: mediaStore, tvMode: tvMode));
  unawaited(store.init());
  unawaited(mediaStore.init());
  unawaited(tvMode.init());
}

class MoonTVApp extends StatelessWidget {
  const MoonTVApp({
    super.key,
    required this.store,
    required this.mediaStore,
    required this.tvMode,
  });

  final AppStore store;
  final MediaStore mediaStore;
  final TvModeController tvMode;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: tvMode,
      builder: (context, _) {
        return MaterialApp(
          title: 'MoonTV',
          debugShowCheckedModeBanner: false,
          theme: buildMoonTheme(tv: tvMode.isTv),
          themeMode: ThemeMode.dark,
          builder: (context, child) => TvModeScope(
            controller: tvMode,
            child: child ?? const SizedBox.shrink(),
          ),
          home: _RootGate(store: store, mediaStore: mediaStore),
        );
      },
    );
  }
}

class _RootGate extends StatelessWidget {
  const _RootGate({required this.store, required this.mediaStore});

  final AppStore store;
  final MediaStore mediaStore;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([store, mediaStore]),
      builder: (context, _) {
        if (!store.initialized || !mediaStore.initialized) {
          return const _LaunchScreen();
        }
        return AppShell(store: store, mediaStore: mediaStore);
      },
    );
  }
}

class _LaunchScreen extends StatelessWidget {
  const _LaunchScreen();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: MoonBackdrop(
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const MoonLogo(size: 52),
              const SizedBox(height: 26),
              SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(
                  strokeWidth: 2.2,
                  color: MoonColors.accent.withValues(alpha: 0.8),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
