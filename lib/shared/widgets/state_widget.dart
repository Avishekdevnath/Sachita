import 'package:flutter/material.dart';
import 'package:sanchita/core/theme/app_design_tokens.dart';
import 'package:sanchita/shared/widgets/smooth_loading_transition.dart';

/// Unified state widget for handling loading, error, and empty states.
/// Simplifies UI code by handling all state transitions automatically.
class StateWidget<T> extends StatelessWidget {
  const StateWidget({
    super.key,
    required this.state,
    required this.onSuccess,
    this.onLoading,
    this.onError,
    this.onEmpty,
    this.skeleton,
    this.loadingDuration = AppTokens.durationNormal,
  });

  final AsyncValue<T>? state;
  final Widget Function(T data) onSuccess;
  final Widget Function()? onLoading;
  final Widget Function(String error)? onError;
  final Widget Function()? onEmpty;
  final Widget? skeleton;
  final Duration loadingDuration;

  @override
  Widget build(BuildContext context) {
    if (state == null) {
      return onLoading?.call() ?? _defaultLoading();
    }

    return state!.when(
      loading: () => onLoading?.call() ?? _defaultLoading(),
      error: (error, stack) =>
          onError?.call(error.toString()) ?? _defaultError(error),
      data: (data) {
        // Check if data is empty (for lists, etc.)
        if (data is List && data.isEmpty) {
          return onEmpty?.call() ?? _defaultEmpty();
        }
        return onSuccess(data);
      },
    );
  }

  Widget _defaultLoading() {
    return SmoothLoadingTransition(
      isLoading: true,
      skeleton: skeleton,
      child: const SizedBox.shrink(),
    );
  }

  Widget _defaultError(Object error) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppTokens.space24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline,
              size: AppTokens.iconLg,
              color: Theme.of(_contextKey.currentContext!).colorScheme.error,
            ),
            const SizedBox(height: AppTokens.space16),
            Text(
              'Something went wrong',
              style: Theme.of(_contextKey.currentContext!).textTheme.titleMedium,
            ),
            const SizedBox(height: AppTokens.space8),
            Text(
              error.toString(),
              textAlign: TextAlign.center,
              style: Theme.of(_contextKey.currentContext!).textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }

  Widget _defaultEmpty() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppTokens.space24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.inbox_outlined,
              size: AppTokens.iconLg,
              color: Theme.of(_contextKey.currentContext!).colorScheme.outline,
            ),
            const SizedBox(height: AppTokens.space16),
            Text(
              'Nothing here yet',
              style: Theme.of(_contextKey.currentContext!).textTheme.titleMedium,
            ),
          ],
        ),
      ),
    );
  }

  static final _contextKey = GlobalKey();
}

/// Async value state representation
enum AsyncValueStatus { loading, error, data }

extension AsyncValueExt<T> on AsyncValue<T> {
  bool get isLoading => this is AsyncLoading;
  bool get isError => this is AsyncError;
  bool get isData => this is AsyncData;

  T? getDataOrNull() => maybeWhen(
        data: (d) => d,
        orElse: () => null,
      );

  Object? getErrorOrNull() => maybeWhen(
        error: (e, _) => e,
        orElse: () => null,
      );
}

/// Riverpod AsyncValue placeholder types
abstract class AsyncValue<T> {
  const AsyncValue();

  R when<R>({
    required R Function() loading,
    required R Function(Object error, StackTrace stackTrace) error,
    required R Function(T data) data,
  });

  R maybeWhen<R>({
    R Function()? loading,
    R Function(Object error, StackTrace stackTrace)? error,
    R Function(T data)? data,
    required R Function() orElse,
  });
}

class AsyncLoading<T> extends AsyncValue<T> {
  const AsyncLoading();

  @override
  R when<R>({
    required R Function() loading,
    required R Function(Object error, StackTrace stackTrace) error,
    required R Function(T data) data,
  }) {
    return loading();
  }

  @override
  R maybeWhen<R>({
    R Function()? loading,
    R Function(Object error, StackTrace stackTrace)? error,
    R Function(T data)? data,
    required R Function() orElse,
  }) {
    return loading?.call() ?? orElse();
  }
}

class AsyncError<T> extends AsyncValue<T> {
  const AsyncError(this.error, this.stackTrace);

  final Object error;
  final StackTrace stackTrace;

  @override
  R when<R>({
    required R Function() loading,
    required R Function(Object error, StackTrace stackTrace) error,
    required R Function(T data) data,
  }) {
    return error(error, stackTrace);
  }

  @override
  R maybeWhen<R>({
    R Function()? loading,
    R Function(Object error, StackTrace stackTrace)? error,
    R Function(T data)? data,
    required R Function() orElse,
  }) {
    return error?.call(error, stackTrace) ?? orElse();
  }
}

class AsyncData<T> extends AsyncValue<T> {
  const AsyncData(this.value);

  final T value;

  @override
  R when<R>({
    required R Function() loading,
    required R Function(Object error, StackTrace stackTrace) error,
    required R Function(T data) data,
  }) {
    return data(value);
  }

  @override
  R maybeWhen<R>({
    R Function()? loading,
    R Function(Object error, StackTrace stackTrace)? error,
    R Function(T data)? data,
    required R Function() orElse,
  }) {
    return data?.call(value) ?? orElse();
  }
}
