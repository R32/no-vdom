package nvd;

class Utils {

	public static inline function f2i(f: Float) return Std.int(f + 0.0000001);

	public static inline function iabs( i : Int ) return i < 0 ? -i : i;

	public static inline function imax( a : Int, b : Int ) return a < b ? b : a;

	public static inline function imin( a : Int, b : Int ) return a > b ? b : a;

	public static inline function iclamp( v : Int, min : Int, max : Int ) return v < min ? min : (v > max ? max : v);

}