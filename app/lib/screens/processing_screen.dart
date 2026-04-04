import 'package:flutter/material.dart';
class ProcessingScreen extends StatelessWidget {
  final String inspectionId;
  const ProcessingScreen({super.key, required this.inspectionId});
  @override
  Widget build(BuildContext context) => const Scaffold(backgroundColor: Color(0xFF1E1E2E), body: Center(child: Text('Processing...', style: TextStyle(color: Colors.white))));
}
