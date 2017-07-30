package nvd.p;

import nvd.p.CharValid.*;

class AttrParse {
	var cls: Array<String>;

	public var attr(default, null): haxe.DynamicAccess<String>;

	public inline function empty() {
		return attr == null || attr.keys().length == 0;
	}

	public function new(s: String, i: Int, max: Int) {
		if (i < max) {
			attr = {};
			rec(s, i, max);
			if (cls != null) attr.set("class", cls.join(" "));
			//log();
		}
	}

	@:dce inline function log(){
		var a = [];
		for (k in attr.keys()) {
			a.push('$k: "${attr.get(k)}", ');
		}
		trace(a.join(""));
	}

	function rec(s: String, left: Int, max: Int): Void {
		if ((left + 1) >= max) return;
		var c = s.charCodeAt(left++);
		var r: Range = null;
		switch (c) {
		case "[".code:
			p_attr(s, left, max);
		case "#".code: // id
			r = r_ident(s, left, max, true);
			if (r != null) {
				attr.set("id", r.substr(s));
				rec(s, r.right, max);
			}
		case ".".code: // class
			r = r_ident(s, left, max, true);
			if (r != null) {
				if (this.cls == null) this.cls = [];
				this.cls.push(r.substr(s));
				rec(s, r.right, max);
			}
		default:
		}
	}

	// do not include "ltrim"
	function r_ident(s: String, left: Int, max: Int, first: Bool): Range {
		var r: Range = null;
		if (left < max) {
			var i = left;
			var c: Int;
			if (first) {
				c = s.charCodeAt(i++);
				if (is_alpha(c) || c == "_".code) {
				} else {
					return r;
				}
			}

			while (i < max) {
				c = s.charCodeAt(i);
				if (is_alpha(c) || is_number(c) || c == "-".code || c == "_".code)
					++i;
				else
					break;
			}
			if (i > left) r = new Range(left, i);
		}
		return r;
	}

	function p_attr(s: String, left: Int, max: Int) {
		left = Range.ltrim(s, max, left);
		var rk = r_ident(s, left, max, true);
		if (rk == null) return;

		var rv: Range = null;
		var next = false;
		left = Range.ltrim(s, max, rk.right);
		while (left < max) {
			switch (s.charCodeAt(left++)) {
			case "=".code: // string
				rv = r_string(s, left, max);
				if (rv == null) return; // TODO: error???.
				left = rv.right;        // continue unitl got "]" or "," for skip single/double quote
			case "]".code:
				next = false;
				break;
			case ",".code:
				next = true;
				break;
			default:
			}
		}
		var key = rk.substr(s, false);
		var val = rv == null ? key : rv.substr(s, false);
		attr.set(key, val);

		if (next)
			p_attr(s, left, max);
		else
			rec(s, left, max);
	}

	function r_string(s: String, left: Int, max: Int): Range {
		var r: Range = null;
		if (left < max) {
			left = Range.ltrim(s, max, left);
			var c = s.charCodeAt(left++);
			switch (c) {
			case '"'.code:
				r = Range.until(s, left, function(c) { return c != '"'.code; } );
			case "'".code:
				r = Range.until(s, left, function(c) { return c != "'".code; } );
			default:
				r = r_ident(s, left - 1, max, false);
			}
		}
		return r;
	}
}