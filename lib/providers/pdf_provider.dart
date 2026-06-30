import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:ember/services/pdf_service.dart';

/// The PDF text-extraction service (stateless; safe to share).
final pdfServiceProvider = Provider<PdfService>((ref) => const PdfService());
