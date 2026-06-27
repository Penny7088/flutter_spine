import 'package:flutter/material.dart';
import 'package:flutter_spine/flutter_spine.dart';

class DemoExtensionsPage extends StatelessWidget {
  const DemoExtensionsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final now = DateTime.now();
    final items = ['apple', 'banana', 'cherry'];
    final price = 1234567.89;

    return AppPageScaffold(
      title: 'Extensions',
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _Section(theme: theme, title: 'BuildContextX', children: [
            _Row('screenSize', '${context.screenSize}'),
            _Row('isDark', '${context.isDark}'),
            _Row('bottomSafeArea', '${context.bottomSafeArea}'),
          ]),
          const SizedBox(height: 12),
          _Section(theme: theme, title: 'DateTimeX', children: [
            _Row('toDateString()', now.toDateString()),
            _Row('toDateTimeString()', now.toDateTimeString()),
            _Row('isSameDay(today)', '${now.isSameDay(DateTime.now())}'),
            _Row('secondsSinceEpoch', '${now.secondsSinceEpoch}'),
          ]),
          const SizedBox(height: 12),
          _Section(theme: theme, title: 'IterableX', children: [
            _Row('firstWhereOrNull(6)',
                '${[1, 2, 3].firstWhereOrNull((e) => e > 6)}'),
            _Row('elementAtOrNull(5)',
                '${[1, 2, 3].elementAtOrNull(5)}'),
            _Row('groupBy(length)',
                '${items.groupBy((e) => e.length)}'),
          ]),
          const SizedBox(height: 12),
          _Section(theme: theme, title: 'NumFormatX', children: [
            _Row('toThousandsSep()', price.toThousandsSep()),
            _Row('toFixedSafe(1)', '${price.toFixedSafe(1)}'),
            _Row('"42".toIntSafe()', '${'42'.toIntSafe()}'),
            _Row('"abc".toIntSafe(0)', '${'abc'.toIntSafe(0)}'),
          ]),
          const SizedBox(height: 12),
          _Section(theme: theme, title: 'StringSafeX', children: [
            _Row('nullIfBlank',
                '  '.nullIfBlank ?? '(null)'),
            _Row('capitalized', 'hello world'.capitalized),
            _Row('safeSubstring(0,3)', 'hello'.safeSubstring(0, 3)),
            _Row('maskMiddle()',
                '13812345678'.maskMiddle(prefix: 3, suffix: 4)),
          ]),
        ],
      ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({
    required this.theme,
    required this.title,
    required this.children,
  });

  final ThemeData theme;
  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: theme.textTheme.titleSmall),
            const SizedBox(height: 8),
            for (final c in children) ...[c, const SizedBox(height: 4)],
          ],
        ),
      ),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row(this.label, this.value);

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text('$label: ', style: const TextStyle(fontWeight: FontWeight.w600)),
        Expanded(child: Text(value)),
      ],
    );
  }
}
