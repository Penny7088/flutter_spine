import 'package:flutter/material.dart';
import 'package:flutter_spine/flutter_spine.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../home/home_vm.dart';

/// 局部自定义 effect——只被本页 listener 捕获。
class _LocalCustomEffect extends Effect {
  const _LocalCustomEffect(this.message);
  final String message;
}

class _RoutingState with HasViewStatus {
  const _RoutingState({this.log = const [], this.status = ViewStatus.idle, this.error});

  final List<String> log;

  @override
  final ViewStatus status;

  @override
  final AppException? error;

  _RoutingState copyWith({
    List<String>? log,
    ViewStatus? status,
    AppException? error,
  }) =>
      _RoutingState(
        log: log ?? this.log,
        status: status ?? this.status,
        error: error ?? this.error,
      );
}

class _RoutingVm extends ViewModelNotifier<_RoutingState> {
  @override
  _RoutingState build() => const _RoutingState();

  void fireLocalToast() {
    emit(const EffectShowToast('Local toast from RoutingVm',
        level: ToastLevel.success));
    update((s) => s.copyWith(
        log: ['[Local] Emitted: EffectShowToast', ...s.log]));
  }

  void fireLocalCustom() {
    emit(const _LocalCustomEffect('Hello from Local VM!'));
    update((s) => s.copyWith(
        log: ['[Local] Emitted: _LocalCustomEffect', ...s.log]));
  }
}

final _routingVmProvider =
    NotifierProvider.autoDispose<_RoutingVm, _RoutingState>(_RoutingVm.new);

class DemoEffectRoutingPage extends ConsumerWidget {
  const DemoEffectRoutingPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(_routingVmProvider);
    final routingVm = ref.read(_routingVmProvider.notifier);
    final homeVm = ref.read(homeVmProvider.notifier);
    final theme = Theme.of(context);

    return AppPageScaffold(
      title: 'Effect Routing',
      source: _RoutingVm,
      onEffect: (ctx, effect) {
        if (effect is _LocalCustomEffect) {
          showDialog(
            context: ctx,
            builder: (_) => AlertDialog(
              title: const Text('Local Effect (Page)'),
              content: Text(effect.message),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(ctx).pop(),
                  child: const Text('OK'),
                ),
              ],
            ),
          );
        }
      },
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // ── Architecture diagram ──
          Card(
            color: theme.colorScheme.surfaceContainerHighest,
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Effect Routing',
                      style: theme.textTheme.titleSmall),
                  const SizedBox(height: 8),
                  Text(
                    'Listeners filter by source type — no matter where '
                    'in the widget tree they sit.',
                    style: theme.textTheme.bodySmall,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '''Root Listener  (source: null)
  └─ Shell         (source: HomeVm)
       ├─ DemoPage  (source: _RoutingVm) ← you are here
       └─ TasksTab  (source: TasksVm)''',
                    style: theme.textTheme.bodySmall!.copyWith(
                      fontFamily: 'monospace',
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // ── Global (HomeVm) ──
          Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.language, size: 18,
                          color: theme.colorScheme.primary),
                      const SizedBox(width: 6),
                      Text('Global — from HomeVm',
                          style: theme.textTheme.titleSmall),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Emitted by HomeVm → Shell (source: HomeVm) catches it.\n'
                    'TasksTab / DemoPage listeners skip it (source mismatch).',
                    style: theme.textTheme.bodySmall,
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: FilledButton.tonalIcon(
                          onPressed: homeVm.emitToast,
                          icon: const Icon(Icons.notifications, size: 18),
                          label: const Text('Toast'),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: FilledButton.tonalIcon(
                          onPressed: homeVm.emitCustom,
                          icon: const Icon(Icons.chat_bubble_outline, size: 18),
                          label: const Text('Custom Dialog'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),

          // ── Local (this page) ──
          Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.touch_app, size: 18,
                          color: theme.colorScheme.secondary),
                      const SizedBox(width: 6),
                      Text('Local — from _RoutingVm',
                          style: theme.textTheme.titleSmall),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Emitted by _RoutingVm → this page (source: _RoutingVm) catches it.\n'
                    'Shell skips (source: HomeVm — mismatch).',
                    style: theme.textTheme.bodySmall,
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: FilledButton.icon(
                          onPressed: routingVm.fireLocalToast,
                          icon: const Icon(Icons.notifications, size: 18),
                          label: const Text('Toast'),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: FilledButton.icon(
                          onPressed: routingVm.fireLocalCustom,
                          icon: const Icon(Icons.chat_bubble_outline, size: 18),
                          label: const Text('Custom Dialog'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // ── Log ──
          if (state.log.isNotEmpty) ...[
            Text('Log', style: theme.textTheme.titleSmall),
            const SizedBox(height: 8),
            for (final entry in state.log)
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text(entry,
                    style: theme.textTheme.bodySmall!.copyWith(
                        fontFamily: 'monospace', fontSize: 12)),
              ),
          ],
        ],
      ),
    );
  }
}
