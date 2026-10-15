// GENERATED CODE - DO NOT MODIFY BY HAND
// 金额字段 read 已手动改为 parseDecimal 兼容旧 double 数据，勿重新 build_runner 覆盖

part of 'transaction_template.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class TransactionTemplateAdapter extends TypeAdapter<TransactionTemplate> {
  @override
  final int typeId = 11;

  @override
  TransactionTemplate read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return TransactionTemplate(
      id: fields[0] as String,
      name: fields[1] as String,
      amount: fields[2] == null ? null : parseDecimal(fields[2]),
      isIncome: fields[3] as bool,
      category: fields[4] as String,
      account: fields[5] as String,
      note: fields[6] as String?,
      tags: fields[7] as String?,
      createdAt: fields[8] as DateTime?,
      updatedAt: fields[9] as DateTime?,
    );
  }

  @override
  void write(BinaryWriter writer, TransactionTemplate obj) {
    writer
      ..writeByte(10)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.name)
      ..writeByte(2)
      ..write(obj.amount)
      ..writeByte(3)
      ..write(obj.isIncome)
      ..writeByte(4)
      ..write(obj.category)
      ..writeByte(5)
      ..write(obj.account)
      ..writeByte(6)
      ..write(obj.note)
      ..writeByte(7)
      ..write(obj.tags)
      ..writeByte(8)
      ..write(obj.createdAt)
      ..writeByte(9)
      ..write(obj.updatedAt);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TransactionTemplateAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
