import 'dart:math';

import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'game_state.dart';
import 'spell.dart';

// This will generate a provider named `gameControllerProvider`
part 'game_controller.g.dart';

@riverpod
class GameController extends _$GameController {
  @override
  GameState build() {
    // Initialize the grid with empty spaces
    final initialGrid = List.generate(
      GameState.defaultGridSize,
      (_) => List.generate(GameState.defaultGridSize, (_) => SpaceType.empty),
    );

    // Add some obstacles for demonstration
    initialGrid[3][3] = SpaceType.obstacle;
    initialGrid[3][4] = SpaceType.obstacle;
    initialGrid[3][5] = SpaceType.obstacle;
    initialGrid[10][15] = SpaceType.obstacle;
    initialGrid[11][15] = SpaceType.obstacle;
    initialGrid[12][15] = SpaceType.obstacle;

    // Initialize the game state with some initial enemies
    return GameState(
      enemies: const [
        Enemy(id: 'enemy_1', position: (2, 2), health: 50),
        Enemy(id: 'enemy_2', position: (7, 7), health: 50),
        Enemy(id: 'enemy_3', position: (5, 1), health: 50),
      ],
      grid: initialGrid,
    );
  }

  /// Moves the player in the given direction.
  void move(Direction direction) {
    // Disable movement if the game is over.
    if (state.gameStatus != GameStatus.playing) return;

    final player = state.player;
    final (x, y) = player.position;

    // Calculate new player position
    switch (direction) {
      case Direction.up:
        if (y > 0 && state.grid[y - 1][x] != SpaceType.obstacle) {
          state = state.copyWith(
              player: player.copyWith(position: (x, y - 1)),
              playerDirection: direction);
        } else {
          // If blocked, just update the direction without moving
          state = state.copyWith(playerDirection: direction);
        }
        break;
      case Direction.down:
        if (y < state.gridSize - 1 && state.grid[y + 1][x] != SpaceType.obstacle) {
          state = state.copyWith(
              player: player.copyWith(position: (x, y + 1)),
              playerDirection: direction);
        } else {
          state = state.copyWith(playerDirection: direction);
        }
        break;
      case Direction.left:
        if (x > 0 && state.grid[y][x - 1] != SpaceType.obstacle) {
          state = state.copyWith(
              player: player.copyWith(position: (x - 1, y)),
              playerDirection: direction);
        } else {
          state = state.copyWith(playerDirection: direction);
        }
        break;
      case Direction.right:
        if (x < state.gridSize - 1 && state.grid[y][x + 1] != SpaceType.obstacle) {
          state = state.copyWith(
              player: player.copyWith(position: (x + 1, y)),
              playerDirection: direction);
        } else {
          state = state.copyWith(playerDirection: direction);
        }
        break;
    }

    // After the player moves, move the enemies
    _moveEnemies();
  }

  /// Moves all enemies based on simple AI.
  void _moveEnemies() {
    // Enemies shouldn't move if the game is already won or lost.
    if (state.gameStatus != GameStatus.playing) return;

    final List<Enemy> currentEnemies = List.from(state.enemies);
    int playerHealth = state.player.health;
    final playerPosition = state.player.position;

    final Set<(int, int)> nextOccupiedPositions = {playerPosition};
    final List<Enemy> nextEnemyStates = [];

    for (final enemy in currentEnemies) {
      final (enemyX, enemyY) = enemy.position;

      // --- 1. ATTACK LOGIC ---
      final isAdjacent = (enemyX - playerPosition.$1).abs() + (enemyY - playerPosition.$2).abs() == 1;

      if (isAdjacent) {
        const attackDamage = 10;
        playerHealth -= attackDamage;
        print('Enemy ${enemy.id} attacked player for $attackDamage damage!');
        nextEnemyStates.add(enemy);
        nextOccupiedPositions.add(enemy.position);
      } else {
        // --- 2. MOVEMENT LOGIC ---
        int newEnemyX = enemyX;
        int newEnemyY = enemyY;
        final dx = playerPosition.$1 - enemyX;
        final dy = playerPosition.$2 - enemyY;

        if (dx != 0) newEnemyX += dx.sign;
        if (dy != 0) newEnemyY += dy.sign;

        final proposedPosition = (
            newEnemyX.clamp(0, state.gridSize - 1),
            newEnemyY.clamp(0, state.gridSize - 1));

        // --- 3. COLLISION LOGIC ---
        if (state.grid[proposedPosition.$2][proposedPosition.$1] == SpaceType.obstacle ||
            nextOccupiedPositions.contains(proposedPosition)) {
          nextEnemyStates.add(enemy);
          nextOccupiedPositions.add(enemy.position);
        } else {
          nextEnemyStates.add(enemy.copyWith(position: proposedPosition));
          nextOccupiedPositions.add(proposedPosition);
        }
      }
    }

    GameStatus nextStatus = state.gameStatus;
    if (playerHealth <= 0) {
      nextStatus = GameStatus.gameOver;
      print("Game Over! Player has been defeated.");
    }

    state = state.copyWith(
      enemies: nextEnemyStates,
      player: state.player.copyWith(health: playerHealth.clamp(0, 100)),
      gameStatus: nextStatus,
    );
  }

