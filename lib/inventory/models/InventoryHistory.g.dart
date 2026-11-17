// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'InventoryHistory.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class InventoryHistoryAdapter extends TypeAdapter<InventoryHistory> {
  @override
  final int typeId = 51;

  @override
  InventoryHistory read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return InventoryHistory(
      itemName: fields[0] as String,
      qty: fields[1] as double,
      unit: fields[2] as String,
      type: fields[3] as String,
      date: fields[4] as DateTime,
      orderNo: fields[5] as String?,
    );
  }

  @override
  void write(BinaryWriter writer, InventoryHistory obj) {
    writer
      ..writeByte(6)
      ..writeByte(0)
      ..write(obj.itemName)
      ..writeByte(1)
      ..write(obj.qty)
      ..writeByte(2)
      ..write(obj.unit)
      ..writeByte(3)
      ..write(obj.type)
      ..writeByte(4)
      ..write(obj.date)
      ..writeByte(5)
      ..write(obj.orderNo);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is InventoryHistoryAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
