import haxegon.*;
import openfl.net.SharedObject;
import haxe.Serializer;
import haxe.Unserializer;

enum BoxColor {
    BoxColor_Gray;
    BoxColor_Orange;
}

typedef Box = {
    id: Int,
    x: Int,
    y: Int,
    is_magnet: Bool,
    color: BoxColor,
    group_id: Int,
};

typedef IntVector2 = {
    x: Int,
    y: Int,
}

enum Direction {
    Direction_Down;
    Direction_Up;
    Direction_Left;
    Direction_Right;
}

typedef Snapshot = {
    player: IntVector2,
    player_dir: Direction,
    boxes: Map<Int, IntVector2>
};

@:publicFields
class Player {
// force unindent

static var pos: IntVector2 = {x: 0, y: 0};
static var direction = Direction_Up;

}


@:publicFields
class Game {
// force unindent

static inline var WORLD_WIDTH = 20;
static inline var WORLD_HEIGHT = 20;
static inline var TILESIZE = 16;
static inline var SCALE = 4;

static var tiles: Array<Array<Int>>;
static var goals: Array<IntVector2>;
static var boxes: Array<Array<Box>>;
static var boxes_by_id: Map<Int, Box>;

static var groups: Map<Int, Array<Int>>;
static inline var GROUP_ID_NONE = -1;
static var group_id_max = GROUP_ID_NONE + 1;
static var magnet_group = new Array<Int>();
static var history: Array<Snapshot>;

function new() {

}

static function init() {
    tiles = Data.create2darray(WORLD_WIDTH, WORLD_HEIGHT, Tile.Wall);
    boxes_by_id = new Map<Int, Box>();
    // boxes = Data.create2darray(WORLD_WIDTH, WORLD_HEIGHT, null);
    boxes = [for (i in 0...WORLD_WIDTH) [for (j in 0...WORLD_HEIGHT) null]];
    goals = new Array<IntVector2>();
    history = new Array<Snapshot>();
    groups = new Map<Int, Array<Int>>();

    for (x in 1...(WORLD_WIDTH - 1)) {
        for (y in 1...(WORLD_HEIGHT - 1)) {
            tiles[x][y] = Tile.Floor;
        }
    }
    tiles[5][10] = Tile.Wall;
    tiles[5][11] = Tile.Wall;
    tiles[5][12] = Tile.Wall;

    Player.pos.x = 10;
    Player.pos.y = 8;
    tiles[Player.pos.x][Player.pos.y] = Tile.Floor;

    // NOTE: only works if at least one of the boxes isn't connected yet
    // i.e. changing connections doesn't work
    function connect(p1: IntVector2, p2: IntVector2) {
        var b1 = boxes[p1.x][p1.y];
        var b2 = boxes[p2.x][p2.y];
        var new_group = false;
        if (b1.group_id != GROUP_ID_NONE) {
            var group_id = b1.group_id;
            groups[group_id].push(b2.id);
            b2.group_id = group_id;
        } else if (b2.group_id != GROUP_ID_NONE) {
            var group_id = b2.group_id;
            groups[group_id].push(b1.id);
            b1.group_id = group_id;
        } else {
            group_id_max++;
            var group_id = group_id_max;
            groups[group_id] = new Array<Int>();
            groups[group_id].push(b1.id);
            groups[group_id].push(b2.id);
            b1.group_id = group_id;
            b2.group_id = group_id;
        }
    }
}

static function render() {
    function screenx(x) {
        return x * TILESIZE * SCALE;
    }
    function screeny(y) {
        return y * TILESIZE * SCALE;
    }

    Gfx.clearscreen();
    Gfx.scale(SCALE);

    // Draw tiles
    for (x in 0...WORLD_WIDTH) {
        for (y in 0...WORLD_HEIGHT) {
            Gfx.drawtile(screenx(x), screeny(y), 'tiles', tiles[x][y]);
        }
    }

    // Draw goals
    for (g in goals) {
        Gfx.drawtile(screenx(g.x), screeny(g.y), 'tiles', Tile.Goal);
    }

    // Draw boxes
    for (box_id in boxes_by_id.keys()) {
        var box = boxes_by_id[box_id];
        var box_tile = if (box.color == BoxColor_Orange) {
            Tile.BoxOrange;
        } else if (box.is_magnet) {
            Tile.BoxMagnet;
        } else {
            Tile.Box;
        }

        Gfx.drawtile(screenx(box.x), screeny(box.y), 'tiles', box_tile);
    }

    // Draw connections
    for (g_id in groups.keys()) {
        var group = groups[g_id];

        // Only draw right and down for each position
        for (id in group) {
            var box = boxes_by_id[id];
            var p = {
                x: box.x,
                y: box.y,
            };
            var right = {
                x: p.x + 1,
                y: p.y,
            };
            var down = {
                x: p.x,
                y: p.y - 1,
            };

            var right_box = boxes[right.x][right.y];
            var down_box = boxes[down.x][down.y];

            function centerx(x) {
                return screenx(x) + TILESIZE / 2;
            };
            function centery(y) {
                return screeny(y) + TILESIZE / 2;
            };

            if (right_box != null && right_box.group_id == box.group_id) {
                Gfx.drawline(centerx(p.x), centerx(p.y), centery(right.x), centery(right.y), Col.RED);
            }
            if (down_box != null && down_box.group_id == down_box.group_id) {
                Gfx.drawline(centerx(p.x), centerx(p.y), centery(down.x), centery(down.y), Col.RED);
            }
        }
    }

    // Draw player
    var player_tile = switch (Player.direction) {
        case Direction_Left: Tile.PlayerLeft;
        case Direction_Right: Tile.PlayerRight;
        case Direction_Up: Tile.PlayerUp;
        case Direction_Down: Tile.PlayerDown;
    }
    Gfx.drawtile(screenx(Player.pos.x), screeny(Player.pos.y), 'tiles', player_tile);
}

static function move_box(from: IntVector2, d: IntVector2) {
    var to = {
        x: from.x + d.x,
        y: from.y + d.y,
    };
    boxes[to.x][to.y] = boxes[from.x][from.y];
    boxes[from.x][from.y] = null;
    var box = boxes[to.x][to.y];
    box.x = to.x;
    box.y = to.y;
}

static function init_new_level(name: String) {
    var level_file = SharedObject.getLocal(name);

    // Default tiles are all floor with walls on the sides
    var default_tiles = [for (x in 0...WORLD_WIDTH) [for (y in 0...WORLD_HEIGHT) Tile.Wall]];
    for (x in 1...13) {
        for (y in 1...13) {
            default_tiles[x][y] = Tile.Floor;
        }
    }
    level_file.data.tiles = default_tiles;

    level_file.data.goals = Serializer.run(new Array<IntVector2>());

    level_file.data.boxes = Serializer.run([for (i in 0...WORLD_WIDTH) [for (j in 0...WORLD_HEIGHT) null]]);

    level_file.data.groups = Serializer.run(new Map<Int, Array<Int>>());

    level_file.data.player_pos = Serializer.run({x: 5, y: 5});

    level_file.flush();

    load_level(name);
}

static function load_level(name: String) {
    var level_file = SharedObject.getLocal(name);
    
    tiles = level_file.data.tiles;

    goals = Unserializer.run(level_file.data.goals);

    boxes = Unserializer.run(level_file.data.boxes);

    // Setup boxes_by_id
    boxes_by_id = new Map<Int, Box>();
    for (x in 0...WORLD_WIDTH) {
        for (y in 0...WORLD_HEIGHT) {
            if (boxes[x][y] != null) {
                var box = boxes[x][y];
                boxes_by_id[box.id] = box;
            }
        }
    }

    groups = Unserializer.run(level_file.data.groups);

    // Find group_id_max
    group_id_max = 0;
    for (id in groups.keys()) {
        if (id > group_id_max) {
            group_id_max = id;
        }
    }

    history = new Array<Snapshot>();

    Player.pos = Unserializer.run(level_file.data.player_pos);
}

static function save_level(name: String) {
    var level_file = SharedObject.getLocal(name);
    
    level_file.data.tiles = tiles;

    level_file.data.goals = Serializer.run(goals);

    level_file.data.boxes = Serializer.run(boxes);

    level_file.data.groups = Serializer.run(groups);

    level_file.data.player_pos = Serializer.run(Player.pos);
}

static function save_snapshot() {
    var boxes_snapshot = new Map<Int, IntVector2>();
    for (id in boxes_by_id.keys()) {
        var box = boxes_by_id[id];
        boxes_snapshot[id] = {
            x: box.x,
            y: box.y
        };
    }

    history.push({
        player: {
            x: Player.pos.x,
            y: Player.pos.y,
        },
        player_dir: Player.direction,
        boxes: boxes_snapshot
    });
}

static function undo() {
    if (history.length == 0) {
        return;
    }

    var s = history.pop();
    
    Player.pos = s.player;
    Player.direction = s.player_dir;

    for (x in 0...WORLD_WIDTH) {
        for (y in 0...WORLD_HEIGHT) {
            boxes[x][y] = null;
        }
    }
    for (box_id in s.boxes.keys()) {
        var box = boxes_by_id[box_id];
        var old_pos = s.boxes[box_id];
        box.x = old_pos.x;
        box.y = old_pos.y;

        boxes[box.x][box.y] = box;
    }
}

static function xd<T>(arr: Array<Array<T>>, pos: IntVector2): T {
    return arr[pos.x][pos.y];
}

static function update() {
    if (Input.delaypressed(Key.Z, 10)) {
        undo();
    }

    // Change magnet direction
    // if (Input.justpressed(Key.LEFT)) {
    //     Player.direction = Direction_Left;
    //     save_snapshot();
    // } else if (Input.justpressed(Key.RIGHT)) {
    //     Player.direction = Direction_Right;
    //     save_snapshot();
    // } else if (Input.justpressed(Key.UP)) {
    //     Player.direction = Direction_Up;
    //     save_snapshot();
    // } else if (Input.justpressed(Key.DOWN)) {
    //     Player.direction = Direction_Down;
    //     save_snapshot();
    // }

    // Rotate player
    if (Input.delaypressed(Key.LEFT, 10)) {
        switch (Player.direction) {
            case Direction_Down: Player.direction = Direction_Right;
            case Direction_Right: Player.direction = Direction_Up;
            case Direction_Up: Player.direction = Direction_Left;
            case Direction_Left: Player.direction = Direction_Down;
        }
    } else if (Input.delaypressed(Key.RIGHT, 10)) {
        switch (Player.direction) {
            case Direction_Down: Player.direction = Direction_Left;
            case Direction_Left: Player.direction = Direction_Up;
            case Direction_Up: Player.direction = Direction_Right;
            case Direction_Right: Player.direction = Direction_Down;
        }
    }

    //
    // Move player
    //
    var player_d = {
        x: 0,
        y: 0,
    };
    var moving_backwards = false;

    if (Input.delaypressed(Key.UP, 10)) {
        switch (Player.direction) {
            case Direction_Down: player_d.y = 1;
            case Direction_Up: player_d.y = -1;
            case Direction_Right: player_d.x = 1;
            case Direction_Left: player_d.x = -1;
        }
    }
    if (Input.delaypressed(Key.DOWN, 10)) {
        moving_backwards = true;

        switch (Player.direction) {
            case Direction_Down: player_d.y = -1;
            case Direction_Up: player_d.y = 1;
            case Direction_Right: player_d.x = -1;
            case Direction_Left: player_d.x = 1;
        }
    }



    // if (Input.delaypressed(Key.W, 10)) {
    //     player_d.y = -1;
    // }
    // if (Input.delaypressed(Key.S, 10)) {
    //     player_d.y = 1;
    // }
    // if (Input.delaypressed(Key.A, 10)) {
    //     player_d.x = -1;
    // }
    // if (Input.delaypressed(Key.D, 10)) {
    //     player_d.x = 1;
    // }

    // // Only move if one button pressed
    // var count = 0;
    // if (Input.pressed(Key.W)) {
    //     count++;
    // }
    // if (Input.pressed(Key.A)) {
    //     count++;
    // }
    // if (Input.pressed(Key.S)) {
    //     count++;
    // }
    // if (Input.pressed(Key.D)) {
    //     count++;
    // }
    // if (count > 1) {
    //     player_d.x = 0;
    //     player_d.y = 0;
    // }

    // 
    // Find if can move
    //

    // Start from player position and recursively check all pushed positions
    var can_move = true;
    var checked = Data.create2darray(WORLD_WIDTH, WORLD_HEIGHT, false);
    var checked_group = new Map<Int, Bool>();
    var checked_magnet = false;
    var stack = new Array<IntVector2>();
    var first_pos = {
        x: Player.pos.x + player_d.x,
        y: Player.pos.y + player_d.y,
    };
    stack.push(first_pos);
    checked[first_pos.x][first_pos.y] = true;

    // Player can't walk on water
    if (xd(tiles, first_pos) == Tile.Water) {
        can_move = false;
    }

    // Can't push boxes backwards
    if (moving_backwards && xd(boxes, first_pos) != null) {
        can_move = false;
    }

    while (stack.length > 0) {
        var pos = stack.pop();
        checked[pos.x][pos.y] = true;
        var box = boxes[pos.x][pos.y];

        if (box != null) {
            function add_group(group: Array<Int>) {
                for (id in group) {
                    var b = boxes_by_id[id];
                    if (!checked[b.x][b.y]) {
                        stack.push({x: b.x, y: b.y});
                    }
                }
            }
            if (box.group_id != -1 && !checked_group.exists(box.group_id)) {
                // Check box group
                add_group(groups[box.group_id]);
                checked_group[box.group_id] = true;
            }
            if (box.is_magnet && !checked_magnet) {
                // Check magnet group
                add_group(magnet_group);
                checked_magnet = true;
            }

            // Push destination of this box if it hasn't been checked yet
            var dest = {
                x: pos.x + player_d.x,
                y: pos.y + player_d.y,
            };
            if (!checked[dest.x][dest.y]) {
                stack.push(dest);
            }
        } else if (tiles[pos.x][pos.y] == Tile.Wall) {
            // Encountered wall, therefore can't move
            can_move = false;
            break;
        }
    }

    //
    // Move everything that was marked for moving
    //
    if (can_move && (player_d.x != 0 || player_d.y != 0)) {
        save_snapshot();
        // Move player
        Player.pos.x += player_d.x;
        Player.pos.y += player_d.y;

        function in_bounds(x: Int, y: Int): Bool {
            return 0 <= x && x < WORLD_WIDTH && 0 <= y && y < WORLD_HEIGHT;
        }

        // Move boxes
        // Go backwards against player move direction, moving everything
        if (player_d.x != 0) {
            for (y in 0...WORLD_HEIGHT) {
                var x = if (player_d.x == -1) {
                    // Moving left, go back from left
                    0;
                } else {
                    // Moving right, go back from right
                    WORLD_WIDTH - 1;
                }
                while (in_bounds(x, y)) {
                    var box = boxes[x][y];
                    if (checked[x][y] && box != null) {
                        move_box({x: x, y: y}, player_d);
                    }

                    x -= player_d.x;
                }
            }
        } else if (player_d.y != 0) {
            for (x in 0...WORLD_WIDTH) {
                var found_magnet = false;
                var pushing = false;

                var y = if (player_d.y == -1) {
                    // Moving up, go back from top
                    0;
                } else {
                    // Moving down, go back from bottom
                    WORLD_HEIGHT - 1;
                }
                while (in_bounds(x, y)) {
                    var box = boxes[x][y];
                    if (checked[x][y] && box != null) {
                        move_box({x: x, y: y}, player_d);
                    }

                    y -= player_d.y;
                }
            }
        }
    }

    //
    // Find which boxes are magnets
    //

    // Clean old group mapping
    magnet_group = new Array<Int>();
    for (x in 0...WORLD_WIDTH) {
        for (y in 0...WORLD_HEIGHT) {
            var box = boxes[x][y];
            if (box != null && box.is_magnet) {
                box.is_magnet = false;
            }    
        }
    }

    // Figure out which boxes are in magnet group
    var checked_magnet = Data.create2darray(WORLD_WIDTH, WORLD_HEIGHT, false);
    var magnet_dest = {x: Player.pos.x, y: Player.pos.y};
    switch (Player.direction) {
        case Direction_Left: magnet_dest.x--;
        case Direction_Right: magnet_dest.x++;
        case Direction_Up: magnet_dest.y--;
        case Direction_Down: magnet_dest.y++;
    }
    if (boxes[magnet_dest.x][magnet_dest.y] != null) {
        function add_box(pos: IntVector2) {
            var box = boxes[pos.x][pos.y];
            checked_magnet[pos.x][pos.y] = true;
            box.is_magnet = true;
            magnet_group.push(box.id);

            var cardinals = [{x: -1, y: 0}, {x: 1, y: 0}, {x: 0, y: -1}, {x: 0, y: 1}];
            for (dir in cardinals) {
                var neighbor = {
                    x: pos.x + dir.x,
                    y: pos.y + dir.y,
                }

                if (!checked_magnet[neighbor.x][neighbor.y]) {
                    var box = boxes[neighbor.x][neighbor.y];
                    if (box != null && box.color == boxes[pos.x][pos.y].color) {
                        add_box(neighbor);
                    }
                }
            }
        }

        add_box(magnet_dest);
    }

    render();

    Text.display(0, 0, Main.current_level);

    if (Input.justpressed(Key.R)) {
        load_level(Main.current_level);
    }
}

}