  /// Updates the player's selected spell element.
  void selectElement(SpellElement element) {
    state = state.copyWith(selectedElement: element);
  }

  /// Updates the player's selected spell shape.
  void selectSpellShape(SpellShape shape) {
    state = state.copyWith(selectedSpellShape: shape);
  }

  /// Casts the currently configured spell at a specific target on the grid.
  void castSpellAt(int targetX, int targetY) {
    if (state.gameStatus != GameStatus.playing) return;

    final spell = state.currentSpell;

    if (spell.shape == SpellShape.self) {
      int playerHealth = state.player.health;
      const int healAmount = 20;
      const int maxPlayerHealth = 100;
      playerHealth = (playerHealth + healAmount).clamp(0, maxPlayerHealth);
      state = state.copyWith(player: state.player.copyWith(health: playerHealth));
      print('Self spell healed player for $healAmount. New health: $playerHealth');
    } else {
      List<Enemy> currentEnemies = List.from(state.enemies);
      final int damage = _calculateSpellDamage(spell.element);

      final Set<(int, int)> affectedTiles = getAffectedTilesForCurrentSpell(
        targetPosition: (targetX, targetY),
      );

      for (int i = 0; i < currentEnemies.length; i++) {
        final enemy = currentEnemies[i];
        if (affectedTiles.contains(enemy.position)) {
          currentEnemies[i] = enemy.copyWith(health: enemy.health - damage);
        }
      }

      currentEnemies.removeWhere((enemy) => enemy.health <= 0);

      GameStatus nextStatus = state.gameStatus;
      if (currentEnemies.isEmpty) {
        nextStatus = GameStatus.victory;
        print("Victory! All enemies have been defeated.");
      }

      state = state.copyWith(enemies: currentEnemies, gameStatus: nextStatus);

      print('Casting a ${spell.element.name} ${spell.shape.name} spell at ($targetX, $targetY)!');
      print('Remaining Enemies: ${state.enemies.length}');
    }

    _moveEnemies();
  }

  /// Resets the game to its initial state.
  void restartGame() {
    ref.invalidateSelf();
  }

  /// Calculates and returns the set of grid coordinates affected by the currently
  /// selected spell, based on the target position.
  Set<(int, int)> getAffectedTilesForCurrentSpell({(int, int)? targetPosition}) {
    if (targetPosition == null) return {};

    final spellShape = state.selectedSpellShape;
    final gridSize = state.gridSize;

    switch (spellShape) {
      case SpellShape.ball:
        return {targetPosition};
      case SpellShape.self:
        return {};
      case SpellShape.cone:
        return _calculateConeAoeTowardsTarget(state.player.position, targetPosition, gridSize);
      case SpellShape.wall:
        return _calculateWallAoeAtTarget(targetPosition, gridSize);
    }
  }

  Set<(int, int)> _calculateConeAoeTowardsTarget(
      (int, int) playerPos, (int, int) targetPos, int gs) {
    final (px, py) = playerPos;
    final (tx, ty) = targetPos;
    final dx = tx - px;
    final dy = ty - py;

    Direction direction;
    if (dx == 0 && dy == 0) {
      direction = state.playerDirection;
    } else if (dx.abs() > dy.abs()) {
      direction = dx > 0 ? Direction.right : Direction.left;
    } else {
      direction = dy > 0 ? Direction.down : Direction.up;
    }
    return _calculateConeAffectedTiles(px, py, direction, gs);
  }

  Set<(int, int)> _calculateConeAffectedTiles(int px, int py, Direction direction, int gs) {
    final Set<(int, int)> tiles = {};
    void addIfValid(int x, int y) {
      if (x >= 0 && x < gs && y >= 0 && y < gs) tiles.add((x, y));
    }

    switch (direction) {
      case Direction.up:
        addIfValid(px, py - 1); addIfValid(px - 1, py - 2); addIfValid(px, py - 2); addIfValid(px + 1, py - 2);
        break;
      case Direction.down:
        addIfValid(px, py + 1); addIfValid(px - 1, py + 2); addIfValid(px, py + 2); addIfValid(px + 1, py + 2);
        break;
      case Direction.left:
        addIfValid(px - 1, py); addIfValid(px - 2, py - 1); addIfValid(px - 2, py); addIfValid(px - 2, py + 1);
        break;
      case Direction.right:
        addIfValid(px + 1, py); addIfValid(px + 2, py - 1); addIfValid(px + 2, py); addIfValid(px + 2, py + 1);
        break;
    }
    return tiles;
  }

  Set<(int, int)> _calculateWallAoeAtTarget((int, int) target, int gs) {
    final Set<(int, int)> tiles = {};
    final (tx, ty) = target;
    void addIfValid(int x, int y) {
      if (x >= 0 && x < gs && y >= 0 && y < gs) tiles.add((x, y));
    }

    for (int x = tx - 1; x <= tx + 1; x++) {
      for (int y = ty - 1; y <= ty + 1; y++) {
        addIfValid(x, y);
      }
    }
    return tiles;
  }

  /// Calculates the base damage for a spell based on its element.
  int _calculateSpellDamage(SpellElement element) {
    switch (element) {
      case SpellElement.fire: return 30;
      case SpellElement.water: return 25;
      case SpellElement.earth: return 20;
      case SpellElement.air: return 15;
    }
  }
}