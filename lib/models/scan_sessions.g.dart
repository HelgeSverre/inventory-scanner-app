// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'scan_sessions.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class ScanItemAdapter extends TypeAdapter<ScanItem> {
  @override
  final int typeId = 0;

  @override
  ScanItem read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return ScanItem(
      barcode: fields[0] as String,
      barcodeType: fields[1] as String,
      timestamp: fields[2] as DateTime,
      productName: fields[3] as String?,
      currentStock: fields[4] as int?,
    );
  }

  @override
  void write(BinaryWriter writer, ScanItem obj) {
    writer
      ..writeByte(5)
      ..writeByte(0)
      ..write(obj.barcode)
      ..writeByte(1)
      ..write(obj.barcodeType)
      ..writeByte(2)
      ..write(obj.timestamp)
      ..writeByte(3)
      ..write(obj.productName)
      ..writeByte(4)
      ..write(obj.currentStock);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ScanItemAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class ScanSessionAdapter extends TypeAdapter<ScanSession> {
  @override
  final int typeId = 1;

  @override
  ScanSession read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return ScanSession(
      id: fields[0] as String,
      name: fields[1] as String,
      startedAt: fields[2] as DateTime,
      finishedAt: fields[3] as DateTime?,
      scans: (fields[4] as List?)?.cast<ScanItem>(),
      isSynced: fields[5] as bool,
      lastError: fields[6] as String?,
      lastSyncAttempt: fields[7] as DateTime?,
    );
  }

  @override
  void write(BinaryWriter writer, ScanSession obj) {
    writer
      ..writeByte(8)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.name)
      ..writeByte(2)
      ..write(obj.startedAt)
      ..writeByte(3)
      ..write(obj.finishedAt)
      ..writeByte(4)
      ..write(obj.scans)
      ..writeByte(5)
      ..write(obj.isSynced)
      ..writeByte(6)
      ..write(obj.lastError)
      ..writeByte(7)
      ..write(obj.lastSyncAttempt);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ScanSessionAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
