package nvd.p;

import nvd.p.CValid.*;
using StringTools;

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
		var c = s.fastCodeAt(left++);
		var r: Range = null;
		switch (c) {
		case "[".code:
			p_attr(s, left, max);
		case "#".code: // id
			r = Range.ident(s, left, max, is_alpha_u, is_anum);
			if (r != null) {
				attr.set("id", r.substr(s, false));
				rec(s, r.right, max);
			}
		case ".".code: // class
			r = Range.ident(s, left, max, is_alpha_u, is_anum);
			if (r != null) {
				if (this.cls == null) this.cls = [];
				this.cls.push(r.substr(s, false));
				rec(s, r.right, max);
			}
		default:
		}
	}

	function p_attr(s: String, left: Int, max: Int) {
		left = Range.ltrim(s, max, left);
		var rk = Range.ident(s, left, max, is_attr_first, is_anumx);
		if (rk == null) return;

		var rv: Range = null;
		var next = false;
		left = Range.ltrim(s, max, rk.right);
		while (left < max) {
			switch (s.fastCodeAt(left++)) {
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
		left = Range.ltrim(s, max, left);
		if (left < max) {
			var c = s.fastCodeAt(left++);
			switch (c) {
			case '"'.code:
				r = Range.until(s, left, max, function(c) { return c != '"'.code; } ); // Note: next is '"'
				if (r == null && s.fastCodeAt(left) == '"'.code) r = new Range(left, left);
			case "'".code:
				r = Range.until(s, left, max, function(c) { return c != "'".code; } );
				if (r == null && s.fastCodeAt(left) == "'".code) r = new Range(left, left);
			default:
				r = Range.ident(s, left - 1, max, is_alpha_u, is_anum);
			}
		}
		return r;
	}

	inline function is_attr_first(c) {
		return is_alpha_u(c) || c == ":".code;
	}
}