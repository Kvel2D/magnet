
typedef Vec2i = {
    x: Int,
    y: Int,
};

@:publicFields
class Vec2iTools {
    static function v_make(x: Int, y: Int) {
        return {x: x, y: y};
    }

    static function v_copy(v: Vec2i): Vec2i {
        return v_make(v.x, v.y);
    }

    static function v_mult(a: Vec2i, s: Int): Vec2i {
        return v_make(a.x * s, a.y * s);
    }

    static function v_add(a: Vec2i, b: Vec2i): Vec2i {
        return v_make(a.x + b.x, a.y + b.y);
    }

    static function v_range(start: Vec2i, end: Vec2i) {
        var range = new Array<Vec2i>();
        for (x in start.x...end.x) {
            for (y in start.y...end.y) {
                range.push(v_make(x, y));
            }
        }
        return range;
    }

    static function v_eql(a: Vec2i, b: Vec2i): Bool {
        return a.x == b.x && a.y == b.y;
    }

}