// GENERATED CODE - DO NOT MODIFY BY HAND
// 金额字段 read 已手动改为 parseDecimal 兼容旧 double 数据，勿重新 build_runner 覆盖

part of 'pending_transaction.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class PendingTransactionAdapter extends TypeAdapter<PendingTransaction> {
  @override
  final int typeId = 8;

  @override
  PendingTransaction read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return PendingTransaction(
      id: fields[0] as String,
      amount: parseDecimal(fields[1]),
      source: fields[5] as PaymentSource,
      paymentTime: fields[6] as DateTime,
      rawText: fields[7] as String,
      merchant: fields[2] as String?,
      inferredCategory: fields[3] as String?,
      confidence: fields[4] as double,
      status: fields[8] as PendingStatus,
      confirmedTransactionId: fields[10] as String?,
      isIncome: fields[11] == null ? false : fields[11] as bool,
    )..createdAt = fields[9] as DateTime;
  }

  @override
  void write(BinaryWriter writer, PendingTransaction obj) {
    writer
      ..writeByte(12)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.amount)
      ..writeByte(2)
      ..write(obj.merchant)
      ..writeByte(3)
      ..write(obj.inferredCategory)
      ..writeByte(4)
      ..write(obj.confidence)
      ..writeByte(5)
      ..write(obj.source)
      ..writeByte(6)
      ..write(obj.paymentTime)
      ..writeByte(7)
      ..write(obj.rawText)
      ..writeByte(8)
      ..write(obj.status)
      ..writeByte(9)
      ..write(obj.createdAt)
      ..writeByte(10)
      ..write(obj.confirmedTransactionId)
      ..writeByte(11)
      ..write(obj.isIncome);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PendingTransactionAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class PaymentSourceAdapter extends TypeAdapter<PaymentSource> {
  @override
  final int typeId = 9;

  @override
  PaymentSource read(BinaryReader reader) {
    switch (reader.readByte()) {
      case 0:
        return PaymentSource.alipay;
      case 1:
        return PaymentSource.wechat;
      case 2:
        return PaymentSource.bank;
      default:
        return PaymentSource.alipay;
    }
  }

  @override
  void write(BinaryWriter writer, PaymentSource obj) {
    switch (obj) {
      case PaymentSource.alipay:
        writer.writeByte(0);
        break;
      case PaymentSource.wechat:
        writer.writeByte(1);
        break;
      case PaymentSource.bank:
        writer.writeByte(2);
        break;
    }
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PaymentSourceAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class PendingStatusAdapter extends TypeAdapter<PendingStatus> {
  @override
  final int typeId = 10;

  @override
  PendingStatus read(BinaryReader reader) {
    switch (reader.readByte()) {
      case 0:
        return PendingStatus.pending;
      case 1:
        return PendingStatus.confirmed;
      case 2:
        return PendingStatus.discarded;
      default:
        return PendingStatus.pending;
    }
  }

  @override
  void write(BinaryWriter writer, PendingStatus obj) {
    switch (obj) {
      case PendingStatus.pending:
        writer.writeByte(0);
        break;
      case PendingStatus.confirmed:
        writer.writeByte(1);
        break;
      case PendingStatus.discarded:
        writer.writeByte(2);
        break;
    }
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PendingStatusAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
