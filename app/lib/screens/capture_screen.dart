import 'package:flutter/material.dart';
class CaptureScreen extends StatelessWidget {
  final String mode;
  const CaptureScreen({super.key, required this.mode});
  @override
  Widget build(BuildContext context) => Scaffold(body: Center(child: Text('Capture: $mode')));
}
