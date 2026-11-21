import 'package:flutter/widgets.dart';

import '../../l10n/app_localizations.dart';
import '../../l10n/app_localizations_en.dart';

/// Localized strings with an English fallback.
///
/// Widget tests pump plain `MaterialApp`s that carry no localization delegates;
/// they deliberately get English instead of failing on a null lookup. The app
/// root installs the generated delegates, so production always uses the active
/// locale.
extension AppLocalizationsContext on BuildContext {
  AppLocalizations get l10n =>
      Localizations.of<AppLocalizations>(this, AppLocalizations) ??
      AppLocalizationsEn();
}
