// GENERATED CODE - DO NOT MODIFY BY HAND
// 金额字段 read 已手动改为 parseDecimal 兼容旧 double 数据，勿重新 build_runner 覆盖

part of 'savings_goal.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class SavingsGoalAdapter extends TypeAdapter<SavingsGoal> {
  @override
  final int typeId = 5;

  @override
  SavingsGoal read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return SavingsGoal(
      id: fields[0] as String,
      name: fields[1] as String,
      description: fields[2] as String?,
      targetAmount: parseDecimal(fields[3]),
      currentAmount: fields[4] == null ? null : parseDecimal(fields[4]),
      iconName: fields[5] as String,
      colorValue: fields[6] as int,
      startDate: fields[7] as DateTime,
      targetDate: fields[8] as DateTime?,
      isCompleted: fields[9] as bool,
      createdAt: fields[10] as DateTime?,
      updatedAt: fields[11] as DateTime?,
      accountId: fields[12] as String?,
    );
  }

  @override
  void write(BinaryWriter writer, SavingsGoal obj) {
    writer
      ..writeByte(13)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.name)
      ..writeByte(2)
      ..write(obj.description)
      ..writeByte(3)
      ..write(obj.targetAmount)
      ..writeByte(4)
      ..write(obj.currentAmount)
      ..writeByte(5)
      ..write(obj.iconName)
      ..writeByte(6)
      ..write(obj.colorValue)
      ..writeByte(7)
      ..write(obj.startDate)
      ..writeByte(8)
      ..write(obj.targetDate)
      ..writeByte(9)
      ..write(obj.isCompleted)
      ..writeByte(10)
      ..write(obj.createdAt)
      ..writeByte(11)
      ..write(obj.updatedAt)
      ..writeByte(12)
      ..write(obj.accountId);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SavingsGoalAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
