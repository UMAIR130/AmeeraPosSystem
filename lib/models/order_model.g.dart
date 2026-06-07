// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'order_model.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class OrderItemAdapter extends TypeAdapter<OrderItem> {
  @override
  final int typeId = 1;

  @override
  OrderItem read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return OrderItem(
      name: fields[0] as String,
      qty: fields[1] as int,
      price: fields[2] as double,
    );
  }

  @override
  void write(BinaryWriter writer, OrderItem obj) {
    writer
      ..writeByte(3)
      ..writeByte(0)
      ..write(obj.name)
      ..writeByte(1)
      ..write(obj.qty)
      ..writeByte(2)
      ..write(obj.price);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is OrderItemAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class OrderAdapter extends TypeAdapter<Order> {
  @override
  final int typeId = 13;

  @override
  Order read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return Order(
      orderId: fields[0] as String,
      orderType: fields[1] as String,
      tableNumber: fields[2] as int?,
      floorNumber: fields[3] as int?,
      items: (fields[4] as List).cast<OrderItem>(),
      subTotal: fields[5] as double,
      service: fields[6] as double,
      discount: fields[7] as double,
      grandTotal: fields[8] as double,
      timestamp: fields[9] as DateTime,
      status: fields[10] as String,
      paymentMethod: fields[11] as String?,
      receivedAmount: fields[12] as double?,
      returnedAmount: fields[13] as double?,
      tax: fields[14] as double,
      lastPrintedCount: fields[15] as int,
      orderNumber: fields[16] as String?,
      customerName: fields[17] as String?,
      customerPhone: fields[18] as String?,
    );
  }

  @override
  void write(BinaryWriter writer, Order obj) {
    writer
      ..writeByte(19)
      ..writeByte(0)
      ..write(obj.orderId)
      ..writeByte(1)
      ..write(obj.orderType)
      ..writeByte(2)
      ..write(obj.tableNumber)
      ..writeByte(3)
      ..write(obj.floorNumber)
      ..writeByte(4)
      ..write(obj.items)
      ..writeByte(5)
      ..write(obj.subTotal)
      ..writeByte(6)
      ..write(obj.service)
      ..writeByte(7)
      ..write(obj.discount)
      ..writeByte(8)
      ..write(obj.grandTotal)
      ..writeByte(9)
      ..write(obj.timestamp)
      ..writeByte(10)
      ..write(obj.status)
      ..writeByte(11)
      ..write(obj.paymentMethod)
      ..writeByte(12)
      ..write(obj.receivedAmount)
      ..writeByte(13)
      ..write(obj.returnedAmount)
      ..writeByte(14)
      ..write(obj.tax)
      ..writeByte(15)
      ..write(obj.lastPrintedCount)
      ..writeByte(16)
      ..write(obj.orderNumber)
      ..writeByte(17)
      ..write(obj.customerName)
      ..writeByte(18)
      ..write(obj.customerPhone);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is OrderAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
