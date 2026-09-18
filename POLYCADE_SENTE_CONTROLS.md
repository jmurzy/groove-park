## Polycade Sente controls

The Polycade Sente supports two players, with a complete and identical set of
controls for each player. The table below describes one set; the same controls
and mappings apply to both Player 1 and Player 2.

| Panel control | Color | Controller mapping | Location |
| --- | --- | --- | --- |
| Joystick | Red ball top, black base | Digital 8-way stick | Left side of the panel |
| Exit | White | Guide / Home | Top row, left; marked with an X symbol |
| Select | White | Back / Select | Top row, center; marked with three horizontal lines |
| Start | White | Start | Top row, right; marked with a triangle symbol |
| X | Blue | X button | Action cluster, upper-left |
| Y | Yellow | Y button | Action cluster, upper-center |
| LB | Orange | Left bumper | Action cluster, upper-right |
| A | Green | A button | Action cluster, lower-left |
| B | Red | B button | Action cluster, lower-center |
| RB | Purple | Right bumper | Action cluster, lower-right |
| LT | White | Left trigger | Bottom row, left |
| RT | White | Right trigger | Bottom row, right |

The joystick is digital and supports all eight directions: up, down, left,
right, and the four diagonals.

## ASCII panel layout

```text
+--------------------------------+  +--------------------------------+
| PLAYER 1                       |  | PLAYER 2                       |
|         [EXIT] [SELECT] [START]|  |         [EXIT] [SELECT] [START]|
| [8-WAY]    [X]    [Y]    [LB]  |  | [8-WAY]    [X]    [Y]    [LB]  |
|   JOY      [A]    [B]    [RB]  |  |   JOY      [A]    [B]    [RB]  |
|           [LT]          [RT]   |  |           [LT]          [RT]   |
+--------------------------------+  +--------------------------------+
```

## Polycade Sente Controller board

The controls use Polycade Neo-Arcade Controller Boards, native XInput boards
developed with Brook Gaming for arcade machines. XInput is the standard Xbox
controller protocol used by Windows PC games, including many games available
through Steam. Its standardized controls provide broad compatibility with both
classic and modern games and reduce the need to remap buttons for each game.

Each board has a fixed player position configured in hardware. This keeps the
two control sets assigned consistently to Player 1 and Player 2 instead of
allowing their order to change between sessions. Neo-Arcade boards support
fixed positions for configurations of up to four players, although the Sente
panel provides controls for two players.

The boards operate exclusively in XInput mode. They do not provide a protocol
switch that could accidentally change them to DInput or keyboard mode and
invalidate the expected control mappings.