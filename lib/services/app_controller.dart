import 'dart:async';
import 'dart:collection';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../models/detection_config.dart';
import '../models/fall_event.dart';
import '../models/emergency_contact.dart';
import 'device_safety_bridge.dart';
import 'fall_detector.dart';
import 'sensor_service.dart';
import 'sos_service.dart';

class AppController extends ChangeNotifier {
  AppController({
    SensorService? sensors,
    DateTime Function()? now,
    DeviceSafetyBridge? device,
    this.allowSimulation = false,
  }) : sensors = sensors ?? SensorService(),
       now = now ?? DateTime.now,
       device = device ?? DeviceSafetyBridge();
  final SensorService sensors;
  final DateTime Function() now;
  final DeviceSafetyBridge device;
  final bool allowSimulation;
  bool get canSimulate => !kReleaseMode && allowSimulation;
  final detector = FallDetector();
  final sosService = SosService();
  final _events = <FallEvent>[];
  List<FallEvent> _deviceEvents = [];
  UnmodifiableListView<FallEvent> get events {
    final combined =
        [..._events, ..._deviceEvents]
            .where(
              (e) => canSimulate || (!e.simulated && e.smsStatus != 'dryRun'),
            )
            .toList()
          ..sort((a, b) => b.at.compareTo(a.at));
    return UnmodifiableListView(combined.take(200).toList());
  }

  final _elapsed = Stopwatch();
  Timer? _timer;
  bool _started = false,
      _disposed = false,
      _polling = false,
      _nativeBusy = false,
      _savingContact = false;
  bool _nativeAlert = false, _demoActive = false, _startingDemo = false;
  int _nativeRevision = 0;
  DateTime? _lastNativePoll;
  bool monitoring = true, foreground = true, sosActive = false;
  bool realSmsEnabled = false, nativeConfigured = false, sosIsSimulation = true;
  bool nativeSensorReady = false;
  bool fullScreenAllowed = false,
      batteryUnrestricted = false,
      simReady = false,
      hasRequiredSensors = false;
  int alarmVolume = 0;
  bool hasGyroscope = true, smsPermissionNeedsSettings = false;
  String sensorMode = 'full';
  String deviceModel = '', androidVersion = '';
  double sensorSampleHz = 0;
  double impactThreshold = 22;
  bool backgroundEnabled = true;
  String detectionDetail = '', lastDetectionRejection = '';
  bool get backgroundMonitoring =>
      realSmsEnabled && monitoring && backgroundEnabled;
  bool get backgroundReady =>
      backgroundMonitoring &&
      nativeSensorReady &&
      smsPermission &&
      notificationPermission &&
      simReady &&
      hasRequiredSensors &&
      nativeSensorError.isEmpty;
  bool smsPermission = false,
      locationPermission = false,
      notificationPermission = false;
  String ownerName = '', deviceError = '', nativeSensorError = '';
  bool autoCallEnabled = false, callPermission = false;
  String callStatus = '', callDetail = '';
  int countdownSeconds = 30;
  Sensitivity sensitivity = Sensitivity.medium;
  String contactName = '', contactPhone = '', sosMessage = '';
  List<EmergencyContact> _contacts = [];
  List<EmergencyContact> get contacts => List.unmodifiable(_contacts);
  String get recipientSummary => _contacts.isEmpty
      ? 'Chưa có người liên hệ'
      : _contacts.length == 1
      ? '${_contacts.first.name} · ${_contacts.first.phone}'
      : '${_contacts.length} liên hệ khẩn cấp';
  DateTime? _deadline, _eventAt, _cooldownUntil, _lastUi;
  EventSource? pendingSource;
  int _processed = -1;
  bool get alertActive => pendingSource != null;
  bool get sensorReady => sensors.fresh(now());
  bool get alertIsSimulation =>
      pendingSource == EventSource.demo || !realSmsEnabled;
  int get remainingSeconds => _deadline == null
      ? 0
      : ((_deadline!.difference(now()).inMilliseconds / 1000).ceil()).clamp(
          0,
          countdownSeconds,
        );

