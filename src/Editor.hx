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
    if (Mouse.rightclick()) {
        var x = mouse_x();
        var y = mouse_y();
        if (Game.boxes[x][y] == null) {
            Game.add_box(x, y);
        }
    }

    Game.render();

    Text.display(0, 0, 'EDITOR\n${mouse_x()} ${mouse_y()}', Col.WHITE);

    var box_size = Game.TILESIZE * Game.SCALE;
    Gfx.drawbox(mouse_x() * box_size, mouse_y() * box_size, box_size, box_size, Col.PINK);
}

}