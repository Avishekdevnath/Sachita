import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sanchita/features/auth/providers/session_provider.dart';

/// Isolated timer widget that only rebuilds the clock/lockout display.
/// This prevents the entire PIN screen from rebuilding every second.
class PinScreenTimer extends ConsumerStatefulWidget {
  const PinScreenTimer({
    super.key,
    required this.child,
  });

  final Widget child;

  @override
  ConsumerState<PinScreenTimer> createState() => _PinScreenTimerState();
}

class _PinScreenTimerState extends ConsumerState<PinScreenTimer> {
  late Timer _clockTicker;
  bool _lockoutClearQueued = false;

  @override
  void initState() {
    super.initState();
    _startClockTimer();
  }

  void _startClockTimer() {
    _clockTicker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) {
        return;
      }

      final session = ref.read(sessionProvider).asData?.value;
      final lockedUntil = session?.lockedUntil;

      // Handle lockout expiry
      if (lockedUntil != null &&
          !lockedUntil.isAfter(DateTime.now()) &&
          !_lockoutClearQueued) {
        _lockoutClearQueued = true;
        WidgetsBinding.instance.addPostFrameCallback((_) async {
          if (!mounted) {
            return;
          }
          await ref.read(sessionProvider.notifier).clearLockoutIfExpired();
          if (mounted) {
            _lockoutClearQueued = false;
          }
        });
      }

      // Only rebuild the timer display, not the entire screen
      if (mounted) {
        setState(() {});
      }
    });
  }

  @override
  void dispose() {
    _clockTicker.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          // Isolated timer section - only this rebuilds every second
          const RepaintBoundary(
            child: _TimerDisplay(),
          ),
          // Pin screen content - NOT rebuilt by timer
          Expanded(
            child: RepaintBoundary(
              child: widget.child,
            ),
          ),
        ],
      ),
    );
  }
}

/// Tiny widget that only displays the current time and lockout countdown.
/// Using RepaintBoundary to prevent parent repaints.
class _TimerDisplay extends ConsumerWidget {
  const _TimerDisplay();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(sessionProvider).asData?.value;
    final lockedUntil = session?.lockedUntil;
    final isLocked = lockedUntil != null && lockedUntil.isAfter(DateTime.now());

    if (!isLocked) {
      // No lockout, minimal display
      return SizedBox(
        height: 60,
        child: Center(
          child: Text(
            DateTime.now().toString().split('.')[0],
            style: Theme.of(context).textTheme.labelSmall,
          ),
        ),
      );
    }

    // Show lockout countdown
    final remaining = lockedUntil.difference(DateTime.now());
    final seconds = remaining.inSeconds.clamp(0, 999);

    return Container(
      height: 60,
      color: Theme.of(context).colorScheme.errorContainer,
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              'Locked out',
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: Theme.of(context).colorScheme.error,
              ),
            ),
            Text(
              'Try again in ${seconds}s',
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: Theme.of(context).colorScheme.error,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
