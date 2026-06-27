import 'package:flutter/foundation.dart';
import 'package:flutter_spine/flutter_spine.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// 自定义全局 effect——HomeVm 专属，Shell 捕获。
class GlobalCustomEffect extends Effect {
  const GlobalCustomEffect(this.message);
  final String message;
}

@immutable
class HomeState with HasViewStatus {
  const HomeState({
    this.status = ViewStatus.idle,
    this.error,
  });

  @override
  final ViewStatus status;

  @override
  final AppException? error;

  HomeState copyWith({
    ViewStatus? status,
    AppException? error,
  }) =>
      HomeState(
        status: status ?? this.status,
        error: error ?? this.error,
      );
}

class HomeVm extends ViewModelNotifier<HomeState> {
  @override
  HomeState build() {
    ref.keepAlive();
    return const HomeState();
  }

  void emitToast() {
    emit(const EffectShowToast('Global toast from HomeVm',
        level: ToastLevel.success));
  }

  void emitCustom() {
    emit(const GlobalCustomEffect('Global custom effect from HomeVm'));
  }
}

final homeVmProvider =
    NotifierProvider.autoDispose<HomeVm, HomeState>(HomeVm.new);
