import 'package:flutter_spine/flutter_spine.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'my_page_state.dart';

final myPageVmProvider =
    NotifierProvider.autoDispose<MyPageVm, MyPageState>(MyPageVm.new);

class MyPageVm extends ViewModelNotifier<MyPageState> {
  @override
  MyPageState build() => const MyPageState();

  void increment() => update((s) => s.copyWith(counter: s.counter + 1));

  void decrement() => update((s) => s.copyWith(counter: s.counter - 1));

  Future<void> resetWithToast() async {
    update((s) => s.copyWith(counter: 0));
    emit(const EffectShowToast('Reset done', level: ToastLevel.success));
  }
}