  void start() {
    if (_started) return;
    _started = true;
    _elapsed.start();
    sensors.addListener(_onSensor);
    if ((monitoring || !canSimulate) && foreground) sensors.start();
    unawaited(refreshDevice());
    _timer = Timer.periodic(const Duration(milliseconds: 200), (_) => tick());
  }

  void _onSensor() {
    if (canSimulate &&
        !realSmsEnabled &&
        monitoring &&
        foreground &&
        !alertActive &&
        !sosActive &&
        (_cooldownUntil == null || !now().isBefore(_cooldownUntil!)) &&
        sensors.accelerationSequence != _processed &&
        sensors.acceleration != null) {
      _processed = sensors.accelerationSequence;
      final gyroFresh =
          sensors.rotationAt != null &&
          sensors.error == null &&
          now().difference(sensors.rotationAt!).inMilliseconds <= 250;
      detector.update(
        at: _elapsed.elapsed,
        magnitude: sensors.acceleration!.magnitude,
        rotation: sensors.rotation?.magnitude ?? 0,
        gyroFresh: gyroFresh,
      );
      if (detector.state == FallState.fallSuspected) {
        _beginAlert(EventSource.sensor);
      }
    }
    if (_lastUi == null || now().difference(_lastUi!).inMilliseconds >= 100) {
      _lastUi = now();
      notifyListeners();
    }
  }

  void tick() {
    if (!_nativeAlert &&
        alertActive &&
        _deadline != null &&
        !now().isBefore(_deadline!)) {
      requestHelp();
      return;
    }
    if (!realSmsEnabled &&
        monitoring &&
        !sensorReady &&
        !alertActive &&
        !sosActive) {
      detector.reset();
    }
    if (_lastNativePoll == null ||
        DateTime.now().difference(_lastNativePoll!).inMilliseconds >= 500) {
      unawaited(refreshDevice());
    }
    notifyListeners();
  }

  Future<void> refreshDevice() async {
    if (_disposed || _polling || _nativeBusy || !device.available) return;
    _polling = true;
    _lastNativePoll = DateTime.now();
    final revision = _nativeRevision;
    try {
      final state = await device.state();
      if (!_disposed && revision == _nativeRevision && state != null) {
        _applyDevice(state);
        notifyListeners();
      }
    } on PlatformException catch (e) {
      if (!_disposed) {
        deviceError = e.message ?? 'Không đọc được trạng thái Android.';
      }
    } finally {
      _polling = false;
    }
  }

