import 'package:flutter/material.dart';

/// Muestra las iniciales de la cuenta sin depender de una imagen remota.
class UserAvatar extends StatelessWidget {
  const UserAvatar({
    required this.displayName,
    required this.email,
    required this.radius,
    required this.backgroundColor,
    required this.foregroundColor,
    super.key,
  });

  final String? displayName;
  final String? email;
  final double radius;
  final Color backgroundColor;
  final Color foregroundColor;

  String get _initials {
    final name = displayName?.trim();
    if (name != null && name.isNotEmpty) {
      final parts = name.split(RegExp(r'\s+'));
      final first = parts.first.substring(0, 1);
      return parts.length > 1 ? '$first${parts.last.substring(0, 1)}' : first;
    }

    final emailName = email?.trim().split('@').first;
    if (emailName != null && emailName.isNotEmpty) {
      return emailName.substring(0, 1).toUpperCase();
    }

    return 'U';
  }

  @override
  Widget build(BuildContext context) {
    return CircleAvatar(
      radius: radius,
      backgroundColor: backgroundColor,
      foregroundColor: foregroundColor,
      child: Text(
        _initials,
        style: TextStyle(fontSize: radius * 0.65, fontWeight: FontWeight.w700),
      ),
    );
  }
}
