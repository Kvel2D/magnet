import haxegon.*;
import openfl.net.SharedObject;

enum State {
    State_Game;
    State_LevelSelect;
    State_Editor;
}

class Main {
// force unindent

public static inline var SCREEN_WIDTH = 1500;
public static inline var SCREEN_HEIGHT = 900;

public static var state = State_Game;

function init(){
    Gfx.resizescreen(SCREEN_WIDTH, SCREEN_HEIGHT);
    Gfx.loadtiles('tiles', Game.TILESIZE, Game.TILESIZE);
    Text.size = 2;

    LevelSelect.init();
    Game.load_level(LevelSelect.current_level);
}

function update() {
    // Switch to LevelSelect
    if (Input.justpressed(Key.TWO)) {
        if (state == State_Editor) {
            Game.save_level();
        }

        Game.load_level(LevelSelect.current_level);
        Text.inputbuffer = '';
        state = State_LevelSelect;
    }

    // Switch between Game and Editor
    if (Input.justpressed(Key.ONE)) {
        switch (state) {
            case State_Game: {
                Game.load_level(LevelSelect.current_level);
                state = State_Editor;
            }
            case State_Editor: {
                Game.save_level();
                state = State_Game;
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