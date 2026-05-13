import 'naming.dart';

/// 极简模板引擎——只做 `{{key}}` 全文替换，不引入 mustache / jinja 等。
///
/// 内置变量：
/// * `{{Name}}`       — PascalCase（`UserProfile`）
/// * `{{name}}`       — camelCase（`userProfile`）
/// * `{{name_snake}}` — snake_case（`user_profile`）
/// * `{{name-kebab}}` — kebab-case（`user-profile`）
/// * `{{Title}}`      — Title Case（`User Profile`）
///
/// 业务可在 [extras] 里传任意自定义键，键名建议大写以便和正文区分。
String renderTemplate(
  String template,
  Naming naming, {
  Map<String, String> extras = const {},
}) {
  final vars = {
    'Name': naming.pascal,
    'name': naming.camel,
    'name_snake': naming.snake,
    'name-kebab': naming.kebab,
    'Title': naming.title,
    ...extras,
  };
  var result = template;
  vars.forEach((k, v) {
    result = result.replaceAll('{{$k}}', v);
  });
  return result;
}
