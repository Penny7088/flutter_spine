import 'package:flutter_spine/flutter_spine.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeState with HasViewStatus {
  _FakeState({required this.status, this.error});

  @override
  final ViewStatus status;

  @override
  final AppException? error;
}

void main() {
  group('ViewStatus 扩展判断', () {
    test('isIdle / isLoading / isRefreshing / isOk / isError 各自互斥', () {
      expect(ViewStatus.idle.isIdle, isTrue);
      expect(ViewStatus.idle.isLoading, isFalse);

      expect(ViewStatus.loading.isLoading, isTrue);
      expect(ViewStatus.loading.isIdle, isFalse);

      expect(ViewStatus.refreshing.isRefreshing, isTrue);
      expect(ViewStatus.refreshing.isLoading, isFalse);

      expect(ViewStatus.ok.isOk, isTrue);
      expect(ViewStatus.error.isError, isTrue);
    });

    test('isBusy = loading ∪ refreshing', () {
      expect(ViewStatus.loading.isBusy, isTrue);
      expect(ViewStatus.refreshing.isBusy, isTrue);
      expect(ViewStatus.idle.isBusy, isFalse);
      expect(ViewStatus.ok.isBusy, isFalse);
      expect(ViewStatus.error.isBusy, isFalse);
    });

    test('hasData = ok ∪ refreshing（刷新中仍有旧数据）', () {
      expect(ViewStatus.ok.hasData, isTrue);
      expect(ViewStatus.refreshing.hasData, isTrue);
      expect(ViewStatus.loading.hasData, isFalse,
          reason: '首次加载没有数据可展示');
      expect(ViewStatus.idle.hasData, isFalse);
      expect(ViewStatus.error.hasData, isFalse);
    });
  });

  group('HasViewStatus mixin', () {
    test('实现类正确暴露 status / error', () {
      final s1 = _FakeState(status: ViewStatus.ok);
      expect(s1.status, ViewStatus.ok);
      expect(s1.error, isNull);

      const err = NotFoundException(message: 'not found');
      final s2 = _FakeState(status: ViewStatus.error, error: err);
      expect(s2.status, ViewStatus.error);
      expect(s2.error, err);
    });

    test('可用 is HasViewStatus 判断', () {
      final Object s = _FakeState(status: ViewStatus.loading);
      expect(s is HasViewStatus, isTrue);
    });
  });
}
