package nvd.p;

import csss.CValid.*;

class PAttr {

	public static function run(s: String, pos: Int, max: Int, attr: haxe.DynamicAccess<String>): Void {
		var classes = [];
		inline function char(p) return StringTools.fastCodeAt(s, p);
		inline function charAt(p) return s.charAt(p);

		var c = char(pos++);
		var left = pos; inline function substr() return s.substr(left, pos - left);
		while (pos < max) {
			switch (c) {
			case "[".code:
				pos = on_attr(s, pos, max, attr);
				if (pos == -1) throw "Invalid Attribute";
			case "#".code:
				pos = ident(s, left, max, is_alpha_u, is_anum);
				if (pos == left) throw "Invalid Char " + charAt(pos);
				attr.set("id", substr());
			case ".".code:
				pos = ident(s, left, max, is_alpha_u, is_anum);
				if (pos == left) throw "Invalid Char " + charAt(pos);
				classes.push(substr());
			default:
				max = 0;  // break loop;
				continue;
			}
			c = char(pos++);
			left = pos;
		}
		if (classes.length > 0)
			attr.set("class", classes.join(" "));
	}

	static function on_attr(s: String, pos: Int, max: Int, attr: haxe.DynamicAccess<String>): Int {
		inline function IGNORE_SPACES() pos = ignore_space(s, pos, max);
		inline function char(p) return StringTools.fastCodeAt(s, p);

		IGNORE_SPACES();
		var left = pos; inline function substr() return s.substr(left, pos - left);
		pos = ident(s, pos, max, is_attr_first, is_anumx);
		if (pos == left) return -1;

		var key = substr();
		IGNORE_SPACES();

		var c = char(pos++);
		switch (c) {
		case "]".code:
			attr.set(key, key);
		case "=".code:
			IGNORE_SPACES();
			c = char(pos++);
			left = pos;    // skip quote
			switch (c) {
			case '"'.code:
				pos = until(s, pos, max, un_double_quote);
			case "'".code:
				pos = until(s, pos, max, un_single_quote);
			default:
				if (is_alpha_um(c)) {
					-- left;
					pos = until(s, pos, max, is_anum);
				} else {
					return -1;
				}
			}
			attr.set(key, substr()); // if pos == left, then set empty string.
			c = char(pos);
			if (c == '"'.code || c == "'".code) ++pos;
			IGNORE_SPACES();
			c = char(pos++);
			if (c != "]".code) return -1;
		default:
			return -1;
		}
		return pos;
	}

	public static inline function is_attr_first(c: Int) return is_alpha_u(c) || c == ":".code;
	public static inline function un_double_quote(c) { return c != '"'.code; }
	public static inline function un_single_quote(c) { return c != "'".code; }
}