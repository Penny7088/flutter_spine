import 'package:flutter_spine/flutter_spine.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('BootstrapAudit.fromConfig', () {
    test('默认 config：effectHandler ok / 其他 skipped', () {
      final audit = BootstrapAudit.fromConfig(const FlutterSpineConfig());
      final byKey = {for (final e in audit.entries) e.key: e};

      expect(byKey['effectHandler']!.status, AuditStatus.ok);
      expect(byKey['effectHandler']!.value,
          contains('MaterialDefaultEffectHandler'));
      expect(byKey['http']!.status, AuditStatus.skipped);
      expect(byKey['storage']!.status, AuditStatus.skipped);
      expect(byKey['ws']!.status, AuditStatus.warn);
      expect(byKey['logger']!.value, contains('PrettyAppLogger'));
    });

    test('全套 config：全部 ok', () {
      final audit = BootstrapAudit.fromConfig(FlutterSpineConfig(
        http: const DioHttpConfig(baseUrl: 'https://api.example.com'),
        ws: (uri) => WsClientConfig(url: uri),
        storage: () async => _FakeStorage(),
        logger: PrettyAppLogger(),
      ));
      final byKey = {for (final e in audit.entries) e.key: e};

      expect(byKey['http']!.status, AuditStatus.ok);
      expect(byKey['http']!.value, contains('api.example.com'));
      expect(byKey['ws']!.status, AuditStatus.ok);
      expect(byKey['storage']!.status, AuditStatus.ok);
    });

    test('errorObserverEnabled=false → warn', () {
      final audit = BootstrapAudit.fromConfig(
        const FlutterSpineConfig(errorObserverEnabled: false),
      );
      final entry = audit.entries.firstWhere((e) => e.key == 'ErrorObserver');
      expect(entry.status, AuditStatus.warn);
      expect(entry.value, 'disabled');
    });
  });

  group('BootstrapAudit.render', () {
    test('包含 box 边框 + ✅ icon + key/value', () {
      final out = BootstrapAudit.fromConfig(const FlutterSpineConfig()).render();
      expect(out, contains('flutter_spine bootstrap audit'));
      expect(out, contains('╔'));
      expect(out, contains('╚'));
      expect(out, contains('✅'));
      expect(out, contains('effectHandler'));
    });

    test('skipped 状态用 ⏭️ 图标', () {
      final out = BootstrapAudit.fromConfig(const FlutterSpineConfig()).render();
      expect(out, contains('⏭️'));
    });
  });
}

class _FakeStorage implements KeyValueStorage {
  @override
  Future<void> setString(String key, String value) async {}
  @override
  String? getString(String key) => null;
  @override
  Future<void> setInt(String key, int value) async {}
  @override
  int? getInt(String key) => null;
  @override
  Future<void> setBool(String key, bool value) async {}
  @override
  bool? getBool(String key) => null;
  @override
  Future<void> setJson(String key, Map<String, dynamic> value) async {}
  @override
  Map<String, dynamic>? getJson(String key) => null;
  @override
  Future<bool> contains(String key) async => false;
  @override
  Future<void> remove(String key) async {}
  @override
  Future<void> clear() async {}
}
