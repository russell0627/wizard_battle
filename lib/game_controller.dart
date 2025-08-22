import 'dart:math';

import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'game_state.dart';
import 'spell.dart';

// This will generate a provider named `gameControllerProvider`
part 'game_controller.g.dart';

// --- Game Constants ---
const int _manaRegenPerTurn = 10;
const int _dashManaCost = 20;
const int _dashDistance = 3;
const int _dashCooldownDuration = 3; // Turns
const int _burnDamagePerTurn = 5;
const int _baseXpToNextLevel = 100;
const int _focusManaRegenAmount = 40;
const int _freezeDuration = 2; // Turns (enemy misses 1 turn)
const double _levelXpMultiplier = 1.2;
const int _healthPotionHealAmount = 30;
const int _burningGroundDamage = 10;
const int _manaPotionRestoreAmount = 50;

const int _burnDuration = 3; // Turns

const Map<SpellShape, int> _spellManaCosts = {
  SpellShape.ball: 10,
  SpellShape.cone: 15,
  SpellShape.wall: 20,
  SpellShape.self: 25, // Healing spell has a cost
  SpellShape.summon: 40, // Summoning is expensive
  SpellShape.raiseDead: 50, // Raising the dead is very expensive
};

/// Defines the enemies for each subsequent wave of the game.
final Map<int, List<Enemy>> _waveDefinitions = {
  2: const [
    Enemy(id: 'wave2_1', position: (5, 15), type: EnemyType.archer, health: 40, attackRange: 5, weakness: SpellElement.earth, resistance: SpellElement.air, xpValue: 40),
    Enemy(id: 'wave2_2', position: (15, 5), type: EnemyType.archer, health: 40, attackRange: 5, weakness: SpellElement.earth, resistance: SpellElement.air, xpValue: 40),
    Enemy(id: 'wave2_3', position: (10, 10), type: EnemyType.ogre, health: 110, weakness: SpellElement.water, resistance: SpellElement.fire, xpValue: 60),
  ],
  3: const [
    // A final, harder wave
    Enemy(id: 'wave3_1', position: (18, 18), type: EnemyType.ogre, health: 150, weakness: SpellElement.water, resistance: SpellElement.fire, xpValue: 75),
    Enemy(id: 'wave3_2', position: (1, 18), type: EnemyType.ogre, health: 150, weakness: SpellElement.water, resistance: SpellElement.fire, xpValue: 75),
    Enemy(id: 'wave3_3', position: (10, 2), type: EnemyType.goblin, health: 70, weakness: SpellElement.fire, resistance: SpellElement.water, xpValue: 40),
    Enemy(id: 'wave3_4', position: (12, 2), type: EnemyType.goblin, health: 70, weakness: SpellElement.fire, resistance: SpellElement.water, xpValue: 40),
  ]
};

@riverpod
class GameController extends _$GameController {
  @override
  GameState build() {
    // Initialize the grid with empty spaces
    final initialGrid = List.generate(
      GameState.defaultGridSize,
      (_) => List.generate(GameState.defaultGridSize, (_) => SpaceType.empty),
    );

    // Initialize the grid with obstacles, water, and forest
    _initializeGrid(initialGrid);

    // Initialize the game state with some initial enemies
    final initialEnemies = _generateInitialWave();
    return GameState(
      enemies: initialEnemies,
      player: const Player(
        unlockedElements: {SpellElement.fire}, // Only Fire unlocked initially
        unlockedSpellShapes: {SpellShape.ball}, // Only Ball unlocked initially
      ),
      itemsOnGrid: const {
        (1, 1): Item(id: 'item_hp_1', type: ItemType.healthPotion),
        (8, 8): Item(id: 'item_mp_1', type: ItemType.manaPotion),
        (15, 15): Item(id: 'item_hp_2', type: ItemType.healthPotion),
      },
      // Note: initialGrid is already set up with obstacles, water, forest, and initial items.
      grid: initialGrid,
    );
  }

