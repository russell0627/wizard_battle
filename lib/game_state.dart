import 'package:flutter/foundation.dart'; // For @immutable
import 'spell.dart';

/// Enum to represent the possible movement directions.
enum Direction { up, down, left, right }

/// Enum to represent the type of space on the grid.
enum SpaceType {
  empty,
  obstacle, // Represents an impassable obstacle
}

/// Enum to represent the current status of the game.
enum GameStatus { playing, victory, gameOver }

/// Represents the player character.
@immutable
class Player {
  const Player({
    this.position = (0, 0),
    this.health = 100,
  });

  final (int, int) position;
  final int health;

  Player copyWith({
    (int, int)? position,
    int? health,
  }) {
    return Player(
      position: position ?? this.position,
      health: health ?? this.health,
    );
  }
}

/// Represents an enemy character.
@immutable
class Enemy {
  const Enemy({
    required this.id,
    required this.position,
    this.health = 50,
  });

  final String id;
  final (int, int) position;
  final int health;

  Enemy copyWith({
    (int, int)? position,
    int? health,
  }) {
    return Enemy(
      id: id, // ID remains constant
      position: position ?? this.position,
      health: health ?? this.health,
    );
  }
}

/// Represents the state of the game grid and player.
@immutable
class GameState {
  static const int defaultGridSize = 20;

  const GameState({
    this.gridSize = defaultGridSize,
    this.player = const Player(),
    this.selectedElement = SpellElement.fire,
    this.selectedSpellShape = SpellShape.ball,
    this.enemies = const [],
    this.playerDirection = Direction.up,
    required this.grid, // Grid is now a required property
    this.gameStatus = GameStatus.playing,
  });

  final int gridSize;
  final Player player;
  final List<Enemy> enemies;
  final Direction playerDirection;
  final List<List<SpaceType>> grid; // Explicit grid representation
  final GameStatus gameStatus;

  /// The currently selected spell element.
  final SpellElement selectedElement;

  /// The currently selected spell shape.
  final SpellShape selectedSpellShape;

  /// A computed property for the currently configured spell.
  SpellData get currentSpell =>
      SpellData(element: selectedElement, shape: selectedSpellShape);

  GameState copyWith({
    int? gridSize,
    Player? player,
    List<Enemy>? enemies,
    SpellElement? selectedElement,
    SpellShape? selectedSpellShape,
    Direction? playerDirection,
    List<List<SpaceType>>? grid,
    GameStatus? gameStatus,
  }) {
    return GameState(
      gridSize: gridSize ?? this.gridSize,
      player: player ?? this.player,
      enemies: enemies ?? this.enemies,
      selectedElement: selectedElement ?? this.selectedElement,
      selectedSpellShape: selectedSpellShape ?? this.selectedSpellShape,
      playerDirection: playerDirection ?? this.playerDirection,
      grid: grid ?? this.grid,
      gameStatus: gameStatus ?? this.gameStatus,
    );
  }
}