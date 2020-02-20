import haxegon.*;
import openfl.net.SharedObject;
import haxe.Serializer;
import haxe.Unserializer;
import Vec2iTools.Vec2i;
import Vec2iTools.*;
import Vec2iTools.v_make as v;

using ArrayExtensions;

enum BoxColor {
    BoxColor_Gray;
    BoxColor_Orange;
}

typedef Box = {
    id: Int,
    pos: Vec2i,
    is_magnet: Bool,
    color: BoxColor,
    group_id: Int,
};

enum Direction {
    Direction_Down;
    Direction_Up;
    Direction_Left;
    Direction_Right;
}

typedef Snapshot = {
    player: Vec2i,
    player_dir: Direction,
    boxes: Map<Int, Vec2i>
};

@:publicFields
class Player {
// force unindent

static var pos = v(0, 0);
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
static var goals: Array<Vec2i>;
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
    goals = new Array<Vec2i>();
    history = new Array<Snapshot>();
    groups = new Map<Int, Array<Int>>();

    for (pos in v_range(v(1, 1), v(WORLD_WIDTH - 1, WORLD_HEIGHT - 1))) {
        tiles.vset(pos, Tile.Floor);
    }
    tiles[5][10] = Tile.Wall;
    tiles[5][11] = Tile.Wall;
    tiles[5][12] = Tile.Wall;

    Player.pos = v(10, 8);
    tiles.vset(Player.pos, Tile.Floor);

