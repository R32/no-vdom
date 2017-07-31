package nvd.p;

import nvd.p.CValid.*;
using StringTools;

class Range {

	public var left: Int;
	public var right: Int;

	public function new(l, r){
		left = l;
		right = r;
	}

	public inline function toString() {
		return '[L: $left, R: $right]';
	}

	public function substr(str: String, trim = true) {
		var l = left;
		var r = right;
		if (trim) {
			l = ltrim(str, r, l);
			r = rtrim(str, r - 1, l);
		}
		return str.substr(l, r - l);
	}

	public static function ltrim(text: String, max: Int, begin = 0): Int {
		while (begin < max) {
			if (is_space(text.fastCodeAt(begin))) {
				++ begin;
			} else {
				break;
			}
		}
		return begin;
	}

	public static function rtrim(text: String, last: Int, left = 0): Int {
		while (last >= left) {
			if (is_space(text.fastCodeAt(last))) {
				-- last;
			} else {
				break;
			}
		}
		return last + 1;
	}

	public static function index(text: String, sl: String, sr: String, begin = 0, outer = true):Range {
		var left = text.indexOf(sl, begin);
		if (left > -1) {
			var right = text.indexOf(sr, left + sl.length);
			if (right > left) {
				if (outer) {
					right += sr.length;
				} else {
					left += sl.length;
				}
				return new Range(left, right);
			}
		}
		return null;
	}

	public static function indexOf(text: String, sub: String, begin = 0, outer = true):Range {
		var right = text.indexOf(sub, begin);
		if (right > begin) {
			if (outer) right += sub.length;
			return new Range(begin, right);
		}
		return null;
	}

	public static function until(text: String, begin: Int, max: Int, callb: Int->Bool): Range {
		var i = begin;
		while (i < max) {
			if (!callb(text.fastCodeAt(i))) break;
			++ i;
		}
		if (i > begin) return new Range(begin, i);
		return null;
	}

	public static function ident(text: String, begin: Int, max: Int, firstChar: Int->Bool, restChar: Int -> Bool): Range {
		var r: Range = null;
		if (begin < max) {
			var i = begin;
			var c = text.fastCodeAt(i++);
			if (!firstChar(c)) return r;
			while (i < max) {
				c = text.fastCodeAt(i);
				if (restChar(c))
					++i;
				else
					break;
			}
			if (i > begin) r = new Range(begin, i);
		}
		return r;
	}
}