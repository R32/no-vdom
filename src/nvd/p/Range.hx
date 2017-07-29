package nvd.p;

import nvd.p.CharValid.*;

class Range {

	public var left: Int;
	public var right: Int;

	public function new(l, r){
		left = l;
		right = r;
	}

	public function union(r2: Range) {
		left = Utils.imin(left, r2.left);
		right = Utils.imax(right, r2.right);
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
			if (is_space(text.charCodeAt(begin))) {
				++ begin;
			} else {
				break;
			}
		}
		return begin;
	}

	public static function rtrim(text: String, last: Int, left: Int): Int {
		while (last >= left) {
			if (is_space(text.charCodeAt(last))) {
				-- last;
			} else {
				break;
			}
		}
		return last + 1;
	}

	public static function index(text: String, sl: String, sr: String, begin = 0, outer = true, rr = -1):Range {
		var left = text.indexOf(sl, begin);
		if (left > -1) {
			var right = rr != -1 ? text.lastIndexOf(sr, rr) : text.indexOf(sr, left + sl.length);
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
	// 下列方法未测试
	public static function indexOf(text: String, sub: String, begin = 0, outer = true, rr = -1):Range {
		var right = rr != -1 ? text.lastIndexOf(sub, rr) : text.indexOf(sub, begin);
		if (right > begin) {
			if (outer) right += sub.length;
			return new Range(begin, right);
		}
		return null;
	}

	public static function until(text: String, begin = 0, callb: Int->Bool): Range {
		var max = text.length;
		var i = begin;
		while (i < max) {
			if (!callb(text.charCodeAt(i))) break;
			++ i;
		}
		if (i > begin) return new Range(begin, i);
		return null;
	}
}