import haxegon.*;

enum State {
    State_Game;
    State_Editor;
}

class Main {
// force unindent
static inline var SCREEN_WIDTH = 900;
static inline var SCREEN_HEIGHT = 900;

var state = State_Game;
var game = new Game();
var editor = new Editor();

function init(){
    Gfx.resizescreen(SCREEN_WIDTH, SCREEN_HEIGHT);
    Gfx.loadtiles('tiles', Game.TILESIZE, Game.TILESIZE);

    game.init();
}

function update() {
    if (Input.justpressed(Key.E)) {
        state = switch (state) {
            case State_Game: State_Editor;
            case State_Editor: State_Game;
        }
    }

    switch (state) {
        case State_Game: game.update();
        case State_Editor: editor.update();
    }
}

}