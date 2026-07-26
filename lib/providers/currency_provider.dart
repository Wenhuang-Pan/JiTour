import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

// ignore_for_file: constant_identifier_names
enum CurrencyOption {
  cny,
  usd,
  eur,
  jpy,
}

class CurrencyProvider extends ChangeNotifier {
  CurrencyOption _currency = CurrencyOption.cny;
  late SharedPreferences _prefs;

  CurrencyOption get currency => _currency;

  String get symbol {
    switch (_currency) {
      case CurrencyOption.cny:
        return '¥';
      case CurrencyOption.usd:
        return '\$';
      case CurrencyOption.eur:
        return '€';
      case CurrencyOption.jpy:
        return '¥';
    }
  }

  String get code {
    switch (_currency) {
      case CurrencyOption.cny:
        return 'CNY';
      case CurrencyOption.usd:
        return 'USD';
      case CurrencyOption.eur:
        return 'EUR';
      case CurrencyOption.jpy:
        return 'JPY';
    }
  }

  String get name {
    switch (_currency) {
      case CurrencyOption.cny:
        return '人民币';
      case CurrencyOption.usd:
        return '美元';
      case CurrencyOption.eur:
        return '欧元';
      case CurrencyOption.jpy:
        return '日元';
    }
  }

  int get decimalDigits {
    switch (_currency) {
      case CurrencyOption.jpy:
        return 0;
      default:
        return 2;
    }
  }

  Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
    _loadPreferences();
  }

  void _loadPreferences() {
    final index = _prefs.getInt('currency') ?? 0;
    _currency = CurrencyOption.values[index];
  }

  Future<void> setCurrency(CurrencyOption currency) async {
    _currency = currency;
    await _prefs.setInt('currency', currency.index);
    notifyListeners();
  }

  String formatAmount(double amount) {
    return '$symbol${amount.toStringAsFixed(decimalDigits)}';
  }

  String formatAmountCompact(double amount) {
    if (amount >= 10000 && _currency == CurrencyOption.cny) {
      return '$symbol${(amount / 10000).toStringAsFixed(1)}万';
    } else if (amount >= 10000) {
      return '$symbol${(amount / 1000).toStringAsFixed(_currency == CurrencyOption.jpy ? 0 : 1)}k';
    } else if (amount >= 1000) {
      return '$symbol${(amount / 1000).toStringAsFixed(_currency == CurrencyOption.jpy ? 0 : 1)}k';
    }
    return formatAmount(amount);
  }

  String getCurrencySymbol(CurrencyOption option) {
    switch (option) {
      case CurrencyOption.cny:
        return '¥';
      case CurrencyOption.usd:
        return '\$';
      case CurrencyOption.eur:
        return '€';
      case CurrencyOption.jpy:
        return '¥';
    }
  }
}
