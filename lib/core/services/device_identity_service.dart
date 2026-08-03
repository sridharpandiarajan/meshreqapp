import 'package:hive_flutter/hive_flutter.dart';
import 'package:uuid/uuid.dart';

class DeviceIdentityService {
  static const String _boxName = 'device_identity_box';
  static const String _uuidKey = 'device_uuid';

  static Future<void> init() async {
    await Hive.initFlutter();
    await Hive.openBox(_boxName);
  }

  static String getOrCreateDeviceUUID() {
    final box = Hive.box(_boxName);
    String? uuid = box.get(_uuidKey);

    if (uuid == null) {
      uuid = const Uuid().v4();
      box.put(_uuidKey, uuid);
    }
    return uuid;
  }
}