import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:ember/models/reading_session.dart';
import 'package:ember/providers/storage_provider.dart';

/// Recorded reading sessions, backed by the Hive `sessions` box. The streak and
/// stats are derived from these (see stats_provider.dart).
class ReadingSessionsNotifier extends Notifier<List<ReadingSession>> {
  @override
  List<ReadingSession> build() {
    final box = ref.watch(storageServiceProvider).sessions;
    return List.unmodifiable(box.values);
  }

  Future<void> add(ReadingSession session) async {
    await ref.read(storageServiceProvider).sessions.put(session.id, session);
    ref.invalidateSelf();
  }
}

final readingSessionsProvider =
    NotifierProvider<ReadingSessionsNotifier, List<ReadingSession>>(
  ReadingSessionsNotifier.new,
);
