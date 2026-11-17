import 'package:hive/hive.dart';

part 'RoomBooking.g.dart'; // 🔥 MUST
@HiveType(typeId: 0)
class RoomBooking extends HiveObject {

  @HiveField(0)
  String roomName;

  @HiveField(1)
  String status;

  @HiveField(2)
  String? customerName;

  @HiveField(3)
  String? cnic;

  @HiveField(4)
  int? advance;   // ✅ int karo

  @HiveField(5)
  int? days;

  @HiveField(6)
  String? customerPhone;

  @HiveField(7)
  String? address;

  @HiveField(8)
  String? carNumber;

  @HiveField(9)
  int? rent;

  @HiveField(10)
  String? date;

  @HiveField(11)
  String? time;

  @HiveField(12)
  String? duration;

  @HiveField(13)
  String? stayType;

  @HiveField(14)
  String? checkIn;

  @HiveField(15)
  String? checkOut;


  @HiveField(16) // next available number use karo
  int? dailyRent;



  // ✅ int karo

  RoomBooking({
    required this.roomName,
    this.status = "available",
    this.customerName,
    this.cnic,
    this.advance,
    this.checkIn,
    this.checkOut,
    this.dailyRent,

  });
}