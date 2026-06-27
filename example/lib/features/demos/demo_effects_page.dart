import 'package:flutter/material.dart';
import 'package:flutter_spine/flutter_spine.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class DemoEffectsPage extends ConsumerWidget {
  const DemoEffectsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final vm = ref.read(_demoEffectsVmProvider.notifier);

    return AppPageScaffold(
      title: 'Effects Demo',
      source: _DemoEffectsVm,
      onEffect: (ctx, effect) {
        if (effect is _CustomDialogEffect) {
          showDialog(
            context: ctx,
            builder: (_) => AlertDialog(
              title: const Text('Custom Effect'),
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
          _Button(
            icon: Icons.vibration,
            label: 'EffectHaptic (medium)',
            onPressed: vm.fireHaptic,
          ),
          const SizedBox(height: 12),
          _Button(
            icon: Icons.notifications,
            label: 'EffectShowToast (success)',
            onPressed: vm.fireToast,
          ),
          const SizedBox(height: 12),
          _Button(
            icon: Icons.chat_bubble_outline,
            label: 'Custom Effect (dialog)',
            onPressed: vm.fireCustomDialog,
          ),
          const SizedBox(height: 12),
          _Button(
            icon: Icons.navigate_next,
            label: 'EffectNavigate (to /my-page)',
            onPressed: vm.navigateToMyPage,
          ),
          const SizedBox(height: 12),
          _Button(
            icon: Icons.arrow_back,
            label: 'EffectPop (go back)',
            onPressed: vm.popBack,
          ),
        ],
      ),
    );
  }
}

class _Button extends StatelessWidget {
  const _Button({
    required this.icon,
    required this.label,
    required this.onPressed,
  });

  final IconData icon;
  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: FilledButton.icon(
        onPressed: onPressed,
        icon: Icon(icon),
        label: Text(label),
      ),
    );
  }
}

class _CustomDialogEffect extends Effect {
  const _CustomDialogEffect(this.message);
  final String message;
}

class _DemoEffectsVm extends ViewModelNotifier<int> {
  @override
  int build() => 0;

  void fireHaptic() {
    emit(const EffectHaptic(HapticKind.medium));
    update((_) => 0);
  }

  void fireToast() {
    emit(const EffectShowToast('Hello from Effects demo!',
        level: ToastLevel.success));
    update((_) => 0);
  }

  void fireCustomDialog() {
    emit(const _CustomDialogEffect('This is a custom effect triggered dialog.'));
    update((_) => 0);
  }

  void navigateToMyPage() {
    emit(const EffectNavigate('/my-page'));
    update((_) => 0);
  }

  void popBack() {
    emit(const EffectPop());
    update((_) => 0);
  }
}

final _demoEffectsVmProvider =
    NotifierProvider.autoDispose<_DemoEffectsVm, int>(_DemoEffectsVm.new);
