import 'package:flutter_spine/flutter_spine.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

// ── 测试用 filter ─────────────────────────────────────────────────────────────

class _Filter {
  const _Filter({this.status = 'all', this.page = 1});
  final String status;
  final int page;

  _Filter copyWith({String? status, int? page}) =>
      _Filter(status: status ?? this.status, page: page ?? this.page);

  @override
  bool operator ==(Object o) =>
      o is _Filter && o.status == status && o.page == page;
  @override
  int get hashCode => Object.hash(status, page);
}

class _FilterCtrl extends FilterNotifier<_Filter> {
  @override
  _Filter initial() => const _Filter();
}

final _filterProvider =
    NotifierProvider.autoDispose<_FilterCtrl, _Filter>(_FilterCtrl.new);

// ── Tests ────────────────────────────────────────────────────────────────────

void main() {
  group('FilterNotifier', () {
    late ProviderContainer container;

    setUp(() => container = ProviderContainer());
    tearDown(() => container.dispose());

    test('build returns initial()', () {
      expect(container.read(_filterProvider), const _Filter());
    });

    test('set replaces state entirely', () {
      container
          .read(_filterProvider.notifier)
          .set(const _Filter(status: 'done', page: 3));
      expect(container.read(_filterProvider), const _Filter(status: 'done', page: 3));
    });

    test('update applies partial change', () {
      container
          .read(_filterProvider.notifier)
          .update((f) => f.copyWith(status: 'pending'));
      expect(container.read(_filterProvider).status, 'pending');
      expect(container.read(_filterProvider).page, 1); // unchanged
    });

    test('reset returns to initial()', () {
      container
          .read(_filterProvider.notifier)
          .set(const _Filter(status: 'done', page: 5));
      container.read(_filterProvider.notifier).reset();
      expect(container.read(_filterProvider), const _Filter());
    });

    test('consecutive updates accumulate', () {
      final notifier = container.read(_filterProvider.notifier);
      notifier.update((f) => f.copyWith(status: 'a'));
      notifier.update((f) => f.copyWith(page: 2));
      final state = container.read(_filterProvider);
      expect(state.status, 'a');
      expect(state.page, 2);
    });
  });
}
