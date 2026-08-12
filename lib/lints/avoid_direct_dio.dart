// ignore_for_file: deprecated_member_use
// 保留旧 element 模型，与 custom_lint_builder 0.7.x 一致。

import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/element/element.dart';
import 'package:analyzer/error/listener.dart';
import 'package:custom_lint_builder/custom_lint_builder.dart';

import '../flutter_spine.dart';

/// 禁止业务代码直接 `new` Dio 类型或 import `package:dio/dio.dart`。
///
/// 触发场景（任一）：
///
/// * `Dio(...)`、`BaseOptions(...)`、`Options(...)`、`Interceptor()` 子类直接 `new`；
/// * `RequestOptions(...)` / `Response(...)` / `FormData(...)` / `MultipartFile(...)`
///   等 Dio 类型的实例化。
///
/// **不**禁止：调用 `flutter_spine` 暴露的 `HttpClient` / `DioHttpConfig` /
/// `Interceptor` 等已封装类型。
///
/// ## 为什么
///
/// * 业务代码绕过 `HttpClient` 抽象，走裸 Dio → 错误归一缺失（拿不到 [AppException]）；
/// * 测试时无法用 `MockHttpClient` / `_FakeAdapter` 注入；
/// * `DioHttpConfig.interceptors` 等"声明式"开关失效；
/// * `MultipartFile`、`FormData` 等类型直接出现在业务里，会让业务依赖 dio 版本号。
///
/// ## 改写指引
///
/// ```dart
/// // ❌ 业务代码
/// final dio = Dio(BaseOptions(baseUrl: 'https://api'));
/// final res = await dio.get('/users/me');
///
/// // ✅ 通过注入 HttpClient
/// final client = ref.read(httpClientProvider);
/// final user = await client.get<User>(
///   '/users/me',
///   decoder: (j) => User.fromJson(j! as Map<String, dynamic>),
/// );
///
/// // ❌ 业务代码组装 multipart
/// final form = FormData.fromMap({'avatar': MultipartFile.fromFileSync(path)});
/// await dio.post('/upload', data: form);
///
/// // ✅ 用 MultipartFilePart + HttpClient.upload
/// await client.upload<UploadResult>(
///   '/upload',
///   files: [MultipartFilePart.fromPath(field: 'avatar', filePath: path)],
///   decoder: (j) => UploadResult.fromJson(j! as Map<String, dynamic>),
/// );
/// ```
///
/// ## 豁免
///
/// * `flutter_spine` 自身的 HTTP 实现：`package/flutter_spine/lib/src/network/**`
/// * 应用启动 `/lib/main.dart` / `lib/bootstrap.dart`
/// * 测试 / fixture / example 路径
class AvoidDirectDio extends DartLintRule {
  const AvoidDirectDio() : super(code: _code);

  static const _code = LintCode(
    name: 'avoid_direct_dio',
    problemMessage:
        '业务代码请使用 HttpClient (flutter_spine)，不要直接 new Dio / Dio 类型。',
    correctionMessage:
        '通过 ref.read(httpClientProvider) 拿到 HttpClient；'
        '上传用 HttpClient.upload + MultipartFilePart；'
        '取消用 client.createCancelToken。',
  );

  static const _dioUri = 'package:dio/';

  @override
  void run(
    CustomLintResolver resolver,
    ErrorReporter reporter,
    CustomLintContext context,
  ) {
    final path = resolver.source.fullName.replaceAll('\\', '/');
    if (_isExempt(path)) return;

    context.registry.addInstanceCreationExpression((node) {
      final type = node.staticType;
      if (type == null) return;
      final element = type.element;
      if (element == null) return;

      final uri = element.library?.source.uri.toString() ?? '';
      if (!uri.startsWith(_dioUri)) return;

      // 允许业务自定义 Interceptor 子类（business 写 `class MyXxx extends Interceptor {}`）；
      // 触发条件是直接实例化"位于 dio 包"的类，所以 `MyXxx()` 不会触发——
      // MyXxx 的 library uri 是 business 包，不是 package:dio/。
      reporter.atNode(node, _code);
    });

    // 静态调用：`Dio.something(...)` / `BaseOptions.xxx(...)` 等
    context.registry.addMethodInvocation((node) {
      final target = node.realTarget;
      if (target == null) return;

      final name = switch (target) {
        Identifier() => target.name,
        _ => null,
      };
      if (name == null) return;

      final uri = _libraryUri(_resolveElement(target));
      if (!uri.startsWith(_dioUri)) return;

      // 静态方法 / 工厂构造（如 MultipartFile.fromFileSync）
      reporter.atNode(node, _code);
    });
  }

  Element? _resolveElement(dynamic node) {
    if (node is SimpleIdentifier) return node.staticElement;
    if (node is PrefixedIdentifier) return node.staticElement;
    return null;
  }

  /// 安全取 element 的所属 library URI。
  /// PrefixElement / 跨平台条件 import 等场景 element.librarySource 可能抛
  /// `'PrefixElementImpl' is not a subtype of 'Fragment' in type cast`，
  /// 直接返回空串当作"非 Dio"处理。
  String _libraryUri(Element? element) {
    if (element == null) return '';
    if (element is PrefixElement) return '';
    try {
      return element.librarySource?.uri.toString() ?? '';
    } catch (_) {
      return '';
    }
  }

  bool _isExempt(String path) {
    return path.contains('/package/flutter_spine/lib/src/network/') ||
        path.contains('/package/flutter_spine_test/') ||
        path.endsWith('/lib/main.dart') ||
        path.endsWith('/lib/bootstrap.dart') ||
        path.contains('/test/') ||
        path.contains('/test_fixtures/') ||
        path.contains('/example/');
  }
}