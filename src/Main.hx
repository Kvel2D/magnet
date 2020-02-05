import haxegon.*;
import openfl.net.SharedObject;

enum State {
    State_Game;
    State_LevelSelect;
    State_Editor;
}

@:publicFields
class Main {
// force unindent

static inline var SCREEN_WIDTH = 900;
static inline var SCREEN_HEIGHT = 900;

static var state = State_Game;

static var level_list: Array<String>;

function init(){
    Gfx.resizescreen(SCREEN_WIDTH, SCREEN_HEIGHT);
    Gfx.loadtiles('tiles', Game.TILESIZE, Game.TILESIZE);
    Text.size = 2;

    // Load level list
    var level_list_file = SharedObject.getLocal('level-list');
    if (level_list_file.data.level_list == null) {
        // Setup default level if it doesn't exist yet
        level_list_file.data.level_list = ['default'];
        Game.new_level('default');
        level_list_file.flush();
    }
    level_list = level_list_file.data.level_list;

    Game.load_level('default');
}

static function save_level_list() {
    var level_list_file = SharedObject.getLocal('level-list');
    level_list_file.data.level_list = level_list;
    level_list_file.flush();
}

function update() {
    if (Input.justpressed(Key.L)) {
        // Reset game if currently ingame
        if (state == State_Game) {
            Game.load_level(Game.level_name);
        }

        // Edit.save_changes();

        if (state == State_LevelSelect) {
            state = State_Game;
        } else {
            state = State_LevelSelect;
        }

        // Render thumbnails
        for (name in level_list) {
            Gfx.createimage(name, SCREEN_WIDTH, SCREEN_HEIGHT);
            Game.load_level(name);
            Gfx.drawtoimage(name);
            Game.render();
            Gfx.drawtoscreen();
        }

        Game.load_level(Game.level_name);
    }

    if (Input.justpressed(Key.E)) {
        state = switch (state) {
            case State_Game: State_Editor;
            case State_Editor: State_Game;
            case State_LevelSelect: state;
        }
    }

    switch (state) {
        case State_Game: Game.update();
        case State_LevelSelect: LevelSelect.update();
        case State_Editor: Editor.update();
    }
}

}