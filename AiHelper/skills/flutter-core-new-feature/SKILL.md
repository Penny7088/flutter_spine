---
name: flutter-core-new-feature
description: Generate a new feature/page/VM/repository in flutter_core or business apps via the dart run flutter_core:new CLI. Use when the user asks to create a new page, async page, paged list, form, repository, effect, or full feature module.
---

# 新建 feature / page / VM / repo

`flutter_core` 已经把"建一组业务文件"沉到 CLI 里。**不要手抄模板**——CLI 是单一来源，模板改了你手抄的就老了。

## 决策树

| 用户说的 | 命令 |
|---|---|
| "加个普通页面 / 表单页 / 详情页" | `page` |
| "加个异步加载页（首屏 loading/error）" | `async-page` |
| "加个分页列表 / 无限下拉" | 无内置命令——业务自建状态类 + 手写 refresh/loadMore（README §4） |
| "加个表单页（输入 + 提交）" | `form` |
| "加个 Repository / 数据层" | `repo` |
| "加个自定义 Effect" | `effect` |
| "建一整个模块（页 + VM + repo + 路由 + 测试）" | `feature` |
| "新工程零起步配 flutter_core" | `bootstrap`（**只在新 app 用一次**） |

## 步骤

1. **必须**先 `cd` 到目标业务包根（`pubspec.yaml` 所在目录）。flutter_core 自身的 `example/` 也是合法目标。
2. 跑 `dart run flutter_core:new <command> --help` 确认参数。
3. 用 CLI 生成：
   ```bash
   dart run flutter_core:new page user_profile --with-test
   dart run flutter_core:new async-page order_detail
   dart run flutter_core:new form login
   dart run flutter_core:new repo user
   dart run flutter_core:new effect refresh_balance
   dart run flutter_core:new feature wallet \
       --variant=async --with-repo --with-route --with-test
   ```
4. **如果业务工程使用 `riverpod_generator`** → 任意命令加 `--gen`，生成出来的是 `@riverpod class FooVm extends _$FooVm with ViewModelMixin<FooState>` 风格。
5. 跑 `dart format <生成的文件>`，让风格统一。
6. 如果生成了 generator 风格代码：`dart run build_runner build --delete-conflicting-outputs`。
7. 加测试（如果 `--with-test`）后跑 `flutter test test/<feature>/`。

## 命名约定（必须遵守）

| 用户给 | CLI 期望 | 生成文件 | 类名 / provider |
|---|---|---|---|
| `user_profile` | snake_case | `user_profile_vm.dart` / `user_profile_page.dart` | `UserProfileVm` / `userProfileVmProvider` |
| `OrderDetail` | ❌ 拒绝 | — | — |
| `order-detail` | ❌ 拒绝 | — | — |

CLI 强制 snake_case；不符合直接 `UsageException`。

## 不要做的事

- ❌ 手写一份 VM + Provider + Page，跳过 CLI——会和模板风格漂移。
- ❌ `dart run flutter_core:new feature wallet --variant=sync`，然后再想接异步：异步 vs 同步是两套基类，迁移代价高。**先想清楚 variant**：列表用 `--variant=async`、表单用 `--variant=sync`。
- ❌ 在 `flutter_core` 包内部用 CLI 加业务 feature——`flutter_core` 是地基，**不应有任何 feature 文件**。CLI 只在业务包用。

## 验证

```bash
dart run flutter_core:new page _smoke --dry-run     # 仅打印计划，不落地
```

文件生成后检查：
- VM 是否 `extends ViewModelNotifier<...>` 或 `extends _$Foo with ViewModelMixin<...>`
- Page 是否用 `AppXxxScaffold`，**不**是裸 `Scaffold`
- Provider 是否 `NotifierProvider.autoDispose<...>`（手写） 或 `@riverpod`（generator）
- 测试是否 `createVmTestHarness()`

## 如果 CLI 不够用

- 缺一种模板（比如"加个 settings page 模板"），看 `package/flutter_core/.cursor/skills/flutter-core-add-lint/SKILL.md` 同源思路：在 `lib/src/cli/templates/` 加模板 + 在 `lib/src/cli/commands/` 加命令 + 在 `bin/new.dart` 注册。
- 模板编辑细则见 [`package/flutter_core/.cursor/rules/cli.mdc`](mdc:package/flutter_core/.cursor/rules/cli.mdc)。
