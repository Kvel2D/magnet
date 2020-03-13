
@:publicFields
class Tile {
// force unindent

static inline var TILESET_SIZE = 10;
static inline function at(x: Int, y: Int): Int {
    return y * TILESET_SIZE + x;
}

static inline var None = at(0, 0);
static inline var Player = at(1, 0);
static inline var PlayerMagnet = at(2, 4);
static inline var PlayerLeft = at(3, 4);
static inline var PlayerUp = at(4, 4);
static inline var PlayerRight = at(5, 4);
static inline var PlayerDown = at(6, 4);
static inline var Floor = at(0, 4);
static inline var Wall = at(1, 4);
static inline var Box = at(0, 3);
static inline var BoxMagnet = at(2, 3);
static inline var BoxOrange = at(0, 5);
static inline var Goal = at(0, 1);
static inline var Water = at(2, 5);
static inline var Cross = at(3, 5);
static inline var Lava = at(4, 5);

}