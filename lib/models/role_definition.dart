import 'package:flutter/material.dart';
import 'enums.dart';

class RoleDefinition {
  final String id;
  final String name;
  final String description;
  final RoleTeam team;
  final IconData icon;
  final Color primaryColor;
  final Color secondaryColor;
  final bool isUnique;
  final int difficulty; // 1 to 5
  final String? lore;
  final List<String>? tips;

  RoleDefinition({
    required this.id,
    required this.name,
    required this.description,
    required this.team,
    required this.icon,
    required this.primaryColor,
    required this.secondaryColor,
    required this.isUnique,
    this.difficulty = 1,
    this.lore,
    this.tips,
  });
}
