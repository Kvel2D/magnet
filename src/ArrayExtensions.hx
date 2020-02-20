import Vec2iTools.Vec2i;

@:publicFields
class ArrayExtensions {
    static function vget<T>(arr: Array<Array<T>>, v: Vec2i): T {
        return arr[v.x][v.y];
    }
    static function vset<T>(arr: Array<Array<T>>, v: Vec2i, val: T) {
        arr[v.x][v.y] = val;
    }
}
