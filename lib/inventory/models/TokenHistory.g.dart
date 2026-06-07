// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'TokenHistory.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class TokenHistoryAdapter extends TypeAdapter<TokenHistory> {
  @override
  final int typeId = 28;

  @override
  TokenHistory read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return TokenHistory(
      orderId: fields[0] as String,
      orderType: fields[1] as String,
      category: fields[2] as String,
      dateTime: fields[3] as String,
      tableNumber: fields[4] as int,
      floorNumber: fields[5] as int,
      items: (fields[6] as List).cast<String>(),
      orderNumber: fields[7] as String,
    );
  }

  @override
  void write(BinaryWriter writer, TokenHistory obj) {
    writer
      ..writeByte(8)
      ..writeByte(0)
      ..write(obj.orderId)
      ..writeByte(1)
      ..write(obj.orderType)
      ..writeByte(2)
      ..write(obj.category)
      ..writeByte(3)
      ..write(obj.dateTime)
      ..writeByte(4)
      ..write(obj.tableNumber)
      ..writeByte(5)
      ..write(obj.floorNumber)
      ..writeByte(6)
      ..write(obj.items)
      ..writeByte(7)
      ..write(obj.orderNumber);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TokenHistoryAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
