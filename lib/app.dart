import 'package:flutter/material.dart';

import 'theme/app_theme.dart';

/// Root of the Ember app: applies the theme and hosts the home screen.
class EmberApp extends StatelessWidget {
  const EmberApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Ember',
      debugShowCheckedModeBanner: false,
      theme: buildEmberTheme(),
      home: const _StartupScreen(),
    );
  }
}

/// Temporary placeholder so we can confirm the theme renders.
/// Replaced by the app shell + bottom nav in Phase 1.
class _StartupScreen extends StatelessWidget {
  const _StartupScreen();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Text('Ember', style: Theme.of(context).textTheme.displayMedium),
      ),
    );
  }
}