  /// Moves the player in the given direction.
  void move(Direction direction) {
    // Disable movement if the game is over.
    if (state.gameStatus != GameStatus.playing) return;

    final player = state.player;
    final (x, y) = player.position; // Current player position

    // Calculate new player position
    (int, int) newPosition = player.position; // Initialize with current position
    switch (direction) {
      case Direction.up:
        if (y > 0 && state.grid[y - 1][x] != SpaceType.obstacle && state.grid[y - 1][x] != SpaceType.corpse) {
          newPosition = (x, y - 1);
        } else {
          // No move, just update direction
        }
        break;
      case Direction.down:
        if (y < state.gridSize - 1 && state.grid[y + 1][x] != SpaceType.obstacle && state.grid[y + 1][x] != SpaceType.corpse) {
          newPosition = (x, y + 1);
        } else {
          // No move, just update direction
        }
        break;
      case Direction.left:
        if (x > 0 && state.grid[y][x - 1] != SpaceType.obstacle && state.grid[y][x - 1] != SpaceType.corpse) {
          newPosition = (x - 1, y);
        } else {
          // No move, just update direction
        }
        break;
      case Direction.right:
        if (x < state.gridSize - 1 && state.grid[y][x + 1] != SpaceType.obstacle && state.grid[y][x + 1] != SpaceType.corpse) {
          newPosition = (x + 1, y);
        } else {
          // No move, just update direction
        }
        break;
    }

    // If player moved, update position and check for items
    if (newPosition != player.position) {
      // Player moved, update position and check for items
      final itemOnNewPosition = state.itemsOnGrid[newPosition];
      final newItemsOnGrid = Map.of(state.itemsOnGrid);
      final newInventory = List.of(player.inventory);

      if (itemOnNewPosition != null) {
        newInventory.add(itemOnNewPosition);
        newItemsOnGrid.remove(newPosition);
        // Optionally, add a SnackBar message here for item pickup
      }

      state = state.copyWith(
        player: player.copyWith(position: newPosition, inventory: newInventory),
        playerDirection: direction,
        itemsOnGrid: newItemsOnGrid,
      );
    } else {
      // Player didn't move, but might have changed direction
      state = state.copyWith(playerDirection: direction);
    }

    // After the player moves, move the enemies
    _processNonPlayerTurns(isFocusing: false);
  }

  /// Allows the player to dash a short distance in a given direction.
  void dash(Direction direction) {
    if (state.gameStatus != GameStatus.playing) return;

    final player = state.player;

    if (player.mana < _dashManaCost) {
      // TODO: Add SnackBar message for not enough mana
      return;
    }
    if (player.dashCooldown > 0) {
      // TODO: Add SnackBar message for dash on cooldown
      return;
    }

    (int, int) newPosition = player.position;
    for (int i = 0; i < _dashDistance; i++) {
      final (currentX, currentY) = newPosition;
      (int, int) nextStep = newPosition;
      if (direction == Direction.up && currentY > 0 && state.grid[currentY - 1][currentX] != SpaceType.obstacle && state.grid[currentY - 1][currentX] != SpaceType.corpse) {
        nextStep = (currentX, currentY - 1);
      } else if (direction == Direction.down && currentY < state.gridSize - 1 && state.grid[currentY + 1][currentX] != SpaceType.obstacle && state.grid[currentY + 1][currentX] != SpaceType.corpse) {
        nextStep = (currentX, currentY + 1);
      } else if (direction == Direction.left && currentX > 0 && state.grid[currentY][currentX - 1] != SpaceType.obstacle && state.grid[currentY][currentX - 1] != SpaceType.corpse) {
        nextStep = (currentX - 1, currentY);
      } else if (direction == Direction.right && currentX < state.gridSize - 1 && state.grid[currentY][currentX + 1] != SpaceType.obstacle && state.grid[currentY][currentX + 1] != SpaceType.corpse) {
        nextStep = (currentX + 1, currentY);
      } else {
        break; // Hit an obstacle or boundary
      }
      newPosition = nextStep;
    }

    state = state.copyWith(
      player: player.copyWith(
        position: newPosition,
        mana: player.mana - _dashManaCost,
        dashCooldown: _dashCooldownDuration,
      ),
    );

    _processNonPlayerTurns(isFocusing: false);
  }

  /// Allows the player to use an item from their inventory.
  void useItem(Item item) {
    if (state.gameStatus != GameStatus.playing) return;

    final player = state.player;
    final newInventory = List.of(player.inventory);

    if (!newInventory.remove(item)) {
      // Item not found in inventory, should not happen if UI is correct
      return;
    }

    Player updatedPlayer = player.copyWith(inventory: newInventory);

    switch (item.type) {
      case ItemType.healthPotion:
        updatedPlayer = updatedPlayer.copyWith(
            health: (updatedPlayer.health + _healthPotionHealAmount).clamp(0, updatedPlayer.maxHealth));
        break;
      case ItemType.manaPotion:
        updatedPlayer = updatedPlayer.copyWith(
            mana: (updatedPlayer.mana + _manaPotionRestoreAmount).clamp(0, updatedPlayer.maxMana));
        break;
    }

    state = state.copyWith(player: updatedPlayer);
    _processNonPlayerTurns(isFocusing: false); // Using an item consumes a turn
  }

  /// Allows the player to focus, skipping their turn to regain a large amount of mana.
  void focus() {
    if (state.gameStatus != GameStatus.playing) return;

    _processNonPlayerTurns(isFocusing: true);
  }

