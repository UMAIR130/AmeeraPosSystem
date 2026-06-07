// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'RoomBooking.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class RoomBookingAdapter extends TypeAdapter<RoomBooking> {
  @override
  final int typeId = 0;

  @override
  RoomBooking read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return RoomBooking(
      roomName: fields[0] as String,
      status: fields[1] as String,
      customerName: fields[2] as String?,
      cnic: fields[3] as String?,
      advance: fields[4] as int?,
      days: fields[5] as int?,
      checkIn: fields[14] as String?,
    )
      ..customerPhone = fields[6] as String?
      ..address = fields[7] as String?
      ..carNumber = fields[8] as String?
      ..rent = fields[9] as int?
      ..date = fields[10] as String?
      ..time = fields[11] as String?
      ..duration = fields[12] as String?
      ..stayType = fields[13] as String?;
  }

  @override
  void write(BinaryWriter writer, RoomBooking obj) {
    writer
      ..writeByte(15)
      ..writeByte(0)
      ..write(obj.roomName)
      ..writeByte(1)
      ..write(obj.status)
      ..writeByte(2)
      ..write(obj.customerName)
      ..writeByte(3)
      ..write(obj.cnic)
      ..writeByte(4)
      ..write(obj.advance)
      ..writeByte(5)
      ..write(obj.days)
      ..writeByte(6)
      ..write(obj.customerPhone)
      ..writeByte(7)
      ..write(obj.address)
      ..writeByte(8)
      ..write(obj.carNumber)
      ..writeByte(9)
      ..write(obj.rent)
      ..writeByte(10)
      ..write(obj.date)
      ..writeByte(11)
      ..write(obj.time)
      ..writeByte(12)
      ..write(obj.duration)
      ..writeByte(13)
      ..write(obj.stayType)
      ..writeByte(14)
      ..write(obj.checkIn);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is RoomBookingAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
