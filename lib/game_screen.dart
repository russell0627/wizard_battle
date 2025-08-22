import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'game_controller.dart';
import 'game_state.dart';
import 'spell.dart';

class GameScreen extends ConsumerStatefulWidget {
  const GameScreen({super.key});

  @override
  ConsumerState<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends ConsumerState<GameScreen> with SingleTickerProviderStateMixin {
  late final FocusNode _focusNode;
  (int, int)? _hoveredTile; // New: Track the tile the mouse is hovering over
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _focusNode = FocusNode();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _focusNode.dispose();
    _tabController.dispose();
    super.dispose();
  }

  // Helper maps to define unlock levels for elements and shapes
  final Map<SpellElement, int> _elementUnlockLevels = {
    SpellElement.fire: 1,
    SpellElement.water: 2,
    SpellElement.earth: 4,
    SpellElement.air: 6,
  };

  final Map<SpellShape, int> _shapeUnlockLevels = {
    SpellShape.ball: 1,
    SpellShape.cone: 3,
    SpellShape.wall: 5,
    SpellShape.self: 7,
    SpellShape.summon: 8,
    SpellShape.raiseDead: 9,
  };

  // Helper to get the required level for an element/shape
  int _getRequiredLevel(dynamic type) =>
      type is SpellElement ? _elementUnlockLevels[type]! : _shapeUnlockLevels[type]!;

  /// Helper method to get the correct icon for an enemy type.
  IconData _getEnemyIcon(EnemyType type) {
    switch (type) {
      case EnemyType.goblin:
        return Icons.bug_report; // Default goblin
      case EnemyType.archer:
        return Icons.track_changes; // Ranged attacker
      case EnemyType.ogre:
        return Icons.shield; // Tanky enemy
    }
  }

