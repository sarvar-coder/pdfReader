import 'dart:async';
import 'dart:math';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:receive_sharing_intent/receive_sharing_intent.dart';

import '../models/book.dart';
import '../services/pdf_service.dart';
import '../services/storage.dart';
import 'reader_screen.dart';

class LibraryScreen extends StatefulWidget {
  final Storage storage;
  const LibraryScreen({super.key, required this.storage});

  @override
  State<LibraryScreen> createState() => LibraryScreenState();
}

class LibraryScreenState extends State<LibraryScreen> {
  List<Book> _books = [];

  /// Non-null while importing — holds a progress label like "Importing 2 of 5".
  String? _progress;

  StreamSubscription<List<SharedMediaFile>>? _shareSub;

  @override
  void initState() {
    super.initState();
    _refresh();
    _listenForSharedPdfs();
  }

  /// Handles PDFs opened/shared from other apps (Files, email, browser …),
  /// both when the app is already running and on a cold start.
  void _listenForSharedPdfs() {
    _shareSub = ReceiveSharingIntent.instance.getMediaStream().listen(_onShared);
    ReceiveSharingIntent.instance.getInitialMedia().then((files) {
      _onShared(files);
      ReceiveSharingIntent.instance.reset();
    });
  }

  void _onShared(List<SharedMediaFile> files) {
    final pdfs = files
        .where((f) =>
            f.mimeType == 'application/pdf' ||
            f.path.toLowerCase().endsWith('.pdf'))
        .map((f) => (path: f.path, name: f.path.split('/').last))
        .toList();
    if (pdfs.isNotEmpty) importFiles(pdfs);
  }

  @override
  void dispose() {
    _shareSub?.cancel();
    super.dispose();
  }

  void _refresh() => setState(() => _books = widget.storage.getBooks());

  Future<void> _pickAndImport() async {
    final result = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf'],
      allowMultiple: true,
    );
    if (result == null) return;
    final files = result.files
        .where((f) => f.path != null)
        .map((f) => (path: f.path!, name: f.name))
        .toList();
    await importFiles(files);
  }

  /// Imports a batch of PDFs with progress. Public so PDFs opened from other
  /// apps can be routed here too. Skips files with no extractable text.
  Future<void> importFiles(List<({String path, String name})> files) async {
    if (files.isEmpty || _progress != null) return;

    var imported = 0;
    var skipped = 0;
    for (var i = 0; i < files.length; i++) {
      setState(() => _progress = files.length == 1
          ? 'Importing…'
          : 'Importing ${i + 1} of ${files.length}');
      final file = files[i];
      try {
        final extracted = await PdfService.extract(file.path);
        if (!extracted.hasText) {
          skipped++;
          continue;
        }
        final book = Book(
          id: '${DateTime.now().microsecondsSinceEpoch}_${Random().nextInt(9999)}',
          title: file.name.replaceAll(RegExp(r'\.pdf$', caseSensitive: false), ''),
          content: extracted.text,
          addedAt: DateTime.now(),
        );
        await widget.storage.saveBook(book);
        imported++;
      } catch (_) {
        skipped++;
      }
    }

    if (!mounted) return;
    setState(() => _progress = null);
    _refresh();
    _showSummary(imported, skipped);
  }

  void _showSummary(int imported, int skipped) {
    final parts = <String>[];
    if (imported > 0) parts.add('$imported imported');
    if (skipped > 0) parts.add('$skipped skipped (no readable text)');
    if (parts.isEmpty) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(parts.join(' · '))));
  }

  Future<void> _openBook(Book book) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ReaderScreen(book: book, storage: widget.storage),
      ),
    );
    _refresh(); // pick up updated resume position
  }

  Future<void> _deleteBook(Book book) async {
    await widget.storage.deleteBook(book.id);
    _refresh();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Readme')),
      body: _books.isEmpty
          ? const Center(
              child: Text('No books yet.\nTap + to import PDFs.',
                  textAlign: TextAlign.center),
            )
          : ListView.separated(
              itemCount: _books.length,
              separatorBuilder: (_, i) => const Divider(height: 1),
              itemBuilder: (_, i) {
                final book = _books[i];
                return ListTile(
                  leading: const Icon(Icons.menu_book),
                  title: Text(book.title),
                  subtitle: Text(book.lastCharOffset > 0
                      ? 'Resume reading'
                      : 'Not started'),
                  onTap: () => _openBook(book),
                  trailing: IconButton(
                    icon: const Icon(Icons.delete_outline),
                    onPressed: () => _deleteBook(book),
                  ),
                );
              },
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _progress != null ? null : _pickAndImport,
        icon: _progress != null
            ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : const Icon(Icons.add),
        label: Text(_progress ?? 'Add PDF'),
      ),
    );
  }
}
