/// 表单页：state（含字段 + 校验信息）+ vm（update / run + emit pop）+ page（AppFormPageScaffold）。
const formStateTemplate = r'''
import 'package:flutter/foundation.dart';

@immutable
class {{Name}}State {
  const {{Name}}State({
    this.username = '',
    this.password = '',
    this.submitting = false,
    this.errorMsg,
  });

  final String username;
  final String password;
  final bool submitting;
  final String? errorMsg;

  bool get canSubmit =>
      username.trim().isNotEmpty && password.length >= 6 && !submitting;

  {{Name}}State copyWith({
    String? username,
    String? password,
    bool? submitting,
    Object? errorMsg = const _Sentinel(),
  }) =>
      {{Name}}State(
        username: username ?? this.username,
        password: password ?? this.password,
        submitting: submitting ?? this.submitting,
        errorMsg:
            errorMsg is _Sentinel ? this.errorMsg : errorMsg as String?,
      );
}

class _Sentinel {
  const _Sentinel();
}
''';

const formVmTemplate = r'''
import 'package:flutter_spine/flutter_spine.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '{{name_snake}}_state.dart';

final {{name}}VmProvider =
    NotifierProvider.autoDispose<{{Name}}Vm, {{Name}}State>({{Name}}Vm.new);

class {{Name}}Vm extends ViewModelNotifier<{{Name}}State> {
  @override
  {{Name}}State build() => const {{Name}}State();

  void setUsername(String v) =>
      update((s) => s.copyWith(username: v, errorMsg: null));

  void setPassword(String v) =>
      update((s) => s.copyWith(password: v, errorMsg: null));

  Future<void> submit() async {
    if (!state.canSubmit) return;
    await run<void>(
      () async {
        // TODO: 替换成 ref.read(authRepositoryProvider).login(...)
        await Future<void>.delayed(const Duration(milliseconds: 600));
      },
      onStart: (s) => s.copyWith(submitting: true, errorMsg: null),
      onSuccess: (s, _) {
        emit(const EffectShowToast('Done', level: ToastLevel.success));
        emit(const EffectPop(true));
        return s.copyWith(submitting: false);
      },
      onFailure: (s, err) => s.copyWith(
        submitting: false,
        errorMsg: err.message,
      ),
    );
  }
}
''';

const formPageTemplate = r'''
import 'package:flutter/material.dart';
import 'package:flutter_spine/flutter_spine.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '{{name_snake}}_vm.dart';

class {{Name}}Page extends ConsumerWidget {
  const {{Name}}Page({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch({{name}}VmProvider);
    final vm = ref.read({{name}}VmProvider.notifier);

    return AppFormPageScaffold(
      title: '{{Title}}',
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            decoration: const InputDecoration(labelText: 'Username'),
            onChanged: vm.setUsername,
          ),
          const SizedBox(height: 12),
          TextField(
            decoration: const InputDecoration(labelText: 'Password'),
            obscureText: true,
            onChanged: vm.setPassword,
          ),
          if (state.errorMsg != null) ...[
            const SizedBox(height: 12),
            Text(
              state.errorMsg!,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ],
        ],
      ),
      bottomAction: FilledButton(
        onPressed: state.canSubmit ? vm.submit : null,
        child: state.submitting
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : const Text('Submit'),
      ),
    );
  }
}
''';

const formVmTestTemplate = r'''
import 'package:flutter_spine/flutter_spine.dart';
import 'package:flutter_core_test/flutter_core_test.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:{{pkg}}/features/{{name_snake}}/{{name_snake}}_vm.dart';

void main() {
  group('{{Name}}Vm', () {
    test('canSubmit 校验：username + password>=6', () {
      final h = createVmTestHarness();
      h.keepAlive({{name}}VmProvider);
      final vm = h.read({{name}}VmProvider.notifier);
      expect(h.read({{name}}VmProvider).canSubmit, isFalse);

      vm.setUsername('alice');
      vm.setPassword('12345');
      expect(h.read({{name}}VmProvider).canSubmit, isFalse);

      vm.setPassword('123456');
      expect(h.read({{name}}VmProvider).canSubmit, isTrue);
    });

    test('submit 成功：发 EffectShowToast + EffectPop(true)', () async {
      final h = createVmTestHarness();
      h.keepAlive({{name}}VmProvider);
      final vm = h.read({{name}}VmProvider.notifier);
      vm.setUsername('alice');
      vm.setPassword('123456');

      await vm.submit();
      await h.pump();

      final payloads = h.effects.payloads;
      expect(payloads.any((e) => e is EffectShowToast), isTrue);
      expect(payloads.any((e) => e is EffectPop), isTrue);
    });
  });
}
''';