  void _applyDevice(Map<String, dynamic> state) {
    final wasReal = realSmsEnabled;
    nativeConfigured = state['enabled'] == true;
    backgroundEnabled = state['backgroundEnabled'] as bool? ?? true;
    detectionDetail = state['detectionDetail'] as String? ?? '';
    lastDetectionRejection = state['lastDetectionRejection'] as String? ?? '';
    autoCallEnabled = state['autoCallEnabled'] == true;
    callPermission = state['callPermission'] == true;
    callStatus = state['callStatus'] as String? ?? '';
    callDetail = state['callDetail'] as String? ?? '';
    realSmsEnabled =
        nativeConfigured && state['running'] == true && state['dryRun'] != true;
    smsPermission = state['smsPermission'] == true;
    smsPermissionNeedsSettings = state['smsPermissionNeedsSettings'] == true;
    hasGyroscope = state['hasGyroscope'] as bool? ?? true;
    sensorMode = state['sensorMode'] as String? ?? 'full';
    deviceModel = state['deviceModel'] as String? ?? '';
    androidVersion = state['androidVersion'] as String? ?? '';
    sensorSampleHz = (state['sensorSampleHz'] as num?)?.toDouble() ?? 0;
    impactThreshold = (state['impactThreshold'] as num?)?.toDouble() ?? 22;
    sensors.hasGyroscope = hasGyroscope;
    locationPermission = state['locationPermission'] == true;
    notificationPermission = state['notificationPermission'] == true;
    fullScreenAllowed = state['fullScreenAllowed'] == true;
    batteryUnrestricted = state['batteryUnrestricted'] == true;
    simReady = state['simReady'] == true;
    hasRequiredSensors = state['hasRequiredSensors'] == true;
    alarmVolume = (state['alarmVolume'] as num?)?.toInt() ?? 0;
    nativeSensorError = state['sensorError'] as String? ?? '';
    nativeSensorReady = state['sensorReady'] == true;
    // Native service remains the detector owner. Show its real readings when available,
    // including uncalibrated gyro hardware not exposed by the Flutter plugin.
    if (realSmsEnabled && monitoring) {
      Vector3? vector(dynamic value) => value is List && value.length == 3
          ? Vector3(
              (value[0] as num).toDouble(),
              (value[1] as num).toDouble(),
              (value[2] as num).toDouble(),
            )
          : null;
      final acceleration = vector(state['nativeAcceleration']);
      if (acceleration != null && nativeSensorReady) {
        sensors.acceleration = acceleration;
        sensors.accelerationAt = now();
        sensors.rotation = vector(state['nativeRotation']);
        if (sensors.rotation != null) {
          sensors.rotationAt = now();
          sensors.rotationWarning = null;
        }
        sensors.error = null;
      }
    }
    if (!_savingContact) {
      contactName = state['contactName'] as String? ?? contactName;
      contactPhone = state['contactPhone'] as String? ?? contactPhone;
      final raw = state['contacts'] as List?;
      _contacts = raw != null
          ? raw
                .map(
                  (e) => EmergencyContact.fromMap(
                    Map<String, dynamic>.from(e as Map),
                  ),
                )
                .toList()
          : contactPhone.isEmpty
          ? []
          : [
              EmergencyContact(
                id: 'legacy',
                name: contactName,
                phone: contactPhone,
              ),
            ];
    }
    ownerName = state['ownerName'] as String? ?? ownerName;
    final startupError = state['startupError'] as String? ?? '';
    if (startupError.isNotEmpty) deviceError = startupError;
    if (nativeConfigured && state['running'] != true) deviceError = 'Dịch vụ SOS đã dừng. Vào Cài đặt và bật lại SOS qua SIM để giám sát nền.';
    _deviceEvents = ((state['events'] as List?) ?? [])
        .map((e) => FallEvent.fromDevice(Map<String, dynamic>.from(e as Map)))
        .toList();
    if (realSmsEnabled) {
      countdownSeconds =
          ((state['countdownSeconds'] as num?)?.toInt() ?? countdownSeconds)
              .clamp(15, 30);
      final level = state['sensitivity'];
      sensitivity = Sensitivity.values.firstWhere(
        (s) => s.name == level,
        orElse: () => sensitivity,
      );
      monitoring = state['monitoring'] as bool? ?? monitoring;
      if (!_demoActive) {
        _nativeAlert = state['pending'] == true;
        pendingSource = _nativeAlert ? EventSource.sensor : null;
        final remaining = (state['remainingMilliseconds'] as num?)?.toInt();
        _deadline = _nativeAlert
            ? remaining != null
                  ? now().add(Duration(milliseconds: remaining))
                  : DateTime.fromMillisecondsSinceEpoch(
                      (state['deadline'] as num).toInt(),
                    )
            : null;
        _eventAt = DateTime.fromMillisecondsSinceEpoch(
          (state['eventAt'] as num?)?.toInt() ?? 0,
        );
        sosActive = state['sosActive'] == true;
        sosIsSimulation = false;
        sosMessage = state['sosMessage'] as String? ?? '';
        detector.state =
            FallState.values[((state['detectorState'] as num?)?.toInt() ?? 0)
                .clamp(0, 4)];
      }
    } else if (wasReal && !_demoActive) {
      _nativeAlert = false;
      pendingSource = null;
      _deadline = null;
      detector.reset();
    }
  }

