import '../error/app_exception.dart';

/// 标准 UI 加载状态。
///
/// 业务 State 如果采用"flat class + status 字段"的模式（推荐默认），字段类型用这个枚举。
/// 如果业务偏好 sealed state / freezed union，可以不使用这个枚举——通用包不强制。
///
/// ## 五态定义
///
/// - [idle]：初始态，尚未触发加载。
/// - [loading]：**首次**加载中，通常 UI 展示全屏 loading / skeleton。
/// - [refreshing]：带有旧数据的刷新中（下拉刷新 / 背景刷新），UI 继续显示旧数据 + 小指示器。
/// - [ok]：加载成功，数据可用。
/// - [error]：加载失败，通常配合 State 里的 `AppException? error` 字段。
enum ViewStatus { idle, loading, refreshing, ok, error }

/// [ViewStatus] 的便捷判断扩展。
extension ViewStatusX on ViewStatus {
  bool get isIdle => this == ViewStatus.idle;
  bool get isLoading => this == ViewStatus.loading;
  bool get isRefreshing => this == ViewStatus.refreshing;
  bool get isOk => this == ViewStatus.ok;
  bool get isError => this == ViewStatus.error;

  /// 正在忙（首次加载或刷新中）。
  bool get isBusy => isLoading || isRefreshing;

  /// 可以展示数据（加载成功 或 刷新中仍有旧数据）。
  bool get hasData => isOk || isRefreshing;
}

/// 约定式接口——愿意用就用，**不强制**。
///
/// `AsyncPageStateView.fromStatus` 这类 UI 组件会通过 `is HasViewStatus` 判断走哪个渲染路径。
/// 业务用 freezed / sealed state 不 implement 这个接口也可以，只是要自己传 builder。
abstract mixin class HasViewStatus {
  ViewStatus get status;
  AppException? get error;
}
