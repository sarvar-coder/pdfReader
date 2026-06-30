import 'package:hive/hive.dart';

/// A single reading session — when the user opened a book and for how long.
/// Persisted in Hive (typeId 3). The streak and stats screens are derived from
/// these in Phase 5; the model is defined now so the box exists from Phase 2.
class ReadingSession {
  ReadingSession({
    required this.id,
    required this.bookId,
    required this.startedAt,
    this.endedAt,
    this.pagesRead = 0,
    this.minutes = 0,
  });

  final String id;
  final String bookId;
  final DateTime startedAt;
  final DateTime? endedAt;
  final int pagesRead;
  final int minutes;
}

/// Manual Hive adapter for [ReadingSession].
class ReadingSessionAdapter extends TypeAdapter<ReadingSession> {
  @override
  final int typeId = 3;

  @override
  ReadingSession read(BinaryReader reader) {
    final count = reader.readByte();
    final fields = <int, dynamic>{
      for (var i = 0; i < count; i++) reader.readByte(): reader.read(),
    };
    return ReadingSession(
      id: fields[0] as String,
      bookId: fields[1] as String,
      startedAt: fields[2] as DateTime,
      endedAt: fields[3] as DateTime?,
      pagesRead: fields[4] as int,
      minutes: fields[5] as int,
    );
  }

  @override
  void write(BinaryWriter writer, ReadingSession obj) {
    writer
      ..writeByte(6)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.bookId)
      ..writeByte(2)
      ..write(obj.startedAt)
      ..writeByte(3)
      ..write(obj.endedAt)
      ..writeByte(4)
      ..write(obj.pagesRead)
      ..writeByte(5)
      ..write(obj.minutes);
  }
}