  Future<String?> enableRealSms(String name) async {
    if (_nativeBusy) return 'Đang xử lý một thao tác Android.';
    _nativeBusy = true;
    _nativeRevision++;
    deviceError = '';
    try {
      final state = await device.command('enableRealSms', {
        ..._configuration,
        'ownerName': name.trim(),
      });
      if (_disposed) return null;
      _applyDevice(state);
      return realSmsEnabled
          ? null
          : 'Dịch vụ chưa chạy. Hãy kiểm tra quyền và bật lại.';
    } on PlatformException catch (e) {
      deviceError = e.message ?? 'Không bật được SOS thật.';
      return deviceError;
    } on MissingPluginException {
      deviceError = 'Hãy cài bản Android mới để dùng SOS qua SIM.';
      return deviceError;
    } finally {
      _nativeBusy = false;
      if (!_disposed) notifyListeners();
    }
  }

  Future<void> disableRealSms() => _nativeCommand('disableRealSms');
  Future<void> requestSmsPermission() => _nativeCommand('requestSmsPermission');
  Future<String?> setAutoCall(bool enabled) async {
    await _nativeCommand('setAutoCall', {'enabled': enabled});
    return deviceError.isEmpty ? null : deviceError;
  }

  Future<bool> setCallPriority(String id) async {
    if (_savingContact) return false;
    final chosen = _contacts.where((c) => c.id == id).firstOrNull;
    if (chosen == null) return false;
    return _saveContacts([chosen, ..._contacts.where((c) => c.id != id)]);
  }

  Future<void> startBackgroundMonitoring() async {
    if (!realSmsEnabled) return;
    await _nativeCommand('configure', {
      ..._configuration,
      'monitoring': true,
      'backgroundEnabled': true,
    });
  }

  Future<void> setBackgroundMonitoring(bool value) async {
    if (realSmsEnabled) {
      await _nativeCommand('configure', {
        ..._configuration,
        'backgroundEnabled': value,
      });
    } else {
      backgroundEnabled = value;
      notifyListeners();
    }
  }

  Future<void> openFullScreenSettings() =>
      _nativeCommand('openFullScreenSettings');
  Future<void> openAppSettings() => _nativeCommand('openAppSettings');
  Future<void> leaveToHome() async {
    if (backgroundReady) await _nativeCommand('leaveToHome');
  }

  Map<String, dynamic> get _configuration => {
    'monitoring': monitoring,
    'backgroundEnabled': backgroundEnabled,
    'countdownSeconds': countdownSeconds,
    'sensitivity': sensitivity.name,
  };
  Future<void> _nativeCommand(
    String method, [
    Map<String, dynamic>? args,
  ]) async {
    if (!device.available) return;
    _nativeRevision++;
    try {
      final state = await device.command(method, args);
      if (!_disposed) {
        _applyDevice(state);
        deviceError = '';
        notifyListeners();
      }
    } on PlatformException catch (e) {
      if (!_disposed) {
        deviceError = e.message ?? 'Thao tác Android chưa hoàn tất.';
        if (method == 'manualSos') {
          sosMessage = 'Chưa yêu cầu gửi được SMS. $deviceError';
        }
        notifyListeners();
      }
    } on MissingPluginException {
      device.available = false;
    }
  }

  void _beginAlert(EventSource source) {
    if (alertActive || sosActive) return;
    pendingSource = source;
    _eventAt = now();
    _deadline = now().add(Duration(seconds: countdownSeconds));
    _nativeAlert = false;
    unawaited(device.setLocalAlertSound(true));
    notifyListeners();
  }

  void simulate() {
    if (!canSimulate) return;
    if (alertActive || sosActive || _startingDemo) return;
    if (realSmsEnabled) {
      unawaited(_startIsolatedDemo());
      return;
    }
    _demoActive = true;
    detector.simulate();
    _beginAlert(EventSource.demo);
  }

