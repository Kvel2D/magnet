import haxegon.*;
import Game;

@:publicFields
class Editor {
// force unindent

function new() {

}

function render() {
    Gfx.clearscreen();
    Text.display(0, 0, 'EDITOR', Col.WHITE);
}

function update() {
    render();
}

}