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

  RoleDefinition({
    required this.id,
    required this.name,
    required this.description,
    required this.team,
    required this.icon,
    required this.primaryColor,
    required this.secondaryColor,
    required this.isUnique,
  });
}
