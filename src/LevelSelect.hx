import haxegon.*;
import openfl.net.SharedObject;

using MathExtensions;

class LevelSelect {
// force unindent

static inline var THUMB_SCALE = 0.15;
static inline var THUMB_WIDTH = Game.WORLD_WIDTH * Game.SCALE * Game.TILESIZE * THUMB_SCALE;
static inline var THUMB_HEIGHT = Game.WORLD_HEIGHT * Game.SCALE * Game.TILESIZE * THUMB_SCALE;
static inline var X_OFFSET = 50;

static var level_list: Array<String>;
public static var current_level: String;
public static var update_thumbnails = true;

public static function init() {
    // Load level list
    var level_list_file = SharedObject.getLocal('level-list');
    if (level_list_file.data.level_list == null) {
        // Setup default level if it doesn't exist yet
        level_list_file.data.level_list = ['default'];
        Game.init_new_level('default');
        level_list_file.flush();
    }
    level_list = level_list_file.data.level_list;

    current_level = 'default';
}

public static function update() {
    if (update_thumbnails) {
        for (name in level_list) {
            Gfx.createimage(name, Main.SCREEN_WIDTH, Main.SCREEN_HEIGHT);
            Game.load_level(name);
            Gfx.drawtoimage(name);
            Game.render();
            Gfx.drawtoscreen();
        }
    }
    
    var x = X_OFFSET;
    var y = 50;

    var hovering_level: String = null;

    for (name in level_list) {
        if (Math.point_box_intersect(Mouse.x, Mouse.y, x, y, THUMB_WIDTH, THUMB_HEIGHT + Text.height(name))) {
            hovering_level = name;
        }

        Gfx.scale(THUMB_SCALE);
        Gfx.drawimage(x, y + Text.height(name), name);

        Gfx.scale(1);
        Text.display(x, y, name);

        x += Math.round(Math.max(THUMB_WIDTH, Text.width(name)));

        if (x + THUMB_WIDTH > Main.SCREEN_WIDTH) {
            x = X_OFFSET;
            y += Math.round(THUMB_HEIGHT + Text.height());
        }
    }

    var new_level_text = 'New level:';
    Text.display(x, y, new_level_text);
    if (Text.input(x + Text.width(new_level_text), y)) {
        var new_level_name = Text.inputresult;

        if (level_list.indexOf(new_level_name) == -1) {
            level_list.push(new_level_name);

            // Save level list
            var level_list_file = SharedObject.getLocal('level-list');
            level_list_file.data.level_list = level_list;
            level_list_file.flush();

            Game.init_new_level(new_level_name);
            Game.load_level(new_level_name);
            Main.state = State_Game;
        } else {
            trace('Level with name $new_level_name already exists!');
        }
    }

    if (hovering_level != null && Mouse.leftclick()) {
        current_level = hovering_level;
        Game.load_level(hovering_level);
        Main.state = State_Game;
    }
}

}
