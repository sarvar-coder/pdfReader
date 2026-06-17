import 'package:flutter/material.dart';

import 'screens/library_screen.dart';
import 'services/storage.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final storage = Storage();
  await storage.init();
  runApp(ReadmeApp(storage: storage));
}

class ReadmeApp extends StatelessWidget {
  final Storage storage;
  const ReadmeApp({super.key, required this.storage});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Readme',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorSchemeSeed: Colors.indigo,
        brightness: Brightness.light,
        useMaterial3: true,
      ),
      darkTheme: ThemeData(
        colorSchemeSeed: Colors.indigo,
        brightness: Brightness.dark,
        useMaterial3: true,
      ),
      themeMode: ThemeMode.system,
      home: LibraryScreen(storage: storage),
    );
  }
}
