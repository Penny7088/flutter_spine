---
name: flutter-core-add-lint
description: Add a new custom lint rule to flutter_core_lint. Use when the user asks to add a lint, ban a coding pattern, enforce an architectural rule at compile time, or extend custom_lint coverage in this repo.
---

# 加一条 custom lint

`flutter_core_lint` 是基于 `custom_lint_builder` 的插件包。每条规则一个文件，注册到 `getLintRules`。

## 步骤（5 个动作，按序）

### 1. 起 rule 文件

`package/flutter_core_lint/lib/src/lints/<snake_case>.dart`：

```dart
// ignore_for_file: deprecated_member_use
// 与 custom_lint_builder 0.7.x 一致，沿用旧 element 模型。

import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/element/element.dart';
import 'package:analyzer/error/listener.dart';
import 'package:custom_lint_builder/custom_lint_builder.dart';

class AvoidXxx extends DartLintRule {
  const AvoidXxx() : super(code: _code);

  static const _code = LintCode(
    name: 'avoid_xxx',                                  // snake_case，对外可见
    problemMessage: '一句话说明禁止什么。',
    correctionMessage: '一句话告诉用户应该怎么改。',
  );

  @override
  void run(
    CustomLintResolver resolver,
    ErrorReporter reporter,
    CustomLintContext context,
  ) {
    final path = resolver.source.fullName.replaceAll('\\', '/');
    if (_isExempt(path)) return;

    context.registry.addMethodInvocation((node) {
      // 你的检测逻辑
      reporter.atNode(node, _code);
    });
  }

  bool _isExempt(String path) =>
      path.contains('/package/flutter_core/lib/src/<...>/') ||  // flutter_core 自身实现
      path.endsWith('/lib/main.dart') ||
      path.endsWith('/lib/bootstrap.dart') ||
      path.contains('/test/') ||
      path.contains('/test_fixtures/') ||
      path.contains('/example/');
}
```

### 2. 注册到 plugin

`package/flutter_core_lint/lib/flutter_core_lint.dart`：

```dart
List<LintRule> getLintRules(CustomLintConfigs configs) => const [
      AvoidRawScaffold(),
      NoUiInViewModel(),
      AvoidStaticMutableInNotifier(),
      AvoidDirectHiveAccess(),
      AvoidDirectMethodChannel(),
      AvoidDirectDio(),
      AvoidDirectWebSocket(),
      AvoidXxx(),                     // ← 加你的
    ];
```

不加这一步规则**不会生效**，custom_lint 不会扫到。

### 3. 写最少 2 个 fixture 用例

在 `package/flutter_core/example/lib/` 下放一个临时文件演示**应该报 + 应该不报**两种情况，用来 smoke 验证：

```dart
// ❌ 应该报
final dio = Dio();

// ✅ 不应报（在豁免路径里）
import 'package:flutter_core/flutter_core.dart';
final http = ref.read(httpClientProvider);
```

### 4. 跑 custom_lint 验证

```bash
cd package/flutter_core/example
dart run custom_lint
```

必须满足两件事：
- ✅ 报出第一类（应该报）—— 错误信息里能看到你的 lint name 和 problemMessage
- ✅ plugin 没 crash（输出末尾不能出现 "type 'X' is not a subtype of 'Y' in type cast" 之类）

如果 plugin crash，看 `flutter-core-fix-lint-fail` skill 里的常见坑（特别是 `PrefixElement` cast）。

### 5. 文档同步（必做，否则下次没人知道）

| 文件 | 加什么 |
|---|---|
| `package/flutter_core_lint/README.md` | 表格里追加：`avoid_xxx` \| 拦什么 \| 救什么坑 \| 豁免路径 |
| `package/flutter_core/ARCHITECTURE.md` § P4 | 表格追加 |
| `package/flutter_core/ARCHITECTURE.md` § "监管边界" | 如果是业务侧禁止行为，加一条 ❌ |
| `package/flutter_core/AGENTS.md` § "不可破红线" | 如果是硬约束 |

## 检测姿势速查

| 想拦 | 用 |
|---|---|
| 调某个静态方法 / 实例方法 | `context.registry.addMethodInvocation((node) => ...)` |
| 用某个类构造器 | `context.registry.addInstanceCreationExpression((node) => ...)` |
| 引用某个 `Type.member` | `context.registry.addPrefixedIdentifier((node) => ...)` |
| import 某个包 | 在 `addImportDirective` 检测 `node.uri.stringValue` |
| 某个类继承 | `addClassDeclaration((node) => node.extendsClause?.superclass...)` |

判定来源 library URI（区分 `dio` vs 自家 `Dio` 类）：

```dart
String _libraryUri(Element? element) {
  if (element == null) return '';
  if (element is PrefixElement) return '';      // 关键 guard，不加会 crash
  return element.librarySource?.uri.toString() ?? '';
}

bool _isDioLib(String uri) => uri.startsWith('package:dio/');
```

## 必有豁免清单

任何"禁止 X"的规则，下面 5 类路径**都必须**豁免：

```dart
bool _isExempt(String path) =>
    path.contains('/package/flutter_core/lib/src/<X 实现目录>/') ||
    path.endsWith('/lib/main.dart') ||
    path.endsWith('/lib/bootstrap.dart') ||
    path.contains('/test/') ||
    path.contains('/test_fixtures/') ||
    path.contains('/example/');
```

漏哪一项都会给业务团队添堵。

## 不要做的事

- ❌ 不要在一个 lint 里同时检测两件事（拆成两条 lint）。
- ❌ 不要 `problemMessage` 写"don't do this"——业务看不懂；写**为什么**禁止 + **指向**正确写法。
- ❌ 不要忘 `_isExempt(path) return;`——会让 flutter_core 自身实现的代码也红一片。
- ❌ 不要忘 `path.replaceAll('\\', '/')` —— Windows 上 `fullName` 是反斜杠。
- ❌ 不要直接 `element as Fragment` / `element as XxxElement` —— 先 `element is` 判，否则会 plugin-wide crash。
- ❌ 不要用 `severity: ErrorSeverity.warning` 之类 —— LintCode 默认就是 lint，业务工程的 `analysis_options.yaml` 决定升级到 error 还是当 info。

## 验证

```bash
cd package/flutter_core_lint && dart analyze
cd ../flutter_core/example && dart run custom_lint
```

两个命令都必须 0 error / 不 crash。
