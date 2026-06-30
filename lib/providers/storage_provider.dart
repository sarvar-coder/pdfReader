import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:ember/services/storage_service.dart';

/// Exposes the initialized [StorageService]. The real instance is created in
/// `main()` and injected via a `ProviderScope` override, so this default only
/// runs if that wiring is missing.
final storageServiceProvider = Provider<StorageService>((ref) {
  throw UnimplementedError(
    'storageServiceProvider must be overridden in main() with '
    'StorageService.init().',
  );
});
