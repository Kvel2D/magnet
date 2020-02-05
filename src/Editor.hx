import haxegon.*;
import flash.net.SharedObject;
import haxe.Serializer;

@:publicFields
class Editor {
// force unindent

function new() {

}

static inline function mouse_x(): Int {
    return Math.floor(Mouse.x / Game.TILESIZE / Game.SCALE);
}
static inline function mouse_y(): Int {
    return Math.floor(Mouse.y / Game.TILESIZE / Game.SCALE);
}

static function update() {
    Game.render();

    Text.display(0, 0, 'EDITOR\n${mouse_x()} ${mouse_y()}', Col.WHITE);


}

}