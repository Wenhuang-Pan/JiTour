import 'package:uuid/uuid.dart';

class UuidUtil {
  UuidUtil._();

  static const _uuid = Uuid();

  static String generate() {
    return _uuid.v4();
  }
}
