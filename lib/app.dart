import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sanchita/core/navigation/app_router.dart';
import 'package:sanchita/core/providers/update_check_provider.dart';
import 'package:sanchita/core/theme/app_design_tokens.dart';
import 'package:sanchita/core/theme/app_theme.dart';
import 'package:sanchita/features/auth/providers/session_provider.dart';
import 'package:sanchita/features/settings/providers/settings_provider.dart';
import 'package:sanchita/features/vault/providers/vault_session_provider.dart';
import 'package:sanchita/shared/widgets/app_logo.dart';

class SanchitaApp extends ConsumerStatefulWidget {
  const SanchitaApp({super.key});

  @override
  ConsumerState<SanchitaApp> createState() => _SanchitaAppState();
}

class _SanchitaAppState extends ConsumerState<SanchitaApp> {
  late final AppLifecycleListener _lifecycleListener;
  Timer? _autoLockTimer;
  DateTime? _backgroundedAt;
  ProviderSubscription<int?>? _autoLockSettingsSubscription;
  ProviderSubscription<bool?>? _authStateSubscription;

  @override
  void initState() {
    super.initState();
    _lifecycleListener = AppLifecycleListener(
      onPause: _onAppBackgrounded,
      onHide: _onAppBackgrounded,
      onDetach: _lockSessionsAndCancelTimer,
      onResume: _onAppResumed,
    );
    _scheduleAutoLockTimer();
    ref.read(updateCheckProvider);
    _autoLockSettingsSubscription = ref.listenManual(
      settingsProvider.select((s) => s.asData?.value.autoLockSeconds),
      (_, __) => _scheduleAutoLockTimer(),
    );
    _authStateSubscription = ref.listenManual(
      sessionProvider.select((s) => s.asData?.value.authenticated),
      (_, isAuthenticated) {
        if (isAuthenticated == true) {
          // Fresh login/unlock: reset timer baseline to avoid stale timer firing.
          _backgroundedAt = null;
          _scheduleAutoLockTimer();
          return;
        }

        // Logged out / re-locked: ensure no timer keeps running in background.
        _autoLockTimer?.cancel();
        _autoLockTimer = null;
      },
    );
  }

  @override
  void dispose() {
    _autoLockTimer?.cancel();
    _autoLockSettingsSubscription?.close();
    _authStateSubscription?.close();
    _lifecycleListener.dispose();
    super.dispose();
  }

  void _lockSessionsAndCancelTimer() {
    _autoLockTimer?.cancel();
    _autoLockTimer = null;
    ref.read(sessionProvider.notifier).lockForReauth();
    ref.read(vaultSessionProvider.notifier).lock();
  }

  void _scheduleAutoLockTimer() {
    _autoLockTimer?.cancel();
    _autoLockTimer = null;

    final settings = ref.read(settingsProvider).asData?.value;
    if (settings == null) {
      return;
    }

    final autoLockSeconds = settings.autoLockSeconds;
    if (autoLockSeconds <= 0) {
      return;
    }

    _autoLockTimer = Timer(Duration(seconds: autoLockSeconds), () {
      ref.read(sessionProvider.notifier).lockForReauth();
      ref.read(vaultSessionProvider.notifier).lock();
    });
  }

  void _onAppBackgrounded() {
    _backgroundedAt = DateTime.now();
    _autoLockTimer?.cancel();
    _autoLockTimer = null;
  }

  void _onAppResumed() {
    final backgroundedAt = _backgroundedAt;
    _backgroundedAt = null;

    if (backgroundedAt == null) {
      _scheduleAutoLockTimer();
      return;
    }

    final settings = ref.read(settingsProvider).asData?.value;
    final autoLockSeconds = settings?.autoLockSeconds ?? 300;
    if (autoLockSeconds <= 0) {
      return;
    }

    final elapsed = DateTime.now().difference(backgroundedAt).inSeconds;
    if (elapsed >= autoLockSeconds) {
      _lockSessionsAndCancelTimer();
    } else {
      _autoLockTimer?.cancel();
      _autoLockTimer = Timer(
        Duration(seconds: autoLockSeconds - elapsed),
        () {
          ref.read(sessionProvider.notifier).lockForReauth();
          ref.read(vaultSessionProvider.notifier).lock();
        },
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final sessionState = ref.watch(sessionProvider);
    final router = ref.watch(appRouterProvider);
    final theme = ref.watch(
      settingsProvider.select((s) => s.asData?.value.theme),
    );

    // Block router initialization until session is fully loaded to prevent
    // showing stale routes before redirect logic can fire
    if (sessionState.isLoading) {
      return GestureDetector(
        behavior: HitTestBehavior.translucent,
        onTap: _scheduleAutoLockTimer,
        onPanDown: (_) => _scheduleAutoLockTimer(),
        child: MaterialApp(
          title: 'Sanchita',
          theme: AppTheme.lightTheme,
          darkTheme: AppTheme.darkTheme,
          themeMode: ThemeMode.system,
          home: const _LoadingScreen(),
          debugShowCheckedModeBanner: false,
        ),
      );
    }

    final themeMode = switch (theme) {
      'light' => ThemeMode.light,
      'dark' => ThemeMode.dark,
      _ => ThemeMode.system,
    };
    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onTap: _scheduleAutoLockTimer,
      onPanDown: (_) => _scheduleAutoLockTimer(),
      child: MaterialApp.router(
        title: 'Sanchita',
        theme: AppTheme.lightTheme,
        darkTheme: AppTheme.darkTheme,
        themeMode: themeMode,
        routerConfig: router,
        debugShowCheckedModeBanner: false,
      ),
    );
  }
}

class _LoadingScreen extends StatelessWidget {
  const _LoadingScreen();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: AppTokens.goldGradient,
        ),
        child: SafeArea(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              const AppLogo(size: AppTokens.iconSplash),
              const SizedBox(height: AppTokens.space16),
              Text(
                'Sanchita',
                style: Theme.of(context).textTheme.displaySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onPrimary,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.2,
                ),
              ),
              const SizedBox(height: AppTokens.space8),
              Text(
                'Your private finance & document vault',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onPrimary.withValues(alpha: 0.7),
                ),
              ),
              const SizedBox(height: AppTokens.space48),
              CircularProgressIndicator(
                color: Theme.of(context).colorScheme.onPrimary,
                strokeWidth: 2.5,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
