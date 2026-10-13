import 'package:decimal/decimal.dart';
import 'package:hive/hive.dart';

/// 金额精度工具：十进制精确运算与 Hive 序列化
///
/// WHY: double 存在二进制浮点误差（0.1+0.2≠0.3），金融场景必须用 Decimal。
/// Hive 默认不支持 Decimal，通过本文件的 [DecimalAdapter] 序列化为 String 存储。

/// 将动态值安全转换为 Decimal，兼容旧数据中存储的 double/int
///
/// WHY: 历史 Hive 数据金额以 double 存储，升级后读取时需无损转换。
/// 用 `raw.toString()` 而非 `Decimal.fromDouble(raw)`，因为 fromDouble 可能
/// 引入额外二进制浮点展开（如 0.1 → 0.10000000000000000555...），
/// toString() 得到的是 Dart 已舍入的十进制表示，更符合用户感知。
///
/// @param raw 可能是 double、int、String、Decimal 或 null
/// @return 转换后的 Decimal；无法识别时返回 Decimal.zero
Decimal parseDecimal(dynamic raw) {
  if (raw == null) return Decimal.zero;
  if (raw is Decimal) return raw;
  if (raw is int) return Decimal.fromInt(raw);
  if (raw is double) {
    // WHY: double.toString() 会输出最短十进制表示（如 0.1 而非 0.10000...02），
    // 再 Decimal.parse 可得到与用户输入一致的精确值
    return Decimal.parse(raw.toString());
  }
  if (raw is String) {
    if (raw.isEmpty) return Decimal.zero;
    return Decimal.tryParse(raw) ?? Decimal.zero;
  }
  return Decimal.zero;
}

/// 金额格式化：统一两位小数输出
///
/// @param value 金额
/// @return 如 "100.00"、"10.50"
String formatMoney(Decimal value) {
  return value.toStringAsFixed(2);
}

/// Hive 类型适配器：Decimal ↔ String
///
/// WHY: Hive 默认不识别 Decimal，注册后 writer.write(decimal) 会自动调用此适配器。
/// 新数据存 String（如 "10.50"），旧数据（double）由模型的 parseDecimal 兼容读取。
class DecimalAdapter extends TypeAdapter<Decimal> {
  @override
  final int typeId = 100;

  @override
  Decimal read(BinaryReader reader) {
    final raw = reader.read();
    return parseDecimal(raw);
  }

  @override
  void write(BinaryWriter writer, Decimal obj) {
    writer.write(obj.toString());
  }
}
