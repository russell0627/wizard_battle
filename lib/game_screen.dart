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

class _GameScreenState extends ConsumerState<GameScreen> {
  late final FocusNode _focusNode;
  (int, int)? _hoveredTile; // New: Track the tile the mouse is hovering over

  @override
  void initState() {
    super.initState();
    _focusNode = FocusNode();
  }

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Watch the game state from the controller
    final gameState = ref.watch(gameControllerProvider);
    final gameController = ref.read(gameControllerProvider.notifier);

    final (playerX, playerY) = gameState.player.position;
    final gridSize = gameState.gridSize;
    final enemyMap = {for (var e in gameState.enemies) e.position: e};

    // Get the tiles affected by the currently selected spell for UI highlighting
    // The AOE is now calculated based on the hovered tile.
    final Set<(int, int)> affectedSpellTiles =
        gameController.getAffectedTilesForCurrentSpell(targetPosition: _hoveredTile);

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
            appBar: AppBar(
              title: const Text('Wizard Battle'),
              centerTitle: true,
            ),
            body: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
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
                        // Check if this cell is affected by the current spell
                        final isAffectedBySpell = affectedSpellTiles.contains((x, y));
                        final spaceType = gameState.grid[y][x];

                        return MouseRegion(
                          onEnter: (_) => setState(() => _hoveredTile = (x, y)),
                          onExit: (_) => setState(() => _hoveredTile = null),
                          child: GestureDetector(
                            onTap: () => gameController.castSpellAt(x, y),
                            child: Container(
                              decoration: BoxDecoration(
                                border: Border.all(color: Colors.grey.shade200),
                                color: spaceType == SpaceType.obstacle // Obstacle color
                                    ? Colors.grey.shade700
                                    : isPlayerPosition // Player color
                                        ? Colors.blueAccent
                                        : isAffectedBySpell // Spell affected tile color
                                            ? Colors.lightBlue.shade100 // A lighter blue for affected tiles
                                            : enemyOnTile != null // Enemy color
                                                ? Colors.redAccent // Distinct color for enemies
                                                : Colors.white, // Empty cell color
                              ),
                              child: isPlayerPosition
                                  ? const Icon(Icons.person, color: Colors.white)
                                  : enemyOnTile != null
                                      ? Column(
                                          mainAxisAlignment: MainAxisAlignment.center,
                                          children: [
                                            const Icon(Icons.bug_report,
                                                color: Colors.white), // Icon for enemy
                                            Text(
                                              'HP: ${enemyOnTile.health}', // Display enemy health
                                              style: const TextStyle(
                                                  color: Colors.white, fontSize: 10),
                                            ),
                                          ],
                                        )
                                      : null, // Empty cell
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 16),
                  // Player Info
                  Text(
                    'Player Health: ${gameState.player.health}',
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Enemies Remaining: ${gameState.enemies.length}',
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 16),
                  // Spell Selection
                  const Text(
                    'Select Spell:',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: SpellElement.values.map((element) {
                      return Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4.0),
                        child: ChoiceChip(
                          label: Text(element.name),
                          selected: gameState.selectedElement == element,
                          onSelected: (selected) {
                            if (selected) {
                              gameController.selectElement(element);
                            }
                          },
                        ),
                      );
                    }).toList(),
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: SpellShape.values.map((shape) {
                      return Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4.0),
                        child: ChoiceChip(
                          label: Text(shape.name),
                          selected: gameState.selectedSpellShape == shape,
                          onSelected: (selected) {
                            if (selected) {
                              gameController.selectSpellShape(shape);
                            }
                          },
                        ),
                      );
                    }).toList(),
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