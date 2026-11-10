import 'package:flutter/material.dart';

/// Initials on a colour picked from the name, the same in every list.
class ContactAvatar extends StatelessWidget {
  const ContactAvatar({super.key, required this.label, this.radius = 20});

  final String label;
  final double radius;

  static String initialsOf(String name) {
    final List<String> parts = name
        .split(RegExp(r'\s+'))
        .where((String p) => p.isNotEmpty && RegExp(r'[A-Za-z]').hasMatch(p[0]))
        .toList();
    if (parts.isEmpty) return '';
    return (parts.first[0] + (parts.length > 1 ? parts.last[0] : ''))
        .toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final List<(Color, Color)> palette = <(Color, Color)>[
      (scheme.primaryContainer, scheme.onPrimaryContainer),
      (scheme.secondaryContainer, scheme.onSecondaryContainer),
      (scheme.tertiaryContainer, scheme.onTertiaryContainer),
    ];
    final (Color bg, Color fg) =
        palette[label.codeUnits.fold<int>(0, (int a, int b) => a + b) %
            palette.length];
    final String initials = initialsOf(label);
    return CircleAvatar(
      radius: radius,
      backgroundColor: bg,
      foregroundColor: fg,
      child: initials.isEmpty
          ? Icon(Icons.person_outline, size: radius)
          : Text(
              initials,
              style: TextStyle(
                fontSize: radius * 0.8,
                fontWeight: FontWeight.w600,
              ),
            ),
    );
  }
}