  /// Processes the turns for all non-player characters (minions and enemies).
  void _processNonPlayerTurns({required bool isFocusing}) {
    // Do not process turns if the game is already over.
    if (state.gameStatus != GameStatus.playing) return;

    // --- SETUP ---
    var player = state.player;
    var nextEnemyStates = List.of(state.enemies);
    var nextMinionStates = List.of(state.minions);
    int xpGainedThisTurn = 0;
    final List<Enemy> newlyDefeatedEnemies = [];

    // --- TERRAIN EFFECT PHASE ---
    // Apply damage from burning ground and tick down durations.
    final nextTerrainEffects = <(int, int), TerrainEffect>{};
    for (final entry in state.terrainEffects.entries) {
      final position = entry.key;
      final effect = entry.value;

      if (effect.type == TerrainEffectType.burning) {
        // Damage player if they are on the burning tile
        if (player.position == position) {
          player = player.copyWith(health: player.health - _burningGroundDamage);
        }
        // Damage any enemy on the burning tile
        final enemyIndex = nextEnemyStates.indexWhere((e) => e.position == position);
        if (enemyIndex != -1) {
          final enemy = nextEnemyStates[enemyIndex];
          final newHealth = enemy.health - _burningGroundDamage;
          if (newHealth > 0) {
            nextEnemyStates[enemyIndex] = enemy.copyWith(health: newHealth);
          } else {
            xpGainedThisTurn += enemy.xpValue;
            newlyDefeatedEnemies.add(nextEnemyStates.removeAt(enemyIndex));
          }
        }
        // TODO: Damage minions on the burning tile
      }

      // Tick down duration
      final newDuration = effect.duration - 1;
      if (newDuration > 0) {
        nextTerrainEffects[position] = effect.copyWith(duration: newDuration);
      }
    }

    // --- STATUS EFFECT PHASE ---
    // Apply damage from status effects like Burn and tick down their duration.
    final List<Enemy> enemiesAfterStatusEffects = [];
    for (var enemy in nextEnemyStates) {
      int totalStatusDamage = 0;
      List<StatusEffect> updatedEffects = [];

      for (final effect in enemy.statusEffects) {
        if (effect.type == StatusEffectType.burn) {
          totalStatusDamage += _burnDamagePerTurn;
        }

        // Decrement duration and keep the effect if its duration is still positive.
        final newDuration = effect.duration - 1;
        if (newDuration > 0) {
          updatedEffects.add(effect.copyWith(duration: newDuration));
        }
      }

      final newHealth = enemy.health - totalStatusDamage;
      if (newHealth > 0) {
        enemiesAfterStatusEffects.add(enemy.copyWith(health: newHealth, statusEffects: updatedEffects));
      } else {
        // Enemy is defeated by status effects, add to list for processing
        xpGainedThisTurn += enemy.xpValue;
        newlyDefeatedEnemies.add(enemy);
      }
    }
    nextEnemyStates = enemiesAfterStatusEffects;

    // --- MINION PHASE ---
    // Minions move and attack enemies.
    if (nextEnemyStates.isNotEmpty) {
      final List<Minion> processedMinions = [];
      final Set<(int, int)> occupiedThisTurn = {player.position, ...nextEnemyStates.map((e) => e.position)};

      for (final minion in nextMinionStates) {
        // Find the closest enemy
        Enemy? closestEnemy;
        int minDistance = 9999;
        for (final enemy in nextEnemyStates) {
          final distance = (minion.position.$1 - enemy.position.$1).abs() + (minion.position.$2 - enemy.position.$2).abs();
          if (distance < minDistance) {
            minDistance = distance;
            closestEnemy = enemy;
          }
        }

        if (closestEnemy != null) {
          if (minDistance == 1) {
            // Attack
            const minionAttackDamage = 15;
            final newEnemyHealth = closestEnemy.health - minionAttackDamage;
            final enemyIndex = nextEnemyStates.indexWhere((e) => e.id == closestEnemy!.id);
            if (newEnemyHealth > 0) {
              nextEnemyStates[enemyIndex] = closestEnemy.copyWith(health: newEnemyHealth);
            } else {
              xpGainedThisTurn += closestEnemy.xpValue;
              newlyDefeatedEnemies.add(nextEnemyStates.removeAt(enemyIndex));
            }
            processedMinions.add(minion); // Minion doesn't move when attacking
            occupiedThisTurn.add(minion.position);
          } else {
            // Move towards the closest enemy
            final (newX, newY) = _moveTowards(minion.position, closestEnemy.position);
            final proposedPosition = (newX.clamp(0, state.gridSize - 1), newY.clamp(0, state.gridSize - 1));

            if (state.grid[proposedPosition.$2][proposedPosition.$1] != SpaceType.obstacle && !occupiedThisTurn.contains(proposedPosition)) {
              processedMinions.add(minion.copyWith(position: proposedPosition));
              occupiedThisTurn.add(proposedPosition);
            } else {
              processedMinions.add(minion); // Can't move, stay put
              occupiedThisTurn.add(minion.position);
            }
          }
        }
      }
      nextMinionStates = processedMinions;
    }

    // --- ENEMY PHASE ---
    // Enemies move and attack the player or the closest minion.
    final List<Enemy> processedEnemies = [];
    final Set<(int, int)> occupiedThisTurn = {player.position, ...nextMinionStates.map((m) => m.position)};

    for (final enemy in nextEnemyStates) {
      // Check if the enemy is frozen and should skip its turn
      if (enemy.statusEffects.any((e) => e.type == StatusEffectType.frozen)) {
        processedEnemies.add(enemy); // Add to list but do nothing
        occupiedThisTurn.add(enemy.position);
        continue; // Skip this enemy's turn
      }

      // Find closest target (player or minion)
      (int, int)? targetPosition;
      String? targetId; // Can be 'player' or a minion's ID
      int minDistance = 9999;

      // Check distance to player
      final playerDist = (enemy.position.$1 - player.position.$1).abs() + (enemy.position.$2 - player.position.$2).abs();
      minDistance = playerDist;
      targetPosition = player.position;
      targetId = 'player';

      // Check distance to minions, they are prioritized
      for (final minion in nextMinionStates) {
        final minionDist = (enemy.position.$1 - minion.position.$1).abs() + (enemy.position.$2 - minion.position.$2).abs();
        if (minionDist < minDistance) {
          minDistance = minionDist;
          targetPosition = minion.position;
          targetId = minion.id;
        }
      }

      // --- ATTACK LOGIC ---
      if (minDistance <= enemy.attackRange) {
        // OGRE STOMP (AOE ATTACK)
        if (enemy.type == EnemyType.ogre && minDistance == 1) {
          const stompDamage = 15;
          final (ex, ey) = enemy.position;
          final Set<(int, int)> stompTiles = {};
          for (int x = ex - 1; x <= ex + 1; x++) {
            for (int y = ey - 1; y <= ey + 1; y++) {
              if (x >= 0 && x < state.gridSize && y >= 0 && y < state.gridSize) {
                stompTiles.add((x, y));
              }
            }
          }

          // Damage player if in stomp area
          if (stompTiles.contains(player.position)) {
            player = player.copyWith(health: player.health - stompDamage);
          }

          // Damage minions if in stomp area
          final List<Minion> minionsAfterStomp = [];
          for (final minion in nextMinionStates) {
            if (stompTiles.contains(minion.position)) {
              final newHealth = minion.health - stompDamage;
              if (newHealth > 0) {
                minionsAfterStomp.add(minion.copyWith(health: newHealth));
              }
              // else minion is defeated and removed from list
            } else {
              minionsAfterStomp.add(minion);
            }
          }
          nextMinionStates = minionsAfterStomp;
        } else {
          // STANDARD SINGLE-TARGET ATTACK
          bool targetInForest = state.grid[targetPosition!.$2][targetPosition.$1] == SpaceType.forest;
          double damageModifier = (enemy.type == EnemyType.archer && targetInForest) ? 0.5 : 1.0;

          // Calculate base damage
          int enemyAttackDamage = 10; // Default goblin damage
          if (enemy.type == EnemyType.ogre) {
            enemyAttackDamage = 20; // Ogre single target attack
          }

          // GOBLIN SWARM TACTICS
          if (enemy.type == EnemyType.goblin) {
            int swarmBonus = 0;
            const swarmRadius = 3;
            const bonusPerGoblin = 2;
            for (final otherEnemy in nextEnemyStates) {
              if (otherEnemy.id != enemy.id && otherEnemy.type == EnemyType.goblin) {
                final dist = (enemy.position.$1 - otherEnemy.position.$1).abs() + (enemy.position.$2 - otherEnemy.position.$2).abs();
                if (dist <= swarmRadius) {
                  swarmBonus += bonusPerGoblin;
                }
              }
            }
            enemyAttackDamage += swarmBonus;
          }

          // Apply final damage to target
          final finalDamage = (enemyAttackDamage * damageModifier).round();
          if (targetId == 'player') {
            player = player.copyWith(health: player.health - finalDamage);
          } else if (targetId != null) {
            final minionIndex = nextMinionStates.indexWhere((m) => m.id == targetId);
            if (minionIndex != -1) {
              final targetMinion = nextMinionStates[minionIndex];
              final newMinionHealth = targetMinion.health - finalDamage;
              if (newMinionHealth > 0) {
                nextMinionStates[minionIndex] = targetMinion.copyWith(health: newMinionHealth);
              } else {
                nextMinionStates.removeAt(minionIndex); // Minion is defeated
              }
            }
          }
        }
        processedEnemies.add(enemy);
        occupiedThisTurn.add(enemy.position);
      } else if (targetPosition != null) {
        // Move
        final (newX, newY) = _moveTowards(enemy.position, targetPosition);
        final proposedPosition = (newX.clamp(0, state.gridSize - 1), newY.clamp(0, state.gridSize - 1));
        if (state.grid[proposedPosition.$2][proposedPosition.$1] != SpaceType.obstacle && !occupiedThisTurn.contains(proposedPosition)) {
          processedEnemies.add(enemy.copyWith(position: proposedPosition));
          occupiedThisTurn.add(proposedPosition);
        } else {
          processedEnemies.add(enemy);
          occupiedThisTurn.add(enemy.position);
        }
      }
    }

    // --- LOOT & XP PHASE ---
    final deathProcessingResult = _processDeaths(
        newlyDefeatedEnemies, state.itemsOnGrid, state.corpsesOnGrid, state.grid);
    player = _processLevelUp(player, xpGainedThisTurn);

    // --- CLEANUP PHASE ---
    GameStatus nextStatus = state.gameStatus;
    if (player.health <= 0) {
      nextStatus = GameStatus.gameOver;
    }

    // Regenerate player mana. Focusing provides a larger boost.
    final manaToRegen = isFocusing ? _focusManaRegenAmount : _manaRegenPerTurn;
    player = player.copyWith(mana: (player.mana + manaToRegen).clamp(0, player.maxMana));

    // Decrement dash cooldown
    if (player.dashCooldown > 0) {
      player = player.copyWith(dashCooldown: player.dashCooldown - 1);
    }

    // Update state once with all changes to health, mana, and enemies.
    state = state.copyWith(
      enemies: processedEnemies,
      minions: nextMinionStates,
      player: player,
      terrainEffects: nextTerrainEffects,
      itemsOnGrid: deathProcessingResult.newItemsOnGrid,
      corpsesOnGrid: deathProcessingResult.newCorpsesOnGrid,
      grid: deathProcessingResult.newGrid,
      gameStatus: nextStatus,
    );

    // NEW: Check for wave completion after the turn has fully resolved.
    if (state.enemies.isEmpty && state.gameStatus == GameStatus.playing) {
      _startNextWave();
    }
  }

