import 'package:flutter/material.dart';

/// A 38×38 tappable square used across the reader and notes chrome.
class IconBtn extends StatelessWidget {
  const IconBtn({super.key, required this.child, this.onTap});

  final Widget child;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: SizedBox(
        width: 38,
        height: 38,
        child: Center(child: child),
      ),
    );
  }
}
