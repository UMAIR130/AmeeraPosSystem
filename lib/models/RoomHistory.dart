import 'package:hive/hive.dart';

part 'RoomHistory.g.dart';

@HiveType(typeId: 8)
class RoomHistory extends HiveObject {

  @HiveField(0)
  String roomName;

  @HiveField(1)
  String? customerName;

  @HiveField(2)
  String? phone;

  @HiveField(3)
  String? cnic;

  @HiveField(4)
  String? address;

  @HiveField(5)
  String? carNumber;

  @HiveField(6)
  int rent;

  @HiveField(7)
  int advance;

  @HiveField(8)
  int remaining;

  @HiveField(9)
  String? stayType;

  @HiveField(10)
  String? checkIn;

  @HiveField(11)
  String? checkOut;

  @HiveField(12)
  int refund;


  RoomHistory({
    required this.roomName,
    this.customerName,
    this.phone,
    this.cnic,
    this.address,
    this.carNumber,
    required this.rent,
    required this.advance,
    required this.remaining,
    this.stayType,
    this.checkIn,
    this.checkOut,
    this.refund = 0,
  });
}