package nvd.p;

import csss.CValid.*;

enum HXXVal {
	Variable(k: String, ?d: String);
	Text(s: String);
}

@:enum private abstract State(Int) to Int {
	var BEGIN = 0;
	var BRACE = 1;
	var OP_OR = 2;
}

class HXX {

	public static function parse(str: String, pos = 0, max = -1): Array<HXXVal> {

		inline function char(p) return StringTools.fastCodeAt(str, p);

		var ret = [];
		var S = BEGIN;
		var c: Int;
		var all_space = true;
		var t_var = "";
		var t_var_d = null;
		if (max == -1) max = str.length;
		var left = pos;
		var i = 0;         // index for ret
		var START = pos;   // for restore
		while (pos < max) {
			switch (S) {
			case BEGIN:
				c = char(pos);
				if (c == "{".code && char(pos + 1) == "{".code) {
					if (pos > left && !all_space) {
						ret.push(Text(str.substring(left, pos)));
					}
					pos += 2;
					S = BRACE;
					continue;
				} else if (all_space && !is_space(c)) {
					all_space = false;
				}
			case BRACE:
				left = ignore_space(str, pos, max);
				pos = ident(str, left, max, is_alpha_u, is_anu);
				if (pos > left) t_var = str.substring(left, pos);
				S = OP_OR;
				continue;
			case OP_OR:
				pos = ignore_space(str, pos, max);
				c = char(pos);
				if (c == "}".code && char(pos + 1) == "}".code) {
					if (t_var != "") {
						ret.push(Variable(t_var, t_var_d));
						t_var = "";
					}
					t_var_d = null;
					all_space = true;
					i = ret.length;  // update
					S = BEGIN;
					pos += 2;
					left = pos;
					START = left;
					continue;
				} else if (t_var_d == null && c == "|".code && char(pos + 1) == "|".code) {
					left = ignore_space(str, pos + 2, max);
					c = char(left);
					switch (c) {
					case '"'.code:
						pos = until(str, left + 1, max, @:privateAccess Attr.un_double_quote);
						if (pos < max) {
							t_var_d = str.substring(left + 1, pos);
						}
					case "'".code:
						pos = until(str, left + 1, max, @:privateAccess Attr.un_single_quote);
						if (pos < max) {
							t_var_d = str.substring(left + 1, pos);
						}
					default:
						pos = until(str, left, max, to_end);
						if (pos < max) {
							t_var_d = str.substring(left, pos);
						}
						continue;
					}
				} else {
					// discard & restore as text
					while (ret.length > i) ret.pop();
					left = START;
					t_var = "";
					t_var_d = null;
					all_space = false;
					S = BEGIN;
					continue;
				}
			}
			++ pos;
		}
		if (pos > left && !all_space)
			ret.push(Text((str.substring(left, pos))));
		return ret;
	}

	static function to_end(c) return !(c <= " ".code || c == "}".code);
}
