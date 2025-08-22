import 'package:flutter/foundation.dart'; // For @immutable
import 'spell.dart';

/// Enum to represent the possible movement directions.
enum Direction { up, down, left, right }

/// Enum to represent the type of space on the grid.
enum SpaceType {
  empty,
  obstacle, // Represents an impassable obstacle
  water, // New: Water tile
  forest, // New: Forest tile
  corpse, // New: A tile with a dead enemy
  item, // New: Represents a space with an item
}

/// Enum to represent the current status of the game.
enum GameStatus { playing, victory, gameOver }

/// Enum for the different types of status effects.
enum StatusEffectType { burn, frozen }

/// Enum for the different types of terrain effects.
enum TerrainEffectType { burning }

/// Enum for the different types of enemies.
enum EnemyType { goblin, archer, ogre }

/// Represents an active status effect on a character.
@immutable
class StatusEffect {
  const StatusEffect({
    required this.type,
    required this.duration,
  });

  final StatusEffectType type;
  final int duration;

  StatusEffect copyWith({
    int? duration,
  }) {
    return StatusEffect(
      type: type,
      duration: duration ?? this.duration,
    );
  }
}

/// Represents an active effect on a terrain tile.
@immutable
class TerrainEffect {
  const TerrainEffect({
    required this.type,
    required this.duration,
  });

  final TerrainEffectType type;
  final int duration;

  TerrainEffect copyWith({
    int? duration,
  }) {
    return TerrainEffect(
      type: type,
      duration: duration ?? this.duration,
    );
  }
}

/// Represents a corpse on the battlefield.
@immutable
class Corpse {
  const Corpse({
    required this.id,
    required this.position,
    required this.type,
  });

  final String id;
  final (int, int) position;
  final EnemyType type; // The type of enemy this was.

  Corpse copyWith({
    (int, int)? position,
  }) {
    return Corpse(id: id, position: position ?? this.position, type: type);
  }
}

/// Represents the player character.
@immutable
class Player {
  const Player({
    this.position = (0, 0),
    this.health = 100,
    this.maxHealth = 100,
    this.mana = 100, // New: Player's current mana
    this.maxMana = 100, // Player's maximum mana
    this.inventory = const [], // New: Player's inventory
    this.dashCooldown = 0, // New: Cooldown for dash ability
    this.level = 1,
    this.xp = 0,
    this.unlockedElements = const {SpellElement.fire}, // New: Initially only Fire is unlocked
    this.unlockedSpellShapes = const {SpellShape.ball}, // New: Initially only Ball is unlocked
    this.xpToNextLevel = 100,
    this.spellPower = 0,
  });

  final (int, int) position;
  final int health;
  final int maxHealth;
  final int mana;
  final int maxMana;
  final List<Item> inventory; // New
  final int dashCooldown; // New
  final int level;
  final int xp;
  final Set<SpellElement> unlockedElements; // New
  final Set<SpellShape> unlockedSpellShapes; // New
  final int xpToNextLevel;
  final int spellPower;

  Player copyWith({
    (int, int)? position,
    int? health,
    int? maxHealth,
    int? mana, // New
    int? maxMana,
    int? dashCooldown, // New
    List<Item>? inventory, // New
    int? level,
    int? xp,
    Set<SpellElement>? unlockedElements, // New
    Set<SpellShape>? unlockedSpellShapes, // New
    int? xpToNextLevel,
    int? spellPower,
  }) {
    return Player(
      position: position ?? this.position,
      health: health ?? this.health,
      maxHealth: maxHealth ?? this.maxHealth,
      mana: mana ?? this.mana, // New
      maxMana: maxMana ?? this.maxMana,
      inventory: inventory ?? this.inventory, // New
      dashCooldown: dashCooldown ?? this.dashCooldown, // New
      level: level ?? this.level,
      xp: xp ?? this.xp,
      unlockedElements: unlockedElements ?? this.unlockedElements, // New
      unlockedSpellShapes: unlockedSpellShapes ?? this.unlockedSpellShapes, // New
      xpToNextLevel: xpToNextLevel ?? this.xpToNextLevel,
      spellPower: spellPower ?? this.spellPower,
    );
  }
}

