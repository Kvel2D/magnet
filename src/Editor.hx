import haxegon.*;
import flash.net.SharedObject;
import haxe.Serializer;
import Game;
import Vec2iTools.Vec2i;
import Vec2iTools.*;
import Vec2iTools.v_make as v;

using MathExtensions;
using ArrayExtensions;

enum ToolType {
    ToolType_Delete;
    ToolType_PlaceWall;
    ToolType_PlaceBox;
    ToolType_PlaceNormalBox;
    ToolType_PlaceGoal;
    ToolType_PlacePlayer;
    ToolType_PlaceWater;
}

class Editor {
// force unindent

static var current_tool = ToolType_PlaceBox;
static var HOVERING_BUTTONE = false;

public function new() {

}

static inline function mouse_x(): Int {
    return Math.floor(Mouse.x / Game.TILESIZE / Game.SCALE);
}
static inline function mouse_y(): Int {
    return Math.floor(Mouse.y / Game.TILESIZE / Game.SCALE);
}

public static function update() {    
    Game.render();
    Text.display(0, 0, LevelSelect.current_level);

    Text.display(0, Text.height(), 'editing', Col.WHITE);

    var box_size = Game.TILESIZE * Game.SCALE;
    Gfx.drawbox(mouse_x() * box_size, mouse_y() * box_size, box_size, box_size, Col.PINK);

    function button(x: Float, y: Float, text: String, selected: Bool): Bool {
        var PADDING = 10;
        var width = Text.width(text) + PADDING * 2;
        var height = Text.height(text) + PADDING * 2;

        var hovering = Math.point_box_intersect(Mouse.x, Mouse.y, x, y, width, height);
        if (hovering) {
            HOVERING_BUTTONE = true;
        }
        var button_color = if (hovering && (Mouse.leftheld() || Mouse.leftclick())) {
            Col.YELLOW;
        } else {
            Col.GRAY;
        }

        if (selected) {
            button_color = Col.YELLOW;
        }

        Gfx.fillbox(x, y, width, height, button_color);
        Text.display(x + PADDING, y + PADDING, text, Col.WHITE);
        return Mouse.leftclick() && hovering;
    }

    HOVERING_BUTTONE = false;
    var tools_x = 1000;
    var tools_y = 0;
    for (tool in Type.allEnums(ToolType)) {
        function tool_text(tool: ToolType): String {
            return switch (tool) {
                case ToolType_Delete: 'Delete';
                case ToolType_PlaceWall: 'Wall';
                case ToolType_PlaceBox: 'Magnet';
                case ToolType_PlaceNormalBox: 'Box';
                case ToolType_PlaceGoal: 'Goal';
                case ToolType_PlacePlayer: 'Player';
                case ToolType_PlaceWater: 'Water';
            }
        }

        if (button(tools_x, tools_y, tool_text(tool), current_tool == tool)) {
            current_tool = tool;
        }
        tools_y += 40;
    }
    if (button(tools_x, tools_y, 'Reset', false)) {
        Game.init_new_level(LevelSelect.current_level);
    }

    function tool_shortcut(key, tool) {
        if (Input.justpressed(key)) {
            current_tool = tool;
        }
    }
    tool_shortcut(Key.D, ToolType_Delete);
    tool_shortcut(Key.B, ToolType_PlaceBox);
    tool_shortcut(Key.N, ToolType_PlaceNormalBox);
    tool_shortcut(Key.G, ToolType_PlaceGoal);
    tool_shortcut(Key.P, ToolType_PlacePlayer);
    tool_shortcut(Key.W, ToolType_PlaceWall);
    tool_shortcut(Key.H, ToolType_PlaceWater);

    if (!HOVERING_BUTTONE && (Mouse.leftclick() || Mouse.leftheld())) {
        var x = mouse_x();
        var y = mouse_y();

        var no_player = !v_eql(Player.pos, v(x, y));
        var box_here = Game.boxes[x][y] != null;

        function get_box_id(): Int {
            // Find lowest available box id
            var free_id = -1;
            for (id in 0...100) {
                if (!Game.boxes_by_id.exists(id)) {
                    free_id = id;
                    break;
                }
            }

            if (free_id == -1) {
                trace('RAN OUT OF BOX IDS');
            }

            return free_id;
        }

        function delete(x, y) {
            // Remove wall
            Game.tiles[x][y] = Tile.Floor;

            // Remove box
            var box = Game.boxes[x][y];
            if (box != null) {
                // Detach from group
                if (box.group_id != Game.GROUP_ID_NONE) {
                    Game.groups[box.group_id].remove(box.id);

                    // Single box groups are auto-removed also
                    if (Game.groups[box.group_id].length == 1) {
                        Game.groups.remove(box.group_id);
                    }
                }

                // NOTE: magnet group is calculated at the end of the frame, technically making it possible to access it right after exiting editor? So have to do this just incase
                Game.magnet_group.remove(box.id);
                
                // Remove from boxes
                Game.boxes.vset(box.pos, null);
                Game.boxes_by_id.remove(box.id);
            }

            // Remove goal
            var removed_goal = null;
            for (g in Game.goals) {
                if (v_eql(g, v(x, y))) {
                    removed_goal = g;
                    break;
                }
            }
            if (removed_goal != null) {
                Game.goals.remove(removed_goal);
            }
        }

        switch (current_tool) {
            case ToolType_PlaceWall: {
                if (no_player) {
                    delete(x, y);
                    Game.tiles[x][y] = Tile.Wall;
                }
            }
            case ToolType_PlaceWater: {
                if (no_player) {
                    Game.tiles[x][y] = Tile.Water;
                }
            }
            case ToolType_Delete: {
                delete(x, y);
            }
            case ToolType_PlaceBox: {                
                if (no_player) {
                    delete(x, y);

                    var box = {
                        id: get_box_id(),
                        pos: v(x, y),
                        is_magnet: true,
                        color: BoxColor_Gray,
                        group_id: Game.GROUP_ID_NONE,
                    };
                    Game.boxes_by_id[box.id] = box;
                    Game.boxes[x][y] = box;
                }
            }
            case ToolType_PlaceNormalBox: {                
                if (no_player) {
                    delete(x, y);

                    var box = {
                        id: get_box_id(),
                        pos: v(x, y),
                        is_magnet: false,
                        color: BoxColor_Orange,
                        group_id: Game.GROUP_ID_NONE,
                    };
                    Game.boxes_by_id[box.id] = box;
                    Game.boxes[x][y] = box;
                }
            }
            case ToolType_PlaceGoal: {
                delete(x, y);

                Game.goals.push(v(x, y));
            }
            case ToolType_PlacePlayer: {
                delete(x, y);

                Player.pos = v(x, y);
            }
        }
    }
}

}