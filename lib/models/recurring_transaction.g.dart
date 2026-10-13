// GENERATED CODE - DO NOT MODIFY BY HAND
// 金额字段 read 已手动改为 parseDecimal 兼容旧 double 数据，勿重新 build_runner 覆盖

part of 'recurring_transaction.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class RecurringTransactionAdapter extends TypeAdapter<RecurringTransaction> {
  @override
  final int typeId = 7;

  @override
  RecurringTransaction read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return RecurringTransaction(
      id: fields[0] as String,
      name: fields[1] as String,
      isIncome: fields[2] as bool,
      amount: parseDecimal(fields[3]),
      category: fields[4] as String,
      subCategory: fields[5] as String?,
      account: fields[6] as String,
      account2: fields[7] as String?,
      currency: fields[8] as String,
      frequency: fields[9] as String,
      startDate: fields[10] as DateTime,
      endDate: fields[11] as DateTime?,
      isEnabled: fields[12] as bool,
      lastExecutedDate: fields[13] as DateTime?,
      nextExecutionDate: fields[14] as DateTime?,
      note: fields[15] as String?,
      createdAt: fields[16] as DateTime?,
      updatedAt: fields[17] as DateTime?,
    );
  }

  @override
  void write(BinaryWriter writer, RecurringTransaction obj) {
    writer
      ..writeByte(18)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.name)
      ..writeByte(2)
      ..write(obj.isIncome)
      ..writeByte(3)
      ..write(obj.amount)
      ..writeByte(4)
      ..write(obj.category)
      ..writeByte(5)
      ..write(obj.subCategory)
      ..writeByte(6)
      ..write(obj.account)
      ..writeByte(7)
      ..write(obj.account2)
      ..writeByte(8)
      ..write(obj.currency)
      ..writeByte(9)
      ..write(obj.frequency)
      ..writeByte(10)
      ..write(obj.startDate)
      ..writeByte(11)
      ..write(obj.endDate)
      ..writeByte(12)
      ..write(obj.isEnabled)
      ..writeByte(13)
      ..write(obj.lastExecutedDate)
      ..writeByte(14)
      ..write(obj.nextExecutionDate)
      ..writeByte(15)
      ..write(obj.note)
      ..writeByte(16)
      ..write(obj.createdAt)
      ..writeByte(17)
      ..write(obj.updatedAt);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is RecurringTransactionAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
