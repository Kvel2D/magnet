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

typedef SinkingBox = {
    box: Box,
    timer: Int,
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

class Player {
    public static var pos = v(0, 0);
    public static var direction = Direction_Up;
}


class Game {
// force unindent

public static inline var WORLD_WIDTH = 20;
public static inline var WORLD_HEIGHT = 20;
public static inline var TILESIZE = 16;
public static inline var SCALE = 3;
public static inline var SINK_TIMER_MAX = 60;

public static var tiles: Array<Array<Int>>;
public static var goals: Array<Vec2i>;
public static var boxes: Array<Array<Box>>;
public static var boxes_by_id: Map<Int, Box>;

public static var sinking_boxes: Array<SinkingBox>;

public static var groups: Map<Int, Array<Int>>;
public static inline var GROUP_ID_NONE = -1;
public static var group_id_max = GROUP_ID_NONE + 1;
static var magnet_group = new Array<Int>();
static var history: Array<Snapshot>;

public function new() {

}

public static function render() {
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

    // Draw boundary
    Gfx.drawbox(0, 0, WORLD_WIDTH * TILESIZE * SCALE, WORLD_HEIGHT * TILESIZE * SCALE, Col.PINK);

    // Draw goals
    for (g in goals) {
        drawtile(toscreen(g), 'tiles', Tile.Goal);
    }

    function box_tile(box: Box): Int {
        return if (box.color == BoxColor_Orange) {
            Tile.BoxOrange;
        } else if (box.is_magnet) {
            Tile.BoxMagnet;
        } else {
            Tile.Box;
        }
    }

    // Update and draw sinking boxes
    for (sink in sinking_boxes.copy()) {
        sink.timer--;
        if (sink.timer < 0) {
            sinking_boxes.remove(sink);
        } else {
            Gfx.imagealpha = (Math.round(sink.timer / 15) * 15 / SINK_TIMER_MAX);
            drawtile(toscreen(sink.box.pos), 'tiles', box_tile(sink.box));
        }
    }
    Gfx.imagealpha = 1.0;

    // Draw boxes
    for (box_id in boxes_by_id.keys()) {
        var box = boxes_by_id[box_id];
        
        drawtile(toscreen(box.pos), 'tiles', box_tile(box));
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

public static function load_level(name: String) {
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

    sinking_boxes = new Array<SinkingBox>();
}

public static function save_level() {
    var level_file = SharedObject.getLocal(LevelSelect.current_level);
    
    level_file.data.tiles = tiles;

    level_file.data.goals = Serializer.run(goals);

    level_file.data.boxes = Serializer.run(boxes);

    level_file.data.groups = Serializer.run(groups);

    level_file.data.player_pos = Serializer.run(Player.pos);
}

public static function update() {
    // Undo
    if (Input.delaypressed(Key.Z, 5)) {
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

    var left = Input.delaypressed(Key.LEFT, 10) || Input.delaypressed(Key.A, 10);
    var right = Input.delaypressed(Key.RIGHT, 10) || Input.delaypressed(Key.D, 10);
    var up = Input.delaypressed(Key.UP, 8) || Input.delaypressed(Key.W, 8);
    var down = Input.delaypressed(Key.DOWN, 8) || Input.delaypressed(Key.S, 8);

    var left_pressed_at_all = Input.pressed(Key.LEFT) || Input.pressed(Key.A);
    var right_pressed_at_all = Input.pressed(Key.RIGHT) || Input.pressed(Key.D);
    var up_pressed_at_all = Input.pressed(Key.UP) || Input.pressed(Key.W);
    var down_pressed_at_all = Input.pressed(Key.DOWN) || Input.pressed(Key.S);

    if (left_pressed_at_all) {
        right = false;
    }
    if (right_pressed_at_all) {
        left = false;
    }
    if (down_pressed_at_all) {
        up = false;
    }
    if (up_pressed_at_all) {
        down = false;
    }

    // Rotate player
    if (left) {
        switch (Player.direction) {
            case Direction_Down: Player.direction = Direction_Right;
            case Direction_Right: Player.direction = Direction_Up;
            case Direction_Up: Player.direction = Direction_Left;
            case Direction_Left: Player.direction = Direction_Down;
        }
    } else if (right) {
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

    if (up) {
        switch (Player.direction) {
            case Direction_Down: player_d.y = 1;
            case Direction_Up: player_d.y = -1;
            case Direction_Right: player_d.x = 1;
            case Direction_Left: player_d.x = -1;
        }
    }
    if (down) {
        moving_backwards = true;

        switch (Player.direction) {
            case Direction_Down: player_d.y = -1;
            case Direction_Up: player_d.y = 1;
            case Direction_Right: player_d.x = -1;
            case Direction_Left: player_d.x = 1;
        }
    }

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

    // Player can't walk on water or lava
    var player_tile = tiles.vget(first_pos);
    if (player_tile == Tile.Water || player_tile == Tile.Lava) {
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
        // Save world state before moving to history
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

    //
    // Sink boxes that are above water without support
    //

    // First, find which groups are supported and which aren't
    var group_is_supported = new Map<Int, Bool>();
    function check_supported(group: Array<Int>) {
        var supported = false;

        // Group is supported if at least one box in the group is not above water
        for (b_id in group) {
            var box = boxes_by_id[b_id];
            if (tiles.vget(box.pos) != Tile.Water) {
                supported = true;
                break;
            }
        }

        return supported;
    }
    for (g_id in groups.keys()) {
        var group = groups[g_id];
        group_is_supported[g_id] = check_supported(group);
    }
    var magnet_supported = check_supported(magnet_group);

    // Now check which boxes are supported
    // NOTE: a box can be both in an unsupported group and in a supported group (a multi-piece that is also magnetized, the multi-piece itself is not supported but it won't sink due to being supported by magnets)
    // So when checking the condition for box to sink is that it's not part of ANY supported groups
    for (b_id in boxes_by_id.keys()) {
        var box = boxes_by_id[b_id];
        var supported = false;

        if (tiles.vget(box.pos) != Tile.Water) {
            // Supported by itself
            supported = true;
        } else if (box.group_id != GROUP_ID_NONE && group_is_supported[box.group_id]) {
            // Supported by normal group
            supported = true;
        } else if (box.is_magnet && magnet_supported) {
            // Supported by magnet group
            supported = true;
        }

        if (!supported) {
            // Remove box
            boxes_by_id.remove(b_id);
            boxes.vset(box.pos, null);
            if (box.group_id != GROUP_ID_NONE) {
                groups[box.group_id].remove(box.id);
            }
            if (box.is_magnet) {
                magnet_group.remove(box.id);
            }
            
            // Start the sink animation
            sinking_boxes.push({
                box: box,
                timer: SINK_TIMER_MAX,
            });
        }
    }

    render();

    Text.display(0, 0, LevelSelect.current_level);

    if (Input.justpressed(Key.R)) {
        load_level(LevelSelect.current_level);
    }
}

}

