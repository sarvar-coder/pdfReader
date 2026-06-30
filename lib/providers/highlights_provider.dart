import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:ember/models/highlight.dart';
import 'package:ember/providers/storage_provider.dart';

/// Saved highlights, backed by the Hive `highlights` box (newest first).
class HighlightsNotifier extends Notifier<List<Highlight>> {
  @override
  List<Highlight> build() {
    final box = ref.watch(storageServiceProvider).highlights;
    final list = box.values.toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return List.unmodifiable(list);
  }

  Future<void> add(Highlight highlight) async {
    await ref.read(storageServiceProvider).highlights.put(highlight.id, highlight);
    ref.invalidateSelf();
  }

  Future<void> remove(String id) async {
    await ref.read(storageServiceProvider).highlights.delete(id);
    ref.invalidateSelf();
  }
}

final highlightsProvider =
    NotifierProvider<HighlightsNotifier, List<Highlight>>(
  HighlightsNotifier.new,
);
