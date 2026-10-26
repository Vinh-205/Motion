import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

String normalizePhone(String value) =>
    value.replaceAll(RegExp(r'[\s().-]'), '');
bool validEmergencyPhone(String value) =>
    RegExp(r'^\+?[0-9]{9,15}$').hasMatch(normalizePhone(value));
String emergencyPhoneKey(String value) {
  final phone = normalizePhone(value);
  return phone.startsWith('+84') ? '0${phone.substring(3)}' : phone;
}

class DeviceSafetyBridge {
  static const channel = MethodChannel('motion/device_safety');
  bool available = !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  Future<Map<String, dynamic>?> alertSound({bool pick = false}) async {
    if (!available) {
      throw PlatformException(
        code: 'unsupported',
        message: 'Chọn âm thanh được hỗ trợ trên Android.',
      );
    }
    final result = await channel.invokeMapMethod<String, dynamic>(
      pick ? 'pickAlertSound' : 'getAlertSound',
    );
    return result == null ? null : Map<String, dynamic>.from(result);
  }

  Future<void> previewAlertSound(bool active) async {
    if (!available) {
      throw PlatformException(
        code: 'unsupported',
        message: 'Nghe thử âm thanh được hỗ trợ trên Android.',
      );
    }
    await channel.invokeMethod<void>('previewAlertSound', {'active': active});
  }

  Future<void> setLocalAlertSound(
    bool active, {
    bool continuous = false,
  }) async {
    if (!available) return;
    try {
      await channel.invokeMethod<void>('setLocalAlertSound', {
        'active': active,
        'continuous': continuous,
      });
    } on MissingPluginException {
      // Older installed APKs do not implement local preview audio.
    } on PlatformException {
      // Sound failure must never prevent a countdown or confirmation.
    }
  }

  Future<Map<String, dynamic>?> state() async {
    if (!available) return null;
    try {
      return Map<String, dynamic>.from(
        await channel.invokeMapMethod<String, dynamic>('state') ?? {},
      );
    } on MissingPluginException {
      available = false;
      return null;
    }
  }

  Future<Map<String, dynamic>?> pickContact() async {
    if (!available) {
      throw PlatformException(
        code: 'unsupported',
        message: 'Chọn danh bạ được hỗ trợ trên Android. Bạn vẫn có thể nhập số thủ công.',
      );
    }
    try {
      final result = await channel.invokeMapMethod<String, dynamic>(
        'pickContact',
      );
      return result == null ? null : Map<String, dynamic>.from(result);
    } on MissingPluginException {
      available = false;
      throw PlatformException(
        code: 'unsupported',
        message: 'Hãy cài lại bản Android mới để dùng danh bạ.',
      );
    }
  }

  Future<bool> saveContact(String name, String phone) async {
    if (!available) return false;
    try {
      return await channel.invokeMethod<bool>('saveContact', {
            'name': name.trim(),
            'phone': normalizePhone(phone),
          }) ??
          false;
    } on MissingPluginException {
      available = false;
      return false;
    }
  }

  Future<bool> saveContacts(List<Map<String, String>> contacts) async {
    if (!available) return false;
    return await channel.invokeMethod<bool>('saveContacts', {
          'contacts': contacts,
        }) ??
        false;
  }

  Future<Map<String, dynamic>> command(
    String method, [
    Map<String, dynamic>? args,
  ]) async {
    if (!available) {
      throw PlatformException(
        code: 'unsupported',
        message: 'SOS qua SIM chỉ hỗ trợ trên Android.',
      );
    }
    final result = await channel.invokeMapMethod<String, dynamic>(method, args);
    return Map<String, dynamic>.from(result ?? {});
  }
}
