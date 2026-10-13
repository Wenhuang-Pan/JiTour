// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'transaction.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class TransactionAdapter extends TypeAdapter<Transaction> {
  @override
  final int typeId = 0;

  @override
  Transaction read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return Transaction(
      id: fields[0] as String,
      amount: fields[1] as Decimal,
      isIncome: fields[2] as bool,
      category: fields[3] as String,
      account: fields[4] as String,
      date: fields[5] as DateTime,
      note: fields[6] as String?,
      deletedAt: fields[7] as DateTime?,
      tags: fields[8] as String?,
      subCategory: fields[9] as String?,
      currency: fields[10] as String?,
      account2: fields[11] as String?,
      isReimbursed: fields[12] as bool,
      fee: fields[13] as Decimal?,
      coupon: fields[14] as Decimal?,
      locationName: fields[15] as String?,
      latitude: fields[16] as double?,
      longitude: fields[17] as double?,
    );
  }

  @override
  void write(BinaryWriter writer, Transaction obj) {
    writer
      ..writeByte(18)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.amount)
      ..writeByte(2)
      ..write(obj.isIncome)
      ..writeByte(3)
      ..write(obj.category)
      ..writeByte(4)
      ..write(obj.account)
      ..writeByte(5)
      ..write(obj.date)
      ..writeByte(6)
      ..write(obj.note)
      ..writeByte(7)
      ..write(obj.deletedAt)
      ..writeByte(8)
      ..write(obj.tags)
      ..writeByte(9)
      ..write(obj.subCategory)
      ..writeByte(10)
      ..write(obj.currency)
      ..writeByte(11)
      ..write(obj.account2)
      ..writeByte(12)
      ..write(obj.isReimbursed)
      ..writeByte(13)
      ..write(obj.fee)
      ..writeByte(14)
      ..write(obj.coupon)
      ..writeByte(15)
      ..write(obj.locationName)
      ..writeByte(16)
      ..write(obj.latitude)
      ..writeByte(17)
      ..write(obj.longitude);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TransactionAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
