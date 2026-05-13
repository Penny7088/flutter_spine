import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// 对 [AsyncValue] 的三种状态（data / loading / error）提供统一渲染。
///
/// 特性：
///   * `skipLoadingOnRefresh=true`（默认）：刷新期间继续展示旧数据，避免闪屏；
///   * [error] 回调默认提供 retry 按钮；
///   * [loading] 默认 `CircularProgressIndicator`；
///   * [error] 默认显示 message + retry 按钮。
class AsyncBuilder<T> extends ConsumerWidget {
  const AsyncBuilder({
    super.key,
    required this.provider,
    required this.data,
    this.loading,
    this.error,
    this.skipLoadingOnRefresh = true,
  });

  final ProviderListenable<AsyncValue<T>> provider;
  final Widget Function(T data) data;
  final WidgetBuilder? loading;
  final Widget Function(
    Object error,
    StackTrace stackTrace,
    VoidCallback retry,
  )? error;
  final bool skipLoadingOnRefresh;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final value = ref.watch(provider);

    if (value.hasValue && (skipLoadingOnRefresh || !value.isLoading)) {
      return data(value.value as T);
    }
    if (value.hasError && !value.isLoading) {
      final retry = _buildRetry(ref);
      return error?.call(value.error!, value.stackTrace!, retry) ??
          _DefaultError(error: value.error!, onRetry: retry);
    }
    return loading?.call(context) ??
        const Center(child: CircularProgressIndicator());
  }

  VoidCallback _buildRetry(WidgetRef ref) => () {
        final p = provider;
        if (p is ProviderOrFamily) ref.invalidate(p as ProviderOrFamily);
      };
}

class _DefaultError extends StatelessWidget {
  const _DefaultError({required this.error, required this.onRetry});

  final Object error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            error.toString(),
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 12),
          OutlinedButton(onPressed: onRetry, child: const Text('Retry')),
        ],
      ),
    );
  }
}