  @override
  Widget build(BuildContext context) {
    // Watch the game state from the controller
    final gameState = ref.watch(gameControllerProvider);
    final gameController = ref.read(gameControllerProvider.notifier);

    final (playerX, playerY) = gameState.player.position;
    final gridSize = gameState.gridSize;
    final enemyMap = {for (var e in gameState.enemies) e.position: e};
    final itemMap = gameState.itemsOnGrid; // New: Map of items on the grid
    final corpseMap = gameState.corpsesOnGrid;
    final minionMap = {for (var m in gameState.minions) m.position: m};

    // --- FOG OF WAR CALCULATION ---
    // Creates a diamond-shaped visible area around the player.
    const int visibilityRadius = 8;
    final Set<(int, int)> visibleTiles = {};
    for (int y = 0; y < gridSize; y++) {
      for (int x = 0; x < gridSize; x++) {
        final distance = (x - playerX).abs() + (y - playerY).abs();
        if (distance <= visibilityRadius) {
          visibleTiles.add((x, y));
        }
      }
    }

    // Get the tiles affected by the currently selected spell for UI highlighting
    // The AOE is now calculated based on the hovered tile.
    final Set<(int, int)> affectedSpellTiles =
        gameController.getAffectedTilesForCurrentSpell(targetPosition: _hoveredTile);

    // --- UI PREVIEW CALCULATION ---
    // Calculate Ogre stomp preview tiles
    final Set<(int, int)> affectedStompHoverTiles = {};
    if (_hoveredTile != null) {
      final enemyOnHoveredTile = enemyMap[_hoveredTile];
      if (enemyOnHoveredTile != null && enemyOnHoveredTile.type == EnemyType.ogre) {
        final (ex, ey) = enemyOnHoveredTile.position;
        for (int x = ex - 1; x <= ex + 1; x++) {
          for (int y = ey - 1; y <= ey + 1; y++) {
            if (x >= 0 && x < gridSize && y >= 0 && y < gridSize && (x, y) != (ex, ey)) {
              affectedStompHoverTiles.add((x, y));
            }
          }
        }
      }
    }

    return RawKeyboardListener(
      focusNode: _focusNode,
      autofocus: true,
      onKey: (event) {
        if (event is RawKeyDownEvent) {
          switch (event.logicalKey) {
            case LogicalKeyboardKey.arrowUp:
              gameController.move(Direction.up);
              break;
            case LogicalKeyboardKey.arrowDown:
              gameController.move(Direction.down);
              break;
            case LogicalKeyboardKey.arrowLeft:
              gameController.move(Direction.left);
              break;
            case LogicalKeyboardKey.arrowRight:
              gameController.move(Direction.right);
              break;
          }
        }
      },
      child: Stack(
        children: [
          Scaffold(
            backgroundColor: Colors.grey[900],
            appBar: AppBar(
              title: const Text('Wizard Battle'),
              centerTitle: true,
              backgroundColor: Colors.grey[850], // Darker AppBar
              foregroundColor: Colors.white, // White text for AppBar
            ),
            body: Center(
              child: Row( // Changed from Column to Row for horizontal layout
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start, // Align content to the top
                children: [
                  // Left Side: Movement Controls
                  Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.start, // Align content to the top
                      children: [
                        const Text(
                          'Movement',
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
                        ),
                        const SizedBox(height: 16),
                        ElevatedButton(
                          onPressed: () => gameController.move(Direction.up),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.blueGrey,
                            foregroundColor: Colors.white,
                            minimumSize: const Size(60, 60), // Make buttons larger
                          ),
                          child: const Icon(Icons.arrow_upward),
                        ),
                        Row(
                          children: [
                            ElevatedButton(
                              onPressed: () => gameController.move(Direction.left),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.blueGrey,
                                foregroundColor: Colors.white,
                                minimumSize: const Size(60, 60),
                              ),
                              child: const Icon(Icons.arrow_back),
                            ),
                            const SizedBox(width: 8),
                            ElevatedButton(
                              onPressed: () => gameController.move(Direction.right),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.blueGrey,
                                foregroundColor: Colors.white,
                                minimumSize: const Size(60, 60),
                              ),
                              child: const Icon(Icons.arrow_forward),
                            ),
                          ],
                        ),
                        ElevatedButton(
                          onPressed: () => gameController.move(Direction.down),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.blueGrey,
                            foregroundColor: Colors.white,
                            minimumSize: const Size(60, 60),
                          ),
                          child: const Icon(Icons.arrow_downward),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 16), // Spacer between left UI and grid
                  // Game Grid
                  SizedBox(
                    width: 600, // Increased size to accommodate more cells
                    height: 600, // Increased size to accommodate more cells
                    child: GridView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: gridSize * gridSize,
                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: gridSize,
                      ),
                      itemBuilder: (context, index) {
                        final x = index % gridSize;
                        final y = index ~/ gridSize;

                        final isPlayerPosition = (x, y) == (playerX, playerY);
                        final enemyOnTile = enemyMap[(x, y)];
                        final minionOnTile = minionMap[(x, y)];
                        final itemOnTile = itemMap[(x, y)]; // New: Item on this tile
                        final corpseOnTile = corpseMap[(x, y)];
                        // Check if this cell is affected by the current spell
                        final isAffectedBySpell = affectedSpellTiles.contains((x, y));
                        final spaceType = gameState.grid[y][x];
                        final bool isStompHover = affectedStompHoverTiles.contains((x, y));
                        final bool isVisible = visibleTiles.contains((x, y));

                        return MouseRegion(
                          onEnter: (_) => setState(() => _hoveredTile = (x, y)),
                          onExit: (_) => setState(() => _hoveredTile = null),
                          child: GestureDetector(
                            onTap: () => gameController.castSpellAt(x, y),
                            child: Container(
                              decoration: BoxDecoration(
                                border: Border.all(
                                  color: isVisible
                                      ? Colors.grey.shade200
                                      : Colors.grey.shade800,
                                  width: isVisible ? 1.0 : 0.5,
                                ),
                                color: spaceType == SpaceType.obstacle // Obstacle color
                                    ? Colors.grey.shade700
                                    : spaceType == SpaceType.water
                                    ? Colors.blue.shade800
                                    : spaceType == SpaceType.forest
                                    ? Colors.green.shade800
                                    : spaceType == SpaceType.corpse
                                    ? Colors.brown.shade800
                                    : isPlayerPosition // Player color
                                        ? Colors.blueAccent
                                        : isVisible && itemOnTile != null // Item color
                                            ? Colors.orange.shade700
                                            : isVisible && minionOnTile != null // Minion color
                                                ? Colors.lightGreen.shade600
                                                : isVisible && isAffectedBySpell // Spell affected tile color
                                                    ? Colors.blue.withAlpha(77) // A lighter blue for affected tiles
                                                    : isVisible && enemyOnTile != null // Enemy color
                                                        ? Colors.redAccent // Distinct color for enemies
                                                        : Colors.grey[800], // Empty cell color
                              ),
                              child: Stack(
                                fit: StackFit.expand,
                                alignment: Alignment.center,
                                children: [
                                  // Render entities only if the tile is visible
                                  if (isVisible) ...[
                                    if (isPlayerPosition)
                                      const Icon(Icons.person, color: Colors.white) // Player
                                    else if (itemOnTile != null)
                                      Icon(
                                          itemOnTile.type == ItemType.healthPotion ? Icons.local_hospital : Icons.auto_awesome,
                                          color: Colors.white)
                                    else if (corpseOnTile != null) // Display a "do not disturb" icon for corpses
                                      const Icon(Icons.do_not_disturb_alt, color: Colors.white70)
                                    else if (minionOnTile != null || enemyOnTile != null)
                                      FittedBox(
                                        child: Column(
                                          mainAxisAlignment: MainAxisAlignment.center,
                                          children: [
                                            Row(
                                              mainAxisAlignment: MainAxisAlignment.center,
                                              children: [
                                                if (minionOnTile != null && minionOnTile.type != null)
                                                  ColorFiltered(
                                                      colorFilter: const ColorFilter.mode(Colors.greenAccent, BlendMode.modulate),
                                                      child: Icon(_getEnemyIcon(minionOnTile.type!), color: Colors.white))
                                                else
                                                  Icon(minionOnTile != null ? Icons.support : _getEnemyIcon(enemyOnTile!.type), color: Colors.white),
                                                if (enemyOnTile?.statusEffects.any((e) => e.type == StatusEffectType.burn) ?? false)
                                                  const Icon(Icons.local_fire_department, color: Colors.orangeAccent, size: 16),
                                                if (enemyOnTile?.statusEffects.any((e) => e.type == StatusEffectType.frozen) ?? false)
                                                  const Icon(Icons.ac_unit, color: Colors.lightBlueAccent, size: 16),
                                              ],
                                            ),
                                            Text(
                                              'HP: ${minionOnTile?.health ?? enemyOnTile?.health}'
                                              '${enemyOnTile?.weakness != null ? ' W:${enemyOnTile!.weakness!.name[0].toUpperCase()}' : ''}'
                                              '${enemyOnTile?.resistance != null ? ' R:${enemyOnTile!.resistance!.name[0].toUpperCase()}' : ''}',
                                              style: const TextStyle(color: Colors.white),
                                            ),
                                          ],
                                        ),
                                      ),
                                    // Terrain Effect Icon
                                    if (gameState.terrainEffects[(x, y)]?.type == TerrainEffectType.burning)
                                      Container(
                                        color: Colors.orange.withAlpha(102),
                                        child: const Icon(Icons.local_fire_department, color: Colors.redAccent),
                                      ),
                                  ],
                                  // Fog of War Overlay
                                  if (isVisible && isStompHover)
                                    Container(color: Colors.red.withAlpha(80)),
                                  if (!isVisible) Container(color: Colors.black.withAlpha(150)),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(width: 16), // Spacer between grid and right UI
                  // Right Side: Other UI elements
                  Expanded( // Allows the column to take available space
                    child: Column(
                      children: [
                        TabBar(
                          controller: _tabController,
                          labelColor: Colors.white,
                          unselectedLabelColor: Colors.grey,
                          indicatorColor: Colors.blueAccent,
                          tabs: const [
                            Tab(icon: Icon(Icons.person), text: 'Info'),
                            Tab(icon: Icon(Icons.inventory), text: 'Inventory'),
                            Tab(icon: Icon(Icons.bolt), text: 'Actions'),
                          ],
                        ),
                        Expanded(
                          child: TabBarView(
                            controller: _tabController,
                            children: [
                              // Info Tab
                              SingleChildScrollView(
                                padding: const EdgeInsets.all(16.0),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text('Level: ${gameState.player.level}', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
                                    const SizedBox(height: 4),
                                    LinearProgressIndicator(
                                      value: gameState.player.xp / gameState.player.xpToNextLevel,
                                      backgroundColor: Colors.grey.shade700,
                                      valueColor: const AlwaysStoppedAnimation<Color>(Colors.lightBlueAccent),
                                    ),
                                    Text('XP: ${gameState.player.xp} / ${gameState.player.xpToNextLevel}', style: const TextStyle(fontSize: 14, color: Colors.white70)),
                                    const SizedBox(height: 8),
                                    Text('Player Health: ${gameState.player.health} / ${gameState.player.maxHealth}', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
                                    const SizedBox(height: 8),
                                    Text('Player Mana: ${gameState.player.mana}/${gameState.player.maxMana}', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
                                    const SizedBox(height: 8),
                                    Text('Spell Power: ${gameState.player.spellPower}', style: const TextStyle(fontSize: 16, color: Colors.white)),
                                    const SizedBox(height: 8),
                                    Text('Enemies Remaining: ${gameState.enemies.length}', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
                                  ],
                                ),
                              ),
                              // Inventory Tab
                              SingleChildScrollView(
                                padding: const EdgeInsets.all(16.0),
                                child: Column(
                                  children: [
                                    ...gameState.player.inventory.map((item) {
                                      return Padding(
                                        padding: const EdgeInsets.symmetric(vertical: 4.0),
                                        child: ElevatedButton(
                                          onPressed: () => gameController.useItem(item),
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: item.type == ItemType.healthPotion ? Colors.red.shade700 : Colors.blue.shade700,
                                            foregroundColor: Colors.white,
                                          ),
                                          child: Row(
                                            mainAxisAlignment: MainAxisAlignment.center,
                                            children: [
                                              Icon(item.type == ItemType.healthPotion ? Icons.local_hospital : Icons.auto_awesome),
                                              const SizedBox(width: 8),
                                              Text(item.type.name.replaceAll(RegExp(r'(?<!^)(?=[A-Z])'), r' ')),
                                            ],
                                          ),
                                        ),
                                      );
                                    }).toList(),
                                    if (gameState.player.inventory.isEmpty)
                                      const Text('Inventory is empty', style: TextStyle(color: Colors.grey)),
                                  ],
                                ),
                              ),
                              // Actions Tab
                              Padding(
                                padding: const EdgeInsets.all(16.0),
                                child: Wrap(
                                  spacing: 8.0,
                                  runSpacing: 8.0,
                                  alignment: WrapAlignment.center,
                                  children: [
                                    ElevatedButton(
                                      onPressed: gameState.player.dashCooldown == 0 ? () => gameController.dash(gameState.playerDirection) : null,
                                      style: ElevatedButton.styleFrom(backgroundColor: Colors.blueGrey, foregroundColor: Colors.white),
                                      child: Text(gameState.player.dashCooldown == 0 ? 'Dash' : 'Dash CD: ${gameState.player.dashCooldown}'),
                                    ),
                                    ElevatedButton(
                                      onPressed: () => gameController.wait(),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: Colors.grey.shade600,
                                        foregroundColor: Colors.white,
                                      ),
                                      child: const Text('Wait'),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                        // Spell Settings (remain outside the tabs)
                        const Padding(
                          padding: EdgeInsets.only(top: 16.0, left: 16.0, right: 16.0),
                          child: Text('Select Spell:', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                          child: Wrap(
                            spacing: 8.0,
                            runSpacing: 4.0,
                            alignment: WrapAlignment.center,
                            children: SpellElement.values.map((element) {
                              return ChoiceChip(
                                label: Text(
                                  gameState.player.unlockedElements.contains(element) ? element.name : '${element.name} (Lvl ${_getRequiredLevel(element)})',
                                  style: TextStyle(color: gameState.player.unlockedElements.contains(element) ? Colors.white : Colors.grey),
                                ),
                                backgroundColor: gameState.player.unlockedElements.contains(element) ? Colors.grey[700] : Colors.grey[900],
                                selectedColor: Colors.blueAccent,
                                selected: gameState.selectedElement == element,
                                onSelected: (selected) {
                                  if (selected) gameController.selectElement(element);
                                },
                              );
                            }).toList(),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16.0),
                          child: Wrap(
                            spacing: 8.0,
                            runSpacing: 4.0,
                            alignment: WrapAlignment.center,
                            children: SpellShape.values.map((shape) {
                              return ChoiceChip(
                                label: Text(
                                  gameState.player.unlockedSpellShapes.contains(shape) ? shape.name : '${shape.name} (Lvl ${_getRequiredLevel(shape)})',
                                  style: TextStyle(color: gameState.player.unlockedSpellShapes.contains(shape) ? Colors.white : Colors.grey),
                                ),
                                backgroundColor: gameState.player.unlockedSpellShapes.contains(shape) ? Colors.grey[700] : Colors.grey[900],
                                selectedColor: Colors.blueAccent,
                                selected: gameState.selectedSpellShape == shape,
                                onSelected: (selected) {
                                  if (selected) gameController.selectSpellShape(shape);
                                },
                              );
                            }).toList(),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Game Over/Victory Overlay
          if (gameState.gameStatus != GameStatus.playing)
            Positioned.fill(
              child: Container(
                color: Colors.black54,
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        gameState.gameStatus == GameStatus.victory
                            ? 'VICTORY!'
                            : 'GAME OVER!',
                        style: const TextStyle(
                            fontSize: 48,
                            fontWeight: FontWeight.bold,
                            color: Colors.white),
                      ),
                      const SizedBox(height: 24),
                      ElevatedButton(
                        onPressed: gameController.restartGame,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(
                              horizontal: 40, vertical: 20),
                          textStyle: const TextStyle(fontSize: 24),
                        ),
                        child: const Text('Restart Game'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}