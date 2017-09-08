package nvd.p;

import csss.CValid.*;

enum HVal {
	Var(k: String);
	Str(s: String, isSpaces: Bool);
}

@:enum private abstract State(Int) to Int {
	var BEGIN = 0;
	var BRACE = 1;
}

class HXX {

	public static function parse(str: String, pos: Int, max: Int): Array<HVal> {

		inline function IGNORE_SPACES() pos = ignore_space(str, pos, max);
		inline function char(p) return StringTools.fastCodeAt(str, p);
		inline function charAt(p) return str.charAt(p);

		var left = pos;
		inline function substr() return str.substr(left, pos - left);
		var S = BEGIN;
		var all_spaces = true;
		inline function RESET() { S = BEGIN; all_spaces = true; left = pos + 1; }

		var ret = [];
		var c: Int;
		while (pos < max) {
			switch (S) {
			case BEGIN:
				c = char(pos);
				switch (c) {
				case "{".code:
					if (pos > left) ret.push(Str(substr(), all_spaces));
					S = BRACE;
				default:
					if (all_spaces && !is_space(c)) all_spaces = false;
				}
			case BRACE:
				IGNORE_SPACES();
				left = pos;
				pos = ident(str, pos, max, is_alpha_u, is_anu);
				if (pos == left) throw pos;   // InvalidChar
				ret.push(Var(substr()));
				IGNORE_SPACES();
				c = char(pos);
				if (c != "}".code) throw pos; // Expected "}"
				RESET();
			}
			++ pos;
		}
		if (pos > left) ret.push(Str(substr(), all_spaces));

		// trims
		var len = ret.length;
		if (len > 1) {
			var p = 0;
			while (p < len) {
				switch (ret[p]) {
				case Str(_, true):
					++ p;
					continue;
				default:
				}
				break;
			}
			while (len > p) {
				switch (ret[len-1]) {
				case Str(_, true):
					-- len;
					continue;
				default:
				}
				break;
			}
			ret = ret.slice(p, len);
		}
		return ret;
	}
}
