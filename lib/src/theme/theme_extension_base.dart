import 'package:flutter/material.dart';

/// 所有业务自定义主题扩展的公共基类（marker class）。
///
/// 业务包（如 flutter_wallet）定义自己的颜色扩展：
/// ```dart
/// class WalletColors extends AppThemeExtension<WalletColors> {
///   final Color upColor;
///   final Color downColor;
///   final Color fundingColor;
///
///   const WalletColors({
///     required this.upColor,
///     required this.downColor,
///     required this.fundingColor,
///   });
///
///   @override
///   WalletColors copyWith({Color? upColor, Color? downColor, Color? fundingColor}) =>
///       WalletColors(
///         upColor: upColor ?? this.upColor,
///         downColor: downColor ?? this.downColor,
///         fundingColor: fundingColor ?? this.fundingColor,
///       );
///
///   @override
///   WalletColors lerp(ThemeExtension<WalletColors>? other, double t) {
///     if (other is! WalletColors) return this;
///     return WalletColors(
///       upColor: Color.lerp(upColor, other.upColor, t)!,
///       downColor: Color.lerp(downColor, other.downColor, t)!,
///       fundingColor: Color.lerp(fundingColor, other.fundingColor, t)!,
///     );
///   }
/// }
/// ```
///
/// 然后在 ThemeData 中注册：
/// ```dart
/// ThemeData(extensions: [WalletColors(upColor: ..., ...)])
/// ```
///
/// 页面中取色：
/// ```dart
/// context.ext<WalletColors>().upColor
/// ```
abstract class AppThemeExtension<T extends ThemeExtension<T>>
    extends ThemeExtension<T> {
  const AppThemeExtension();
}

/// [ThemeData] 扩展：类型安全地取 [ThemeExtension]。
extension ThemeDataX on ThemeData {
  /// 取已注册的主题扩展，未注册时抛出（开发期快速发现错误）。
  T ext<T extends ThemeExtension<T>>() => extension<T>()!;

  /// 取已注册的主题扩展，未注册时返回 null（可选场景）。
  T? extOrNull<T extends ThemeExtension<T>>() => extension<T>();
}

/// [BuildContext] 扩展：直接从 context 取色，省略 `Theme.of(context)`。
extension BuildContextThemeX on BuildContext {
  ThemeData get theme => Theme.of(this);

  T ext<T extends ThemeExtension<T>>() => Theme.of(this).extension<T>()!;

  T? extOrNull<T extends ThemeExtension<T>>() =>
      Theme.of(this).extension<T>();
}