  /// Updates the player's selected spell element.
  void selectElement(SpellElement element) {
    if (!state.player.unlockedElements.contains(element)) {
      // Optionally, add a SnackBar message here "Element not yet unlocked!"
      return;
    }
    state = state.copyWith(selectedElement: element);
  }

  /// Updates the player's selected spell shape.
  void selectSpellShape(SpellShape shape) {
    if (!state.player.unlockedSpellShapes.contains(shape)) {
      // Optionally, add a SnackBar message here "Spell shape not yet unlocked!"
      return;
    }
    state = state.copyWith(selectedSpellShape: shape);
  }

  /// Casts the currently configured spell at a specific target on the grid.
  void castSpellAt(int targetX, int targetY) {
    if (state.gameStatus != GameStatus.playing) return;

    final spell = state.currentSpell;

    // Check for mana cost
    final manaCost = _spellManaCosts[spell.shape] ?? 0;
    if (state.player.mana < manaCost) {
      return; // Prevent casting if not enough mana
    }

    int xpFromThisSpell = 0;

    if (spell.shape == SpellShape.self) {
      final player = state.player;
      const int healAmount = 20;

      final newHealth = (player.health + healAmount).clamp(0, player.maxHealth);
      final newMana = player.mana - manaCost;

      // Update state once with both health and mana changes
      state = state.copyWith(player: player.copyWith(health: newHealth, mana: newMana));
    } else if (spell.shape == SpellShape.summon) {
      final occupiedTiles = {
        state.player.position, // Player position is always occupied
        ...state.enemies.map((e) => e.position),
        ...state.minions.map((m) => m.position),
      };
      final targetPosition = (targetX, targetY);

      if (state.grid[targetY][targetX] == SpaceType.empty && !occupiedTiles.contains(targetPosition)) {
        final newMinion = Minion(
          id: 'minion_${DateTime.now().millisecondsSinceEpoch}',
          position: targetPosition,
        );
        final newMinions = List.of(state.minions)..add(newMinion);
        state = state.copyWith(minions: newMinions, player: state.player.copyWith(mana: state.player.mana - manaCost));
      } else {
        return; // Don't end turn if summon failed
      }
    } else if (spell.shape == SpellShape.raiseDead) {
      final targetPosition = (targetX, targetY);
      final corpse = state.corpsesOnGrid[targetPosition];

      if (corpse != null) {
        final newMinion = Minion(
          id: 'undead_${corpse.id}_${DateTime.now().millisecondsSinceEpoch}',
          position: targetPosition,
          type: corpse.type, // This minion is an undead version of the corpse's type
        );
        final newMinions = List.of(state.minions)..add(newMinion);
        final newCorpses = Map.of(state.corpsesOnGrid)..remove(targetPosition);
        final newGrid = state.grid.map((row) => List.of(row)).toList();
        newGrid[targetY][targetX] = SpaceType.empty;

        state = state.copyWith(minions: newMinions, corpsesOnGrid: newCorpses, grid: newGrid, player: state.player.copyWith(mana: state.player.mana - manaCost));
      } else {
        return; // Can't raise what isn't dead
      }
    } else {
      List<Enemy> currentEnemies = List.from(state.enemies);
      final newTerrainEffects = Map.of(state.terrainEffects);

      // Calculate new mana but don't update state yet
      final newMana = state.player.mana - manaCost;

      final Set<(int, int)> affectedTiles = getAffectedTilesForCurrentSpell(
        // The AOE calculation is based on the target position
        targetPosition: (targetX, targetY),
      );

      // Check for terrain interactions from the spell itself
      for (final tilePos in affectedTiles) {
        if (spell.element == SpellElement.fire && state.grid[tilePos.$2][tilePos.$1] == SpaceType.forest) {
          // Set the forest tile on fire
          newTerrainEffects[tilePos] = const TerrainEffect(type: TerrainEffectType.burning, duration: 3);
        }
      }

      for (int i = 0; i < currentEnemies.length; i++) {
        final enemy = currentEnemies[i];
        if (affectedTiles.contains(enemy.position)) {
          final int damage = _calculateSpellDamage(spell.element, enemy); // Calculate damage per enemy
          List<StatusEffect> newStatusEffects = List.of(enemy.statusEffects);

          // If it's a fire spell, apply or refresh the Burn status effect.
          if (spell.element == SpellElement.fire) {
            // Remove any existing burn effect to refresh its duration.
            newStatusEffects.removeWhere((effect) => effect.type == StatusEffectType.burn);
            newStatusEffects.add(const StatusEffect(type: StatusEffectType.burn, duration: _burnDuration));
          }
          // If it's a water spell, apply or refresh the Frozen status effect.
          if (spell.element == SpellElement.water) {
            // Remove any existing frozen effect to refresh its duration.
            newStatusEffects.removeWhere((effect) => effect.type == StatusEffectType.frozen);
            newStatusEffects.add(const StatusEffect(type: StatusEffectType.frozen, duration: _freezeDuration));
          }

          currentEnemies[i] = enemy.copyWith(health: enemy.health - damage, statusEffects: newStatusEffects);
        }
      }

      // Apply pushback for air spells after damage and status effects
      if (spell.element == SpellElement.air) {
        currentEnemies = _applyPushback(currentEnemies, affectedTiles, state.player.position);
      }

      final List<Enemy> defeatedThisCast = [];
      final List<Enemy> remainingEnemies = [];
      for (final enemy in currentEnemies) {
        if (enemy.health > 0) {
          remainingEnemies.add(enemy);
        } else {
          xpFromThisSpell += enemy.xpValue;
          defeatedThisCast.add(enemy);
        }
      }

      // Process loot drops for all defeated enemies
      final deathProcessingResult =
          _processDeaths(defeatedThisCast, state.itemsOnGrid, state.corpsesOnGrid, state.grid);

      final playerAfterLevelUp = _processLevelUp(state.player, xpFromThisSpell);

      state = state.copyWith(
        enemies: remainingEnemies,
        terrainEffects: newTerrainEffects,
        player: playerAfterLevelUp.copyWith(mana: newMana),
        itemsOnGrid: deathProcessingResult.newItemsOnGrid,
        corpsesOnGrid: deathProcessingResult.newCorpsesOnGrid,
        grid: deathProcessingResult.newGrid,
      );
    }

    _processNonPlayerTurns(isFocusing: false);
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
      case SpellShape.summon:
        return {targetPosition}; // Highlight the single tile for summoning
      case SpellShape.raiseDead:
        return {targetPosition}; // Highlight the single tile for raising
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

  /// Helper to calculate one step towards a target, prioritizing the longest axis.
  (int, int) _moveTowards((int, int) start, (int, int) target) {
    int newX = start.$1;
    int newY = start.$2;
    final dx = target.$1 - start.$1;
    final dy = target.$2 - start.$2;

    if (dx.abs() > dy.abs()) {
      newX += dx.sign;
    } else if (dy.abs() > 0) {
      newY += dy.sign;
    }
    return (newX, newY);
  }

  /// Calculates the damage for a spell, considering elemental weaknesses and resistances.
  int _calculateSpellDamage(SpellElement spellElement, Enemy? targetEnemy) {
    double baseDamage;
    switch (spellElement) {
      case SpellElement.fire: baseDamage = 30;
      case SpellElement.water: baseDamage = 25;
      case SpellElement.earth: baseDamage = 20;
      case SpellElement.air: baseDamage = 15;
    }
    
    // Check for caster's terrain bonus
    final casterPos = state.player.position;
    if (state.grid[casterPos.$2][casterPos.$1] == SpaceType.water && spellElement == SpellElement.water) {
      baseDamage *= 1.25; // 25% damage boost for water spells from water
    }

    if (targetEnemy != null) {
      // Check for target's terrain interaction
      final targetPos = targetEnemy.position;
      if (state.grid[targetPos.$2][targetPos.$1] == SpaceType.water && spellElement == SpellElement.fire) {
        baseDamage *= 0.75; // Fire is 25% weaker against targets in water
      }

      if (targetEnemy.weakness == spellElement) baseDamage *= 1.5; // 50% more damage
      if (targetEnemy.resistance == spellElement) baseDamage *= 0.5; // 50% less damage
    }

    // Add bonus damage from player's spell power
    final finalDamage = baseDamage + state.player.spellPower;

    return finalDamage.round(); // Return as an integer
  }

  /// Processes loot drops for a list of defeated enemies.
  ({
    Map<(int, int), Item> newItemsOnGrid,
    Map<(int, int), Corpse> newCorpsesOnGrid,
    List<List<SpaceType>> newGrid
  }) _processDeaths(List<Enemy> defeatedEnemies, Map<(int, int), Item> currentItems,
      Map<(int, int), Corpse> currentCorpses, List<List<SpaceType>> currentGrid) {
    if (defeatedEnemies.isEmpty) {
      return (newItemsOnGrid: currentItems, newCorpsesOnGrid: currentCorpses, newGrid: currentGrid);
    }

    final newItemsOnGrid = Map.of(currentItems);
    final newCorpsesOnGrid = Map.of(currentCorpses);
    final newGrid = currentGrid.map((row) => List.of(row)).toList();
    const lootDropChance = 0.25; // 25%

    for (final enemy in defeatedEnemies) {
      final pos = enemy.position;
      // Create a corpse
      newCorpsesOnGrid[pos] = Corpse(id: enemy.id, position: pos, type: enemy.type);
      newGrid[pos.$2][pos.$1] = SpaceType.corpse;

      // Check for loot drop
      if (Random().nextDouble() < lootDropChance) {
        // Try to place loot on an adjacent empty tile
        final adjacentTiles = [(pos.$1, pos.$2 - 1), (pos.$1, pos.$2 + 1), (pos.$1 - 1, pos.$2), (pos.$1 + 1, pos.$2)];
        adjacentTiles.shuffle();
        final lootPos = adjacentTiles.firstWhere((p) => p.$1 >= 0 && p.$1 < state.gridSize && p.$2 >= 0 && p.$2 < state.gridSize && newGrid[p.$2][p.$1] == SpaceType.empty, orElse: () => (-1, -1));

        if (lootPos != (-1, -1)) {
          final itemType = Random().nextBool() ? ItemType.healthPotion : ItemType.manaPotion;
          final newItem = Item(id: 'item_drop_${enemy.id}_${DateTime.now().millisecondsSinceEpoch}', type: itemType);
          newItemsOnGrid[lootPos] = newItem;
          newGrid[lootPos.$2][lootPos.$1] = SpaceType.item;
        }
      }
    }
    return (newItemsOnGrid: newItemsOnGrid, newCorpsesOnGrid: newCorpsesOnGrid, newGrid: newGrid);
  }

  Player _processLevelUp(Player player, int xpGained) {
    if (xpGained <= 0) return player;

    Player updatedPlayer = player.copyWith(xp: player.xp + xpGained);

    Set<SpellElement> newUnlockedElements = Set.from(updatedPlayer.unlockedElements);
    Set<SpellShape> newUnlockedSpellShapes = Set.from(updatedPlayer.unlockedSpellShapes);

    while (updatedPlayer.xp >= updatedPlayer.xpToNextLevel) {
      final int remainingXp = updatedPlayer.xp - updatedPlayer.xpToNextLevel;
      final int newLevel = updatedPlayer.level + 1;
      final int newMaxHealth = updatedPlayer.maxHealth + 10;
      final int newMaxMana = updatedPlayer.maxMana + 5;

      // Unlock new elements/shapes based on level
      if (newLevel == 2) {
        newUnlockedElements.add(SpellElement.water);
      } else if (newLevel == 3) {
        newUnlockedSpellShapes.add(SpellShape.cone);
      } else if (newLevel == 4) {
        newUnlockedElements.add(SpellElement.earth);
      } else if (newLevel == 5) {
        newUnlockedSpellShapes.add(SpellShape.wall);
      } else if (newLevel == 6) {
        newUnlockedElements.add(SpellElement.air);
      } else if (newLevel == 7) {
        newUnlockedSpellShapes.add(SpellShape.self);
      } else if (newLevel == 8) {
        newUnlockedSpellShapes.add(SpellShape.summon);
      } else if (newLevel == 9) {
        newUnlockedSpellShapes.add(SpellShape.raiseDead);
      }

      updatedPlayer = updatedPlayer.copyWith(
        level: newLevel,
        xp: remainingXp,
        xpToNextLevel: (_baseXpToNextLevel * pow(_levelXpMultiplier, newLevel - 1)).round(),
        maxHealth: newMaxHealth,
        maxMana: newMaxMana,
        health: newMaxHealth, // Full heal on level up
        mana: newMaxMana, // Full mana on level up
        unlockedElements: newUnlockedElements,
        unlockedSpellShapes: newUnlockedSpellShapes,
        spellPower: updatedPlayer.spellPower + 2,
      );
    }
    return updatedPlayer;
  }

  /// Pushes enemies back one tile if an air spell hits them.
  List<Enemy> _applyPushback(List<Enemy> enemies, Set<(int, int)> affectedTiles, (int, int) playerPos) {
    final List<Enemy> updatedEnemies = [];
    final Set<(int, int)> occupiedTiles = {...enemies.map((e) => e.position)};

    for (final enemy in enemies) {
      if (affectedTiles.contains(enemy.position)) {
        final (ex, ey) = enemy.position;
        final (px, py) = playerPos;

        // Determine primary direction of push away from the player
        final dx = ex - px;
        final dy = ey - py;

        int pushX = 0;
        int pushY = 0;

        if (dx.abs() > dy.abs()) {
          pushX = dx.sign;
        } else {
          // Prioritizes vertical push in case of a tie (diagonal)
          pushY = dy.sign;
        }

        final newPos = (ex + pushX, ey + pushY);

        // Check if the new position is valid and unoccupied
        if (newPos.$1 >= 0 &&
            newPos.$1 < state.gridSize &&
            newPos.$2 >= 0 &&
            newPos.$2 < state.gridSize &&
            state.grid[newPos.$2][newPos.$1] == SpaceType.empty &&
            !occupiedTiles.contains(newPos)) {
          updatedEnemies.add(enemy.copyWith(position: newPos));
          // Update occupied tiles for the next enemy in the loop to prevent stacking
          occupiedTiles.remove(enemy.position);
          occupiedTiles.add(newPos);
        } else {
          updatedEnemies.add(enemy); // Can't be pushed
        }
      } else {
        updatedEnemies.add(enemy); // Not affected by the spell
      }
    }
    return updatedEnemies;
  }

  /// Initializes the grid with obstacles, water, forest, and items.
  void _initializeGrid(List<List<SpaceType>> grid) {
    // Add some obstacles for demonstration
    grid[3][3] = SpaceType.obstacle;
    grid[3][4] = SpaceType.obstacle;
    grid[3][5] = SpaceType.obstacle;
    grid[10][15] = SpaceType.obstacle;
    grid[11][15] = SpaceType.obstacle;
    grid[12][15] = SpaceType.obstacle;

    // Add some water and forest tiles
    for (int i = 5; i < 10; i++) {
      grid[i][10] = SpaceType.water; // A river
    }
    grid[15][5] = SpaceType.forest;
    grid[16][5] = SpaceType.forest;
    grid[15][6] = SpaceType.forest;

    // Set the SpaceType for item locations before creating the GameState
    grid[1][1] = SpaceType.item;
    grid[8][8] = SpaceType.item;
    grid[15][15] = SpaceType.item;
  }

  /// Generates the initial wave of enemies for the game.
  List<Enemy> _generateInitialWave() {
    return const [
      Enemy(id: 'enemy_1', position: (8, 5), type: EnemyType.goblin, health: 50, weakness: SpellElement.fire, resistance: SpellElement.water, xpValue: 30),
      Enemy(id: 'enemy_2', position: (12, 10), type: EnemyType.goblin, health: 50, weakness: SpellElement.fire, resistance: SpellElement.water, xpValue: 30),
    ];
  }

  /// Resets the board and spawns the next wave of enemies.
  void _startNextWave() {
    final nextWaveNumber = state.waveNumber + 1;
    final newEnemies = _waveDefinitions[nextWaveNumber] ?? [];

    if (newEnemies.isEmpty) {
      // No more waves defined, player wins the game.
      state = state.copyWith(gameStatus: GameStatus.victory);
      return;
    }

    // Reset player position but keep their stats
    final player = state.player.copyWith(position: (0, 0));

    // Re-initialize the grid to clear corpses and dropped items from SpaceType
    final newGrid = List.generate(
      GameState.defaultGridSize,
      (_) => List.generate(GameState.defaultGridSize, (_) => SpaceType.empty),
    );
    _initializeGrid(newGrid);

    // Reset to the initial set of items on the map
    const initialItems = {
      (1, 1): Item(id: 'item_hp_1', type: ItemType.healthPotion),
      (8, 8): Item(id: 'item_mp_1', type: ItemType.manaPotion),
      (15, 15): Item(id: 'item_hp_2', type: ItemType.healthPotion),
    };

    // Update the state for the new wave
    state = state.copyWith(
      player: player,
      enemies: newEnemies,
      waveNumber: nextWaveNumber,
      itemsOnGrid: initialItems, // Reset to initial items
      corpsesOnGrid: {}, // Clear corpses
      terrainEffects: {}, // Clear effects
      minions: [], // Clear minions from previous wave
      grid: newGrid,
      gameStatus: GameStatus.playing, // Ensure it stays playing
    );
  }
}