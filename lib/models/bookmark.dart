import 'package:hive/hive.dart';

/// A saved bookmark pointing at a page in a book. Persisted in Hive (typeId 2).
class Bookmark {
  Bookmark({
    required this.id,
    required this.bookId,
    required this.page,
    required this.chapter,
    required this.note,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  final String id;
  final String bookId;
  final int page;
  final String chapter;
  final String note;
  final DateTime createdAt;
}

/// Manual Hive adapter for [Bookmark].
class BookmarkAdapter extends TypeAdapter<Bookmark> {
  @override
  final int typeId = 2;

  @override
  Bookmark read(BinaryReader reader) {
    final count = reader.readByte();
    final fields = <int, dynamic>{
      for (var i = 0; i < count; i++) reader.readByte(): reader.read(),
    };
    return Bookmark(
      id: fields[0] as String,
      bookId: fields[1] as String,
      page: fields[2] as int,
      chapter: fields[3] as String,
      note: fields[4] as String,
      createdAt: fields[5] as DateTime?,
    );
  }

  @override
  void write(BinaryWriter writer, Bookmark obj) {
    writer
      ..writeByte(6)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.bookId)
      ..writeByte(2)
      ..write(obj.page)
      ..writeByte(3)
      ..write(obj.chapter)
      ..writeByte(4)
      ..write(obj.note)
      ..writeByte(5)
      ..write(obj.createdAt);
  }
}
