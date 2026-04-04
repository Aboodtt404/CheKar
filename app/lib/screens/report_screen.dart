import 'package:flutter/material.dart';
class ReportScreen extends StatelessWidget {
  final String inspectionId;
  const ReportScreen({super.key, required this.inspectionId});
  @override
  Widget build(BuildContext context) => const Scaffold(body: Center(child: Text('Report')));
}