  Future<void> _startIsolatedDemo() async {
    _startingDemo = true;
    try {
      await device.command('beginDemo');
      if (!_disposed) {
        _demoActive = true;
        detector.simulate();
        _beginAlert(EventSource.demo);
      }
    } on PlatformException catch (e) {
      if (!_disposed) {
        deviceError = e.message ?? 'Không bắt đầu được mô phỏng.';
        notifyListeners();
      }
    } finally {
      _startingDemo = false;
    }
  }

  void _endDemo() {
    final wasDemo = _demoActive;
    _demoActive = false;
    if (wasDemo && realSmsEnabled) unawaited(_nativeCommand('endDemo'));
  }

  void confirmSafe() {
    if (!alertActive) return;
    if (_nativeAlert) {
      pendingSource = null;
      _deadline = null;
      _nativeAlert = false;
      unawaited(_nativeCommand('confirmSafe'));
      notifyListeners();
      return;
    }
    _record(EventOutcome.safe);
    _resetAfterEvent();
    _endDemo();
    notifyListeners();
  }

  void requestHelp() {
    if (sosActive) return;
    if (!realSmsEnabled && !canSimulate) {
      deviceError = 'SOS chưa sẵn sàng. Hãy thiết lập liên hệ, SIM và quyền gửi SMS trước.';
      notifyListeners();
      return;
    }
    if (realSmsEnabled && !_demoActive) {
      sosActive = true;
      sosIsSimulation = false;
      pendingSource = null;
      _deadline = null;
      _nativeAlert = false;
      sosMessage = 'Đang yêu cầu gửi cảnh báo qua SIM.';
      unawaited(_nativeCommand('manualSos'));
      notifyListeners();
      return;
    }
    pendingSource ??= EventSource.manual;
    _eventAt ??= now();
    _record(EventOutcome.sos);
    _deadline = null;
    pendingSource = null;
    sosActive = true;
    sosIsSimulation = true;
    unawaited(device.setLocalAlertSound(true, continuous: true));
    sosMessage = sosService.activate(
      contactName: contactName,
      phone: contactPhone,
      recipients: _contacts.map((c) => '${c.name} · ${c.phone}').toList(),
    );
    notifyListeners();
  }

  void _record(EventOutcome outcome) {
    _events.insert(
      0,
      FallEvent(
        at: _eventAt ?? now(),
        source: pendingSource!,
        outcome: outcome,
        reason: pendingSource == EventSource.demo
            ? 'Người dùng chạy mô phỏng té ngã.'
            : pendingSource == EventSource.manual
            ? 'Người dùng chủ động nhấn SOS.'
            : 'Chuỗi bất thường → va chạm → xoay → ít chuyển động ngắn (0,6–1,5 giây tùy mức).',
        recipientName: contactName,
        recipientPhone: contactPhone,
        countdownSeconds: countdownSeconds,
        sensitivity: sensitivity.name,
        recipients: _contacts
            .map(
              (c) => {
                'name': c.name,
                'phone': c.phone,
                'smsStatus': 'dryRun',
                'detail': 'Mô phỏng, không gửi SMS.',
              },
            )
            .toList(),
      ),
    );
    if (_events.length > 200) _events.removeLast();
  }

  void _resetAfterEvent() {
    if (!_nativeAlert) unawaited(device.setLocalAlertSound(false));
    pendingSource = null;
    _deadline = null;
    _eventAt = null;
    detector.reset();
    _cooldownUntil = now().add(DetectionConfig.cooldown);
  }

  void dismissSos() {
    sosActive = false;
    _resetAfterEvent();
    if (!sosIsSimulation && realSmsEnabled) {
      unawaited(_nativeCommand('dismissSos'));
    }
    _endDemo();
    notifyListeners();
  }

  void setMonitoring(bool value) {
    if (!realSmsEnabled && !canSimulate) {
      deviceError = 'Hãy thiết lập SOS qua SIM để bật giám sát nền.';
      notifyListeners();
      return;
    }
    monitoring = value;
    detector.reset();
    if ((value || !canSimulate) && foreground) {
      sensors.start();
    } else {
      sensors.stop();
    }
    if (realSmsEnabled) unawaited(_nativeCommand('configure', _configuration));
    notifyListeners();
  }

