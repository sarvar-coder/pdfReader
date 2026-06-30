import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:ember/models/bookmark.dart';
import 'package:ember/providers/storage_provider.dart';

/// Saved bookmarks, backed by the Hive `bookmarks` box (lowest page first).
class BookmarksNotifier extends Notifier<List<Bookmark>> {
  @override
  List<Bookmark> build() {
    final box = ref.watch(storageServiceProvider).bookmarks;
    final list = box.values.toList()..sort((a, b) => a.page.compareTo(b.page));
    return List.unmodifiable(list);
  }

  Future<void> add(Bookmark bookmark) async {
    await ref.read(storageServiceProvider).bookmarks.put(bookmark.id, bookmark);
    ref.invalidateSelf();
  }

  Future<void> remove(String id) async {
    await ref.read(storageServiceProvider).bookmarks.delete(id);
    ref.invalidateSelf();
  }
}

final bookmarksProvider =
    NotifierProvider<BookmarksNotifier, List<Bookmark>>(BookmarksNotifier.new);
