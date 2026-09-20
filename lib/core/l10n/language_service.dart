import 'dart:async';
import 'package:flutter/material.dart';
import 'package:readmesh/data/repositories/kvs_repository.dart';
import 'package:readmesh/core/l10n/app_localizations.dart';

/// Service to manage language choice persisted locally via KVS.
/// Default is Arabic on first launch, RTL.
class LanguageService extends ChangeNotifier {
  static const _kvsKey = 'app_language';
  final KvsRepository _kvsRepo;

  String _currentCode = AppLocalizations.defaultLocale; // ar default
  bool _initialized = false;

  LanguageService(this._kvsRepo);

  String get currentCode => _currentCode;
  Locale get currentLocale => Locale(_currentCode);
  bool get isArabic => _currentCode == 'ar';
  bool get isRTL => isArabic;
  bool get initialized => _initialized;

  AppLocalizations get l10n => AppLocalizations(_currentCode);

  Future<void> init() async {
    try {
      final stored = await _kvsRepo.getString(_kvsKey);
      if (stored != null && AppLocalizations.supportedLocales.contains(stored)) {
        _currentCode = stored;
      } else {
        // First launch -> Arabic default
        _currentCode = AppLocalizations.defaultLocale;
        await _kvsRepo.setString(_kvsKey, _currentCode);
      }
    } catch (_) {
      _currentCode = AppLocalizations.defaultLocale;
    }
    _initialized = true;
    notifyListeners();
  }

  Future<void> setLanguage(String code) async {
    if (!AppLocalizations.supportedLocales.contains(code)) return;
    if (_currentCode == code) return;
    _currentCode = code;
    try {
      await _kvsRepo.setString(_kvsKey, code);
    } catch (_) {}
    notifyListeners();
  }

  Future<void> toggle() async {
    await setLanguage(isArabic ? 'en' : 'ar');
  }

  // Stream for persistence watching (optional)
  Stream<String?> watchLanguage() {
    return _kvsRepo.watchString(_kvsKey);
  }
}
