import 'package:flutter/foundation.dart';

/// Enum for spell elements.
enum SpellElement { fire, water, earth, air }

/// Enum for spell shapes.
enum SpellShape { ball, cone, wall, self, summon, raiseDead }

/// Data classes for defining spells.
@immutable
class SpellData {
  const SpellData({
    required this.element,
    required this.shape,
  });

  final SpellElement element;
  final SpellShape shape;
}