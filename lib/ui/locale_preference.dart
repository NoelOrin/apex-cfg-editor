import 'package:flutter/widgets.dart';

/// 界面语言偏好：跟随系统、简体中文、English。
enum AppLocalePreference {
  system,
  zh,
  en;

  /// FluentApp.locale：system 返回 null，交给系统 locale 解析。
  Locale? get locale => switch (this) {
    AppLocalePreference.system => null,
    AppLocalePreference.zh => const Locale('zh'),
    AppLocalePreference.en => const Locale('en'),
  };

  /// settings.json 的稳定字符串值。
  String get raw => name;
}

/// 解析持久化语言值；缺失或非法值回退到跟随系统。
AppLocalePreference appLocalePreferenceFromRaw(String? raw) => switch (raw) {
  'zh' => AppLocalePreference.zh,
  'en' => AppLocalePreference.en,
  _ => AppLocalePreference.system,
};

/// 语言偏好作用域：应用壳持有真实状态，设置页读取并触发切换。
class LocalePreferenceScope extends InheritedWidget {
  final AppLocalePreference preference;
  final ValueChanged<AppLocalePreference> onChanged;

  const LocalePreferenceScope({
    super.key,
    required this.preference,
    required this.onChanged,
    required super.child,
  });

  static LocalePreferenceScope? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<LocalePreferenceScope>();

  @override
  bool updateShouldNotify(LocalePreferenceScope oldWidget) =>
      oldWidget.preference != preference || oldWidget.onChanged != onChanged;
}
