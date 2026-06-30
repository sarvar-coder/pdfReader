import 'package:flutter/material.dart';
import 'package:hive/hive.dart';

/// A saved highlight (a colored quote pulled from a book). Persisted in Hive
/// (typeId 1).
class Highlight {
  Highlight({
    required this.id,
    required this.bookId,
    required this.quote,
    required this.colorValue,
    required this.page,
    required this.chapter,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  final String id;
  final String bookId;
  final String quote;

  /// ARGB int of the swatch color (one of the four highlight colors).
  final int colorValue;
  final int page;
  final String chapter;
  final DateTime createdAt;

  Color get color => Color(colorValue);

  /// Human-friendly relative time, e.g. "2 days ago".
  String get age {
    final d = DateTime.now().difference(createdAt);
    if (d.inDays >= 1) return '${d.inDays} day${d.inDays == 1 ? '' : 's'} ago';
    if (d.inHours >= 1) return '${d.inHours} hr${d.inHours == 1 ? '' : 's'} ago';
    if (d.inMinutes >= 1) return '${d.inMinutes} min ago';
    return 'Just now';
  }
}

/// Manual Hive adapter for [Highlight].
class HighlightAdapter extends TypeAdapter<Highlight> {
  @override
  final int typeId = 1;

  @override
  Highlight read(BinaryReader reader) {
    final count = reader.readByte();
    final fields = <int, dynamic>{
      for (var i = 0; i < count; i++) reader.readByte(): reader.read(),
    };
    return Highlight(
      id: fields[0] as String,
      bookId: fields[1] as String,
      quote: fields[2] as String,
      colorValue: fields[3] as int,
      page: fields[4] as int,
      chapter: fields[5] as String,
      createdAt: fields[6] as DateTime?,
    );
  }

  @override
  void write(BinaryWriter writer, Highlight obj) {
    writer
      ..writeByte(7)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.bookId)
      ..writeByte(2)
      ..write(obj.quote)
      ..writeByte(3)
      ..write(obj.colorValue)
      ..writeByte(4)
      ..write(obj.page)
      ..writeByte(5)
      ..write(obj.chapter)
      ..writeByte(6)
      ..write(obj.createdAt);
  }
}
