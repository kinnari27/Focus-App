import 'package:flutter/material.dart';

class AppColors {
  AppColors._();

  // Core brand background and surfaces
  static const Color background = Color(0xFF0F0F12);
  static const Color surface = Color(0xFF18181C);
  static const Color surfaceElevated = Color(0xFF222228);
  static const Color border = Color(0x1FFFFFFF);
  static const Color borderHighlighted = Color(0x336366F1);

  // Brand Accents
  static const Color primary = Color(0xFF6366F1);     // Indigo
  static const Color secondary = Color(0xFF00F5D4);   // Mint Green
  static const Color error = Color(0xFFF72585);       // Coral Red Error
  static const Color accentPink = Color(0xFFF72585);   // Coral Pink
  static const Color warning = Color(0xFFFFB703);      // Warm Amber
  static const Color info = Color(0xFF4EA8DE);         // Soft Cyan/Blue

  // Priority Colors
  static const Color priorityHigh = Color(0xFFF72585);
  static const Color priorityMedium = Color(0xFF6366F1);
  static const Color priorityLow = Color(0xFF4EA8DE);

  // Category Colors
  static const Color categoryMind = Color(0xFF6366F1);
  static const Color categoryWork = Color(0xFF00F5D4);
  static const Color categoryHealth = Color(0xFFF72585);
  static const Color categoryPersonal = Color(0xFF4EA8DE);

  static Color getPriorityColor(String priority) {
    switch (priority.toLowerCase()) {
      case 'high':
        return priorityHigh;
      case 'medium':
        return priorityMedium;
      case 'low':
      default:
        return priorityLow;
    }
  }

  static Color getCategoryColor(String category) {
    switch (category.toLowerCase()) {
      case 'mind':
        return categoryMind;
      case 'work':
        return categoryWork;
      case 'health':
        return categoryHealth;
      case 'personal':
      default:
        return categoryPersonal;
    }
  }
}

