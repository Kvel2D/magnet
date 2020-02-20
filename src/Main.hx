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

static var prev_state = State_Game;
static var state = State_Game;

static var level_list: Array<String>;
static var current_level: String;

function init(){
    Gfx.resizescreen(SCREEN_WIDTH, SCREEN_HEIGHT);
    Gfx.loadtiles('tiles', Game.TILESIZE, Game.TILESIZE);
    Text.size = 2;

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
    Game.load_level(current_level);
}

static function save_level_list() {
    var level_list_file = SharedObject.getLocal('level-list');
    level_list_file.data.level_list = level_list;
    level_list_file.flush();
}

static function change_state(new_state) {
    prev_state = state;
    state = new_state;
}

function update() {
    if (Input.justpressed(Key.TWO)) {
        switch (state) {
            case State_LevelSelect: {
                change_state(prev_state);
            }
            case State_Game: {
                Text.inputbuffer = '';
                change_state(State_LevelSelect);
            }
            case State_Editor: {
                Text.inputbuffer = '';
                change_state(State_LevelSelect);
            }
        }

        // Render thumbnails
        for (name in level_list) {
            Gfx.createimage(name, SCREEN_WIDTH, SCREEN_HEIGHT);
            Game.load_level(name);
            Gfx.drawtoimage(name);
            Game.render();
            Gfx.drawtoscreen();
        }

        Game.load_level(current_level);
    }

    if (Input.justpressed(Key.ONE)) {
        switch (state) {
            case State_Game: {
                Game.load_level(current_level);
                change_state(State_Editor);
            }
            case State_Editor: {
                Game.save_level(current_level);
                change_state(State_Game);
            }
            case State_LevelSelect:
        }
    }

    switch (state) {
        case State_Game: Game.update();
        case State_LevelSelect: LevelSelect.update();
        case State_Editor: Editor.update();
    }
}

}