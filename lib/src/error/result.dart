import 'app_exception.dart';

/// 显式的成功 / 失败容器。作为 `throw AppException` 的**补充**（不是替代）。
///
/// 使用场景：
///   * 不想写 try/catch，但又想区分"成功 / 失败"两条路径；
///   * 表单校验：多个规则并行校验，每个规则返回 `Result<Unit>`；
///   * ViewModel 里对 Repository 调用用 `.toResult()` 统一处理。
///
/// throw 仍是主通道（Repository 出口必须 `safeApiCall` 归一成 [AppException]）；
/// [Result] 只在需要显式分支的地方用。
sealed class Result<T> {
  const Result();
}

/// 成功。
final class Ok<T> extends Result<T> {
  const Ok(this.value);
  final T value;

  @override
  bool operator ==(Object other) =>
      identical(this, other) || (other is Ok<T> && value == other.value);

  @override
  int get hashCode => value.hashCode;

  @override
  String toString() => 'Ok($value)';
}

/// 失败。
final class Err<T> extends Result<T> {
  const Err(this.error);
  final AppException error;

  @override
  bool operator ==(Object other) =>
      identical(this, other) || (other is Err<T> && error == other.error);

  @override
  int get hashCode => error.hashCode;

  @override
  String toString() => 'Err($error)';
}

/// [Result] 的便捷访问扩展。
extension ResultX<T> on Result<T> {
  bool get isOk => this is Ok<T>;
  bool get isErr => this is Err<T>;

  /// 失败时返回 null。
  T? get valueOrNull => switch (this) {
        Ok(:final value) => value,
        Err() => null,
      };

  /// 成功时返回 null。
  AppException? get errorOrNull => switch (this) {
        Ok() => null,
        Err(:final error) => error,
      };

  /// 把两种分支各映射成 [R] 再合并。
  R fold<R>(
    R Function(T value) onOk,
    R Function(AppException error) onErr,
  ) =>
      switch (this) {
        Ok(:final value) => onOk(value),
        Err(:final error) => onErr(error),
      };
}

/// 把 `Future<T>` 转成 `Future<Result<T>>`，不 throw。
///
/// 捕获策略：
///   * [AppException] → 包成 [Err]；
///   * 其他异常 → 包成 [Err]（payload 为 [UnknownException]，保留 stackTrace）。
///
/// 这样 VM 里业务代码即使忘记走 `safeApiCall`，也不会有未捕获异常泄漏到 Zone。
extension FutureResultX<T> on Future<T> {
  Future<Result<T>> toResult() async {
    try {
      return Ok(await this);
    } on AppException catch (e) {
      return Err(e);
    } catch (e, st) {
      return Err(UnknownException(
        message: e.toString(),
        raw: e,
        stackTrace: st,
      ));
    }
  }
}