  void setForeground(bool value) {
    foreground = value;
    if (value) unawaited(refreshDevice());
    if (!_nativeAlert) {
      unawaited(
        device.setLocalAlertSound(
          value && (alertActive || (sosActive && sosIsSimulation)),
          continuous: sosActive && sosIsSimulation,
        ),
      );
    }
    detector.reset();
    if (value && (monitoring || !canSimulate)) {
      sensors.start();
    } else {
      sensors.stop();
    }
    // Native real monitoring continues; only the foreground UI sensor subscriptions stop.
    tick();
  }

  void setCountdown(int value) {
    countdownSeconds = value.clamp(15, 30);
    if (realSmsEnabled) unawaited(_nativeCommand('configure', _configuration));
    notifyListeners();
  }

  void setSensitivity(Sensitivity value) {
    sensitivity = value;
    detector.config = DetectionConfig.forSensitivity(value);
    detector.reset();
    if (realSmsEnabled) unawaited(_nativeCommand('configure', _configuration));
    notifyListeners();
  }

  Future<bool> saveContact(String name, String phone, {String? id}) async {
    if (_savingContact) return false;
    final nextName = name.trim(), nextPhone = normalizePhone(phone);
    if (nextName.isEmpty || !validEmergencyPhone(nextPhone)) return false;
    if (_contacts.any(
      (c) =>
          c.id != id &&
          emergencyPhoneKey(c.phone) == emergencyPhoneKey(nextPhone),
    )) {
      deviceError = 'Số điện thoại này đã có trong danh sách.';
      notifyListeners();
      return false;
    }
    if (id == null && _contacts.length >= 10) {
      deviceError = 'Tối đa 10 liên hệ khẩn cấp.';
      notifyListeners();
      return false;
    }
    final contact = EmergencyContact(
      id:
          id ??
          'c${List.generate(4, (_) => Random.secure().nextInt(0x100000000).toRadixString(16).padLeft(8, '0')).join()}',
      name: nextName,
      phone: nextPhone,
    );
    final next = id == null
        ? [..._contacts, contact]
        : _contacts.map((c) => c.id == id ? contact : c).toList();
    return _saveContacts(next);
  }

  Future<bool> removeContact(String id) async {
    if (_savingContact) return false;
    if (_contacts.length == 1 && realSmsEnabled) {
      deviceError = 'Tắt SOS qua SIM trước khi xóa liên hệ cuối cùng.';
      notifyListeners();
      return false;
    }
    return _saveContacts(_contacts.where((c) => c.id != id).toList());
  }

  Future<bool> _saveContacts(List<EmergencyContact> next) async {
    _nativeRevision++;
    _savingContact = true;
    notifyListeners();
    try {
      final saved = await device.saveContacts(
        next.map((c) => c.toMap()).toList(),
      );
      if (!_disposed && saved) {
        _contacts = next;
        contactName = next.firstOrNull?.name ?? '';
        contactPhone = next.firstOrNull?.phone ?? '';
        deviceError = '';
        notifyListeners();
      }
      return saved;
    } on PlatformException catch (e) {
      if (!_disposed) deviceError = e.message ?? 'Không lưu được liên hệ.';
      return false;
    } on MissingPluginException {
      if (!_disposed) {
        deviceError =
            'Hãy dừng và chạy lại bản Android mới để lưu danh sách liên hệ.';
      }
      return false;
    } finally {
      _savingContact = false;
    }
  }

  @override
  void dispose() {
    if (!_nativeAlert) unawaited(device.setLocalAlertSound(false));
    _disposed = true;
    _timer?.cancel();
    _elapsed.stop();
    sensors.removeListener(_onSensor);
    sensors.dispose();
    super.dispose();
  }
}
