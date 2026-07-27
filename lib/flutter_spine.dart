/// flutter_spine — 跨 feature 共享的基础设施。
///
/// 引入方式（业务包 pubspec.yaml 加 path 依赖后）：
///   import 'package:flutter_spine/flutter_spine.dart';
///
/// 约定：
///   * Core 不包含任何业务颜色、路由名、API 端点；
///   * DataSource / Repository 的出口必须通过 [safeApiCall] 包裹；
///   * 分页列表 Notifier 继承 [PagedNotifierMixin]，禁止 static 可变字段；
///   * Toast 回调由业务包注入到 [ErrorObserver]，Core 不依赖 toast 库。
library;

import 'flutter_spine.dart';

// ── Error ──────────────────────────────────────────────────────────────────
export 'src/error/app_exception.dart';
export 'src/error/safe_call.dart';
export 'src/error/result.dart';

// ── Effect ─────────────────────────────────────────────────────────────────
export 'src/effect/effect.dart';
export 'src/effect/effect_bus.dart';
export 'src/effect/default_effect_handler.dart';
export 'src/effect/material_default_effect_handler.dart';
export 'src/effect/effect_listener.dart';

// ── Bootstrap（一行接入 API） ─────────────────────────────────────────────
export 'src/bootstrap/flutter_spine.dart';
export 'src/bootstrap/flutter_spine_config.dart';
export 'src/bootstrap/bootstrap_audit.dart';
export 'src/bootstrap/diagnostics_banner.dart';

// ── State ──────────────────────────────────────────────────────────────────
export 'src/state/view_status.dart';
export 'src/state/view_model_notifier.dart';
export 'src/state/async_view_model_notifier.dart';
export 'src/state/view_model_mixin.dart';
export 'src/state/async_view_model_mixin.dart';

// ── Network ────────────────────────────────────────────────────────────────
export 'src/network/channel_client.dart';

// ── HTTP ───────────────────────────────────────────────────────────────────
export 'src/network/http/http_client.dart';
export 'src/network/http/http_method.dart';
export 'src/network/http/http_response.dart';
export 'src/network/http/dio_http_client.dart';
export 'src/network/http/http_interceptors.dart';
export 'src/network/http/http_retry_interceptor.dart';
export 'src/network/http/http_auth_refresh_interceptor.dart';
export 'src/network/http/multipart_file_part.dart';
export 'src/network/http/http_providers.dart';

// ── WebSocket ──────────────────────────────────────────────────────────────
export 'src/network/ws/ws_client.dart';
export 'src/network/ws/ws_connection_state.dart';
export 'src/network/ws/default_ws_client.dart';
export 'src/network/ws/ws_providers.dart';
export 'src/network/ws/base_ws_gateway.dart';
export 'src/network/ws/ws_module_registry.dart';

// ── Pagination ─────────────────────────────────────────────────────────────
export 'src/pagination/paged_state.dart';
export 'src/pagination/paged_notifier_mixin.dart';
export 'src/pagination/paged_list_view.dart';
export 'src/pagination/paged_scaffold.dart';

// ── Filter ─────────────────────────────────────────────────────────────────
export 'src/filter/filter_notifier.dart';

// ── Presentation ───────────────────────────────────────────────────────────
export 'src/presentation/async_builder.dart';
export 'src/presentation/async_value_ext.dart';
export 'src/presentation/page_state/loading_view.dart';
export 'src/presentation/page_state/empty_view.dart';
export 'src/presentation/page_state/error_view.dart';
export 'src/presentation/page_state/skeleton_builder.dart';
export 'src/presentation/page_state/async_page_state_view.dart';

// ── Logging ────────────────────────────────────────────────────────────────
export 'src/logging/app_logger.dart';
export 'src/logging/logger_impl.dart';

// ── Observers ──────────────────────────────────────────────────────────────
export 'src/observers/error_observer.dart';
export 'src/observers/log_observer.dart';

// ── Storage ────────────────────────────────────────────────────────────────
export 'src/storage/key_value_storage.dart';
export 'src/storage/hive_storage.dart';
export 'src/storage/storage_providers.dart';

// ── Theme ──────────────────────────────────────────────────────────────────
export 'src/theme/theme_extension_base.dart';
export 'src/theme/theme_mode_notifier.dart';

// ── Utils ──────────────────────────────────────────────────────────────────
export 'src/utils/num_ext.dart';
export 'src/utils/string_ext.dart';
export 'src/utils/date_ext.dart';
export 'src/utils/iterable_ext.dart';
export 'src/utils/context_ext.dart';

// ── UI (AppBar + Scaffolds) ────────────────────────────────────────────────
export 'src/ui/appbar/app_default_appbar.dart';
export 'src/ui/scaffold/app_raw_page.dart';
export 'src/ui/scaffold/app_page_scaffold.dart';
export 'src/ui/scaffold/app_list_page_scaffold.dart';
export 'src/ui/scaffold/app_form_page_scaffold.dart';
export 'src/ui/scaffold/app_bottom_sheet_scaffold.dart';
export 'src/ui/scaffold/app_tab_child_scaffold.dart';
