import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

extension BuildContextX on BuildContext {
  /// 是否可以安全调用 pop。
  bool get canSafePop => Navigator.of(this).canPop();

  /// 安全 pop：无历史时返回 false，不抛异常。
  bool safePop<T extends Object?>([T? result]) {
    if (!canSafePop) return false;
    Navigator.of(this).pop(result);
    return true;
  }

  /// 替换整个导航栈到目标路由（用于"回主页"等场景）。
  void replaceAllWith(String location) {
    while (canSafePop) {
      Navigator.of(this).pop();
    }
    go(location);
  }

  // ──────── MediaQuery 快捷 ────────

  Size get screenSize => MediaQuery.sizeOf(this);
  double get screenWidth => screenSize.width;
  double get screenHeight => screenSize.height;

  EdgeInsets get viewPadding => MediaQuery.viewPaddingOf(this);
  EdgeInsets get viewInsets => MediaQuery.viewInsetsOf(this);

  /// 安全区下边距（如底部 home indicator）。
  double get bottomSafeArea => viewPadding.bottom;

  /// 键盘高度。
  double get keyboardHeight => viewInsets.bottom;
  bool get isKeyboardVisible => keyboardHeight > 0;

  // ──────── Theme 快捷 ────────

  ThemeData get theme => Theme.of(this);
  TextTheme get textTheme => theme.textTheme;
  ColorScheme get colorScheme => theme.colorScheme;
  bool get isDark => theme.brightness == Brightness.dark;
}
