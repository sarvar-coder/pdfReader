import 'package:flutter/material.dart';
import 'package:hive/hive.dart';

/// A book in the library. Persisted in Hive (typeId 0). Covers are drawn as a
/// two-color gradient until real PDF thumbnails arrive (Phase 3); the PDF file
/// itself lives at `<docs>/books/<id>.pdf`, derived from [id].
class Book {
  Book({
    required this.id,
    required this.title,
    required this.author,
    required this.currentPage,
    required this.totalPages,
    required this.gradientColors,
    this.chapter,
    DateTime? addedAt,
  }) : addedAt = addedAt ?? DateTime.now();

  /// Stable unique id; also names the PDF file on disk.
  final String id;
  final String title;
  final String author;
  final int currentPage;
  final int totalPages;

  /// Two ARGB ints painted top-left → bottom-right behind the cover title.
  final List<int> gradientColors;

  /// Optional chapter label shown on the continue card / reader chrome.
  final String? chapter;

  /// When the book was added to the library (used for "recently added" sort).
  final DateTime addedAt;

  /// Cover gradient as [Color]s for painting.
  List<Color> get gradient =>
      gradientColors.map((c) => Color(c)).toList(growable: false);

  /// Reading progress in the range 0.0–1.0.
  double get progress => totalPages == 0 ? 0 : currentPage / totalPages;

  /// True once any page past the first has been reached.
  bool get inProgress => currentPage > 0 && currentPage < totalPages;

  Book copyWith({
    String? title,
    String? author,
    int? currentPage,
    int? totalPages,
    List<int>? gradientColors,
    String? chapter,
  }) {
    return Book(
      id: id,
      title: title ?? this.title,
      author: author ?? this.author,
      currentPage: currentPage ?? this.currentPage,
      totalPages: totalPages ?? this.totalPages,
      gradientColors: gradientColors ?? this.gradientColors,
      chapter: chapter ?? this.chapter,
      addedAt: addedAt,
    );
  }
}

/// Manual Hive adapter (no codegen — `hive_generator` is incompatible with the
/// analyzer version pulled in by Riverpod 3).
class BookAdapter extends TypeAdapter<Book> {
  @override
  final int typeId = 0;

  @override
  Book read(BinaryReader reader) {
    final count = reader.readByte();
    final fields = <int, dynamic>{
      for (var i = 0; i < count; i++) reader.readByte(): reader.read(),
    };
    return Book(
      id: fields[0] as String,
      title: fields[1] as String,
      author: fields[2] as String,
      currentPage: fields[3] as int,
      totalPages: fields[4] as int,
      gradientColors: (fields[5] as List).cast<int>(),
      chapter: fields[6] as String?,
      addedAt: fields[7] as DateTime?,
    );
  }

  @override
  void write(BinaryWriter writer, Book obj) {
    writer
      ..writeByte(8)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.title)
      ..writeByte(2)
      ..write(obj.author)
      ..writeByte(3)
      ..write(obj.currentPage)
      ..writeByte(4)
      ..write(obj.totalPages)
      ..writeByte(5)
      ..write(obj.gradientColors)
      ..writeByte(6)
      ..write(obj.chapter)
      ..writeByte(7)
      ..write(obj.addedAt);
  }
}