    // NOTE: only works if at least one of the boxes isn't connected yet
    // i.e. changing connections doesn't work
    function connect(p1: Vec2i, p2: Vec2i) {
        var b1 = boxes.vget(p1);
        var b2 = boxes.vget(p2);
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
    function toscreen(a: Vec2i): Vec2i {
        return v_mult(a, TILESIZE * SCALE);
    }
    function drawtile(pos: Vec2i, name: String, tile: Int) {
        Gfx.drawtile(pos.x, pos.y, name, tile);
    }

    Gfx.clearscreen();
    Gfx.scale(SCALE);

    // Draw tiles
    for (pos in v_range(v(0, 0), v(WORLD_WIDTH, WORLD_HEIGHT))) {
        drawtile(toscreen(pos), 'tiles', tiles.vget(pos));
    }

    // Draw goals
    for (g in goals) {
        drawtile(toscreen(g), 'tiles', Tile.Goal);
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

        drawtile(toscreen(box.pos), 'tiles', box_tile);
    }

    // Draw connections
    for (g_id in groups.keys()) {
        var group = groups[g_id];

        // Only draw right and down for each position
        for (id in group) {
            var box = boxes_by_id[id];
            var right = v_add(box.pos, v(1, 0));
            var down = v_add(box.pos, v(0, 1));

            var right_box = boxes.vget(right);
            var down_box = boxes.vget(down);

            function centered(a: Vec2i) {
                var halftile = Math.round(TILESIZE / 2);
                return v_add(toscreen(a), v(halftile, halftile));
            };
            function drawline(p1: Vec2i, p2: Vec2i, color: Int) {
                Gfx.drawline(p1.x, p1.y, p2.x, p2.y, color);
            }

            if (right_box != null && right_box.group_id == box.group_id) {
                drawline(centered(box.pos), centered(right), Col.RED);
            }
            if (down_box != null && down_box.group_id == down_box.group_id) {
                drawline(centered(box.pos), centered(down), Col.RED);
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
    drawtile(toscreen(Player.pos), 'tiles', player_tile);
}

static function move_box(from: Vec2i, d: Vec2i) {
    var to = v_add(from, d);
    boxes.vset(to, boxes.vget(from));
    boxes.vset(from, null);
    var box = boxes.vget(to);
    box.pos = to;
}

static function init_new_level(name: String) {
    var level_file = SharedObject.getLocal(name);

    // Default tiles are all floor with walls on the sides
    var default_tiles = [for (x in 0...WORLD_WIDTH) [for (y in 0...WORLD_HEIGHT) Tile.Wall]];
    for (pos in v_range(v(1, 1), v(13, 13))) {
        default_tiles.vset(pos, Tile.Floor);
    }
    level_file.data.tiles = default_tiles;

    level_file.data.goals = Serializer.run(new Array<Vec2i>());

    level_file.data.boxes = Serializer.run([for (i in 0...WORLD_WIDTH) [for (j in 0...WORLD_HEIGHT) null]]);

    level_file.data.groups = Serializer.run(new Map<Int, Array<Int>>());

    level_file.data.player_pos = Serializer.run(v(5, 5));

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
    for (pos in v_range(v(0, 0), v(WORLD_WIDTH, WORLD_HEIGHT))) {
        if (boxes.vget(pos) != null) {
            var box = boxes.vget(pos);
            boxes_by_id[box.id] = box;
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
    var boxes_snapshot = new Map<Int, Vec2i>();
    for (id in boxes_by_id.keys()) {
        var box = boxes_by_id[id];
        boxes_snapshot[id] = box.pos;
    }

    history.push({
        player: v_copy(Player.pos),
        player_dir: Player.direction,
        boxes: boxes_snapshot
    });
}

static function undo() {
    if (history.length == 0) {
        return;
    }

    var s = history.pop();
    
    Player.pos = v_copy(s.player);
    Player.direction = s.player_dir;

    for (pos in v_range(v(0, 0), v(WORLD_WIDTH, WORLD_HEIGHT))) {
        boxes.vset(pos, null);
    }
    for (box_id in s.boxes.keys()) {
        var box = boxes_by_id[box_id];
        var old_pos = s.boxes[box_id];
        box.pos = v_copy(old_pos);

        boxes.vset(box.pos, box);
    }
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
    var player_d = v(0, 0);
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
    var stack = new Array<Vec2i>();
    var first_pos = v_add(Player.pos, player_d);
    stack.push(first_pos);
    checked.vset(first_pos, true);

    // Player can't walk on water
    if (tiles.vget(first_pos) == Tile.Water) {
        can_move = false;
    }

    // Can't push boxes backwards
    if (moving_backwards && boxes.vget(first_pos) != null) {
        can_move = false;
    }

    while (stack.length > 0) {
        var pos = stack.pop();
        checked.vset(pos, true);
        var box = boxes.vget(pos);

        if (box != null) {
            function add_group(group: Array<Int>) {
                for (id in group) {
                    var box_from_group = boxes_by_id[id];
                    if (!checked.vget(box_from_group.pos)) {
                        stack.push(v_copy(box_from_group.pos));
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
            var dest = v_add(pos, player_d);
            if (!checked.vget(dest)) {
                stack.push(dest);
            }
        } else if (tiles.vget(pos) == Tile.Wall) {
            // Encountered wall, therefore can't move
            can_move = false;
            break;
        }
    }

    //
    // Move everything that was marked for moving
    //
    if (can_move && !v_eql(player_d, v(0, 0))) {
        save_snapshot();
        // Move player
        Player.pos = v_add(Player.pos, player_d);

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
                        move_box(v(x, y), player_d);
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
                        move_box(v(x, y), player_d);
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
    for (pos in v_range(v(0, 0), v(WORLD_WIDTH, WORLD_HEIGHT))) {
        var box = boxes.vget(pos);
        if (box != null && box.is_magnet) {
            box.is_magnet = false;
        }    
    }

    // Figure out which boxes are in magnet group
    var checked_magnet = Data.create2darray(WORLD_WIDTH, WORLD_HEIGHT, false);
    var magnet_dest = v_copy(Player.pos);
    switch (Player.direction) {
        case Direction_Left: magnet_dest.x--;
        case Direction_Right: magnet_dest.x++;
        case Direction_Up: magnet_dest.y--;
        case Direction_Down: magnet_dest.y++;
    }
    if (boxes.vget(magnet_dest) != null) {
        function add_box(pos: Vec2i) {
            var box = boxes.vget(pos);
            checked_magnet.vset(pos, true);
            box.is_magnet = true;
            magnet_group.push(box.id);

            var cardinals = [v(-1, 0), v(1, 0), v(0, -1), v(0, 1)];
            for (dir in cardinals) {
                var neighbor = v_add(pos, dir);

                if (!checked_magnet.vget(neighbor)) {
                    var box = boxes.vget(neighbor);
                    if (box != null && box.color == boxes.vget(pos).color) {
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
