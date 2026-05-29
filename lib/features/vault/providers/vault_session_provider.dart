import 'package:flutter_riverpod/flutter_riverpod.dart';

class VaultSessionState {
  const VaultSessionState({this.unlocked = false, this.unlockedAt});

  final bool unlocked;
  final DateTime? unlockedAt;

  VaultSessionState copyWith({
    bool? unlocked,
    DateTime? unlockedAt,
    bool clearUnlockedAt = false,
  }) {
    return VaultSessionState(
      unlocked: unlocked ?? this.unlocked,
      unlockedAt: clearUnlockedAt ? null : (unlockedAt ?? this.unlockedAt),
    );
  }
}

final vaultSessionProvider =
    NotifierProvider<VaultSessionNotifier, VaultSessionState>(
      VaultSessionNotifier.new,
    );

class VaultSessionNotifier extends Notifier<VaultSessionState> {
  @override
  VaultSessionState build() {
    return const VaultSessionState(unlocked: true);
  }

  void unlock() {
    state = state.copyWith(unlocked: true, unlockedAt: DateTime.now());
  }

  void lock() {
    state = state.copyWith(unlocked: false, clearUnlockedAt: true);
  }
}
