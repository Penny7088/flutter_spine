import 'package:flutter/material.dart';
import 'package:flutter_spine/flutter_spine.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class SettingsPage extends ConsumerWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeModeProvider);

    return AppPageScaffold(
      title: 'Settings',
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Theme',
                      style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 8),
                  for (final mode in ThemeMode.values)
                    RadioListTile<ThemeMode>(
                      value: mode,
                      groupValue: themeMode,
                      title: Text(_themeLabel(mode)),
                      onChanged: (v) {
                        if (v != null) {
                          ref.read(themeModeProvider.notifier).set(v);
                          ref.read(appLoggerProvider).info(
                              'Theme changed to ${_themeLabel(v)}');
                        }
                      },
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Storage (KeyValueStorage)',
                      style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 8),
                  const _StorageDemo(),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Logger (AppLogger)',
                      style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 8),
                  FilledButton.icon(
                    onPressed: () {
                      ref.read(appLoggerProvider).debug('Debug log test');
                      ref.read(appLoggerProvider).info('Info log test');
                      ref.read(appLoggerProvider).warn('Warn log test');
                      ref.read(appLoggerProvider).error('Error log test');
                    },
                    icon: const Icon(Icons.terminal),
                    label: const Text('Write test logs'),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _themeLabel(ThemeMode mode) => switch (mode) {
        ThemeMode.light => 'Light',
        ThemeMode.dark => 'Dark',
        ThemeMode.system => 'System (default)',
      };
}

class _StorageDemo extends ConsumerWidget {
  const _StorageDemo();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final storage = ref.read(keyValueStorageProvider);
    final lastSaved = storage.getString('demo_last_saved');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (lastSaved != null)
          Text('Last saved: $lastSaved',
              style: Theme.of(context).textTheme.bodySmall),
        const SizedBox(height: 8),
        OutlinedButton.icon(
          onPressed: () {
            final now = DateTime.now().toIso8601String();
            storage.setString('demo_last_saved', now);
            ref.read(appLoggerProvider).info('Saved timestamp: $now');
          },
          icon: const Icon(Icons.save),
          label: const Text('Save current timestamp'),
        ),
      ],
    );
  }
}
