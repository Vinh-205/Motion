import 'package:cam_bien_te_nga/services/device_safety_bridge.dart';
import 'package:flutter/services.dart';

class FakeDeviceSafetyBridge extends DeviceSafetyBridge {
  FakeDeviceSafetyBridge() {
    available = true;
  }
  final calls = <String>[];
  final soundRequests = <bool>[];
  final previewRequests = <bool>[];
  String soundTitle = 'Âm báo thức mặc định';
  String? nextSoundTitle;
  bool rejectSoundPreview = false;
  @override
  Future<Map<String, dynamic>?> alertSound({bool pick = false}) async {
    if (pick) {
      calls.add('pickAlertSound');
      if (nextSoundTitle == null) return null;
      soundTitle = nextSoundTitle!;
    }
    return {'title': soundTitle};
  }

  @override
  Future<void> previewAlertSound(bool active) async {
    if (rejectSoundPreview) {
      throw PlatformException(
        code: 'not_ready',
        message: 'Cảnh báo đang phát.',
      );
    }
    previewRequests.add(active);
  }

  @override
  Future<void> setLocalAlertSound(
    bool active, {
    bool continuous = false,
  }) async {
    soundRequests.add(active);
  }

  @override
  Future<bool> saveContacts(List<Map<String, String>> contacts) async {
    if (!saveSucceeds) return false;
    data['contacts'] = contacts;
    data['contactName'] = contacts.firstOrNull?['name'] ?? '';
    data['contactPhone'] = contacts.firstOrNull?['phone'] ?? '';
    return true;
  }

  bool saveSucceeds = true;
  String? enableError;
  String? callEnableError;
  int sendRequests = 0;
  Map<String, dynamic>? selectedContact;
  final data = <String, dynamic>{
    'running': false,
    'enabled': false,
    'dryRun': false,
    'monitoring': true,
    'countdownSeconds': 30,
    'sensitivity': 'medium',
    'ownerName': '',
    'contactName': '',
    'contactPhone': '',
    'pending': false,
    'deadline': 0,
    'remainingMilliseconds': 0,
    'eventAt': 0,
    'sosActive': false,
    'smsStatus': '',
    'sosMessage': '',
    'detectorState': 0,
    'events': <Map<String, dynamic>>[],
    'locationPermission': false,
    'notificationPermission': false,
  };
  @override
  Future<Map<String, dynamic>?> state() async => Map.of(data);
  @override
  Future<bool> saveContact(String name, String phone) async {
    if (!saveSucceeds) return false;
    data['contactName'] = name;
    data['contactPhone'] = phone;
    return true;
  }

  @override
  Future<Map<String, dynamic>?> pickContact() async {
    calls.add('pickContact');
    return selectedContact;
  }

  @override
  Future<Map<String, dynamic>> command(
    String method, [
    Map<String, dynamic>? args,
  ]) async {
    calls.add(method);
    switch (method) {
      case 'requestSmsPermission':
        data['smsPermission'] = enableError == null;
      case 'resetAlertSound':
        soundTitle = 'Chuông SOS Motion · mặc định';
        return {'title': soundTitle, 'custom': false};
      case 'setAutoCall':
        if (callEnableError != null) {
          throw PlatformException(
            code: 'call_denied',
            message: callEnableError,
          );
        }
        data['autoCallEnabled'] = args?['enabled'] == true;
        data['callPermission'] = args?['enabled'] == true;
      case 'enableRealSms':
        if (enableError != null) {
          throw PlatformException(code: 'sms_denied', message: enableError);
        }
        data.addAll({...?args, 'enabled': true, 'running': true});
      case 'disableRealSms':
        data.addAll({
          'enabled': false,
          'running': false,
          'pending': false,
          'sosActive': false,
        });
      case 'configure':
        data.addAll(args ?? {});
      case 'beginDemo':
        if (data['pending'] == true) {
          throw PlatformException(
            code: 'real_alert_active',
            message: 'Có cảnh báo thật đang chờ xử lý.',
          );
        }
      case 'manualSos':
        if (data['sosActive'] != true) {
          sendRequests++;
          data.addAll({
            'pending': false,
            'sosActive': true,
            'smsStatus': 'sending',
            'sosMessage': 'Đang yêu cầu gửi SMS.',
          });
          (data['events'] as List).insert(0, {
            'id': '$sendRequests',
            'at': DateTime.now().millisecondsSinceEpoch,
            'source': 'manual',
            'outcome': 'sos',
            'smsStatus': 'sending',
            'detail': 'Đang yêu cầu gửi SMS.',
          });
        }
      case 'confirmSafe':
        data['pending'] = false;
      case 'dismissSos':
        data['sosActive'] = false;
    }
    return Map.of(data);
  }
}
