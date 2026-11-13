import 'package:flutter/material.dart';

/// Presenta el logo oficial de TaskFlow en los flujos de inicio y acceso.
class TaskFlowLogo extends StatelessWidget {
  const TaskFlowLogo({required this.size, super.key});

  final double size;

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      'taskflow2.png',
      key: const ValueKey('taskflow-logo'),
      width: size,
      height: size,
      fit: BoxFit.contain,
      semanticLabel: 'Logo de TaskFlow',
    );
  }
}
