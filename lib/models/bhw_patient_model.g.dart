// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'bhw_patient_model.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class BHWPatientAdapter extends TypeAdapter<BHWPatient> {
  @override
  final int typeId = 1;

  @override
  BHWPatient read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return BHWPatient(
      id: fields[0] as String,
      name: fields[1] as String,
      age: fields[2] as int,
      sex: fields[3] as String,
      barangay: fields[4] as String,
      purok: fields[5] as String?,
      contactNumber: fields[6] as String?,
      isDiabetic: fields[7] as bool,
      diabeticStatus: fields[8] as String,
      symptoms: (fields[9] as List).cast<String>(),
      symptomResponses: (fields[10] as Map).cast<String, bool>(),
      additionalNotes: fields[11] as String?,
      riskLevel: fields[12] as String,
      scanImagePath: fields[13] as String?,
      scanImageUrl: fields[14] as String?,
      scanDate: fields[15] as DateTime,
      confidenceScore: fields[16] as double?,
      scannedByBHWId: fields[17] as String,
      scannedByBHWName: fields[18] as String,
      scannedByBHWBarangay: fields[19] as String,
      recommendation: fields[20] as String,
      urgency: fields[21] as String,
      referredToClinic: fields[22] as bool,
      referredClinicName: fields[23] as String?,
      isSyncedToFirestore: fields[24] as bool,
      lastSyncedAt: fields[25] as DateTime?,
      firestoreDocId: fields[26] as String?,
      createdAt: fields[27] as DateTime,
      updatedAt: fields[28] as DateTime,
    );
  }

  @override
  void write(BinaryWriter writer, BHWPatient obj) {
    writer
      ..writeByte(29)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.name)
      ..writeByte(2)
      ..write(obj.age)
      ..writeByte(3)
      ..write(obj.sex)
      ..writeByte(4)
      ..write(obj.barangay)
      ..writeByte(5)
      ..write(obj.purok)
      ..writeByte(6)
      ..write(obj.contactNumber)
      ..writeByte(7)
      ..write(obj.isDiabetic)
      ..writeByte(8)
      ..write(obj.diabeticStatus)
      ..writeByte(9)
      ..write(obj.symptoms)
      ..writeByte(10)
      ..write(obj.symptomResponses)
      ..writeByte(11)
      ..write(obj.additionalNotes)
      ..writeByte(12)
      ..write(obj.riskLevel)
      ..writeByte(13)
      ..write(obj.scanImagePath)
      ..writeByte(14)
      ..write(obj.scanImageUrl)
      ..writeByte(15)
      ..write(obj.scanDate)
      ..writeByte(16)
      ..write(obj.confidenceScore)
      ..writeByte(17)
      ..write(obj.scannedByBHWId)
      ..writeByte(18)
      ..write(obj.scannedByBHWName)
      ..writeByte(19)
      ..write(obj.scannedByBHWBarangay)
      ..writeByte(20)
      ..write(obj.recommendation)
      ..writeByte(21)
      ..write(obj.urgency)
      ..writeByte(22)
      ..write(obj.referredToClinic)
      ..writeByte(23)
      ..write(obj.referredClinicName)
      ..writeByte(24)
      ..write(obj.isSyncedToFirestore)
      ..writeByte(25)
      ..write(obj.lastSyncedAt)
      ..writeByte(26)
      ..write(obj.firestoreDocId)
      ..writeByte(27)
      ..write(obj.createdAt)
      ..writeByte(28)
      ..write(obj.updatedAt);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is BHWPatientAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