/// Enum for the different types of items.
enum ItemType { healthPotion, manaPotion }

/// Represents an item on the grid or in the player's inventory.
@immutable
class Item {
  const Item({
    required this.id,
    required this.type,
  });

  final String id;
  final ItemType type;

  Item copyWith({
    String? id,
    ItemType? type,
  }) {
    return Item(
      id: id ?? this.id,
      type: type ?? this.type,
    );
  }
}

/// Represents an enemy character.
@immutable
class Enemy {
  const Enemy({
    required this.id,
    required this.position,
    this.type = EnemyType.goblin,
    this.health = 50,
    this.attackRange = 1,
    this.weakness, // New: Elemental weakness
    this.resistance, // New: Elemental resistance
    this.statusEffects = const [], // New: Active status effects
    this.xpValue = 25,
  });

  final String id;
  final (int, int) position;
  final EnemyType type;
  final int health;
  final int attackRange;
  final SpellElement? weakness; // New
  final SpellElement? resistance; // New
  final List<StatusEffect> statusEffects; // New
  final int xpValue;

  // A single, complete copyWith method to prevent data loss.
  Enemy copyWith({
    (int, int)? position,
    int? health,
    SpellElement? weakness, // New
    SpellElement? resistance, // New
    List<StatusEffect>? statusEffects,
    int? xpValue,
  }) {
    return Enemy(
      id: id, // ID remains constant
      position: position ?? this.position,
      type: type, // Type is inherent and does not change
      health: health ?? this.health,
      attackRange: attackRange, // Attack range is inherent and does not change
      weakness: weakness ?? this.weakness,
      resistance: resistance ?? this.resistance,
      statusEffects: statusEffects ?? this.statusEffects,
      xpValue: xpValue ?? this.xpValue,
    );
  }
}

/// Represents a summoned minion that fights for the player.
@immutable
class Minion {
  const Minion({
    required this.id,
    required this.position,
    this.type, // If not null, this is an undead minion of a specific type
    this.health = 40,
  });

  final String id;
  final (int, int) position;
  final EnemyType? type;
  final int health;

  Minion copyWith({
    (int, int)? position,
    int? health,
    EnemyType? type,
  }) {
    return Minion(
      id: id, // ID remains constant
      position: position ?? this.position,
      type: type ?? this.type,
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
    this.itemsOnGrid = const {}, // New: Items placed on the grid
    this.corpsesOnGrid = const {}, // New: Corpses on the grid
    this.terrainEffects = const {}, // New: Active effects on the grid
    this.minions = const [], // New: List of player's minions
    this.playerDirection = Direction.up,
    required this.grid, // Grid is now a required property
    this.gameStatus = GameStatus.playing,
  });

  final int gridSize;
  final Player player;
  final List<Enemy> enemies;
  final Map<(int, int), Item> itemsOnGrid; // New
  final Map<(int, int), Corpse> corpsesOnGrid; // New
  final Map<(int, int), TerrainEffect> terrainEffects; // New
  final List<Minion> minions;
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
    List<Minion>? minions,
    Map<(int, int), Item>? itemsOnGrid, // New
    Map<(int, int), Corpse>? corpsesOnGrid, // New
    Map<(int, int), TerrainEffect>? terrainEffects, // New
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
      minions: minions ?? this.minions,
      itemsOnGrid: itemsOnGrid ?? this.itemsOnGrid, // New
      corpsesOnGrid: corpsesOnGrid ?? this.corpsesOnGrid, // New
      terrainEffects: terrainEffects ?? this.terrainEffects, // New
      selectedElement: selectedElement ?? this.selectedElement,
      selectedSpellShape: selectedSpellShape ?? this.selectedSpellShape,
      playerDirection: playerDirection ?? this.playerDirection,
      grid: grid ?? this.grid,
      gameStatus: gameStatus ?? this.gameStatus,
    );
  }
}