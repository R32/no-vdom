package nvd.inner;

 using StringTools;
import haxe.macro.Expr;
import haxe.macro.Context;
import haxe.macro.PositionTools;

private enum State {
	TEXT;
	EXPR;
}

class HXX {

	var skip : Bool;

	public function new( isHXX : Bool) {
		skip = !isHXX;
	}

	public function parse( s : String, pos : Position ) {
		var ret = {expr: EConst(CString(s)), pos: pos};
		if (skip)
			return ret;
		var col = [];
		var pinfo = PositionTools.getInfos(pos);
		inline function phere(i, len) return PositionTools.make({file: pinfo.file, min: pinfo.min + i, max: pinfo.min + i + len});
		inline function PUSH(s) col.push(s);
		var i = 0;
		var len = s.length - 1; // since }}  %} needs 2 char.
		var start = 0;
		var STATE = TEXT;
		var width = 0;
		while (i < len) {
			var c = s.fastCodeAt(i++);
			switch (STATE) {
			case TEXT if (c == "{".code):
				c = s.fastCodeAt(i++);
				if (c != "{".code)
					continue;
				width = i - 2 - start;
				if (width > 0 && !empty(s, start, width)) {
					var sub = s.substr(start, width);
					PUSH({expr: EConst(CString(sub)), pos: phere(start, width)});
				}
				start = i;
				STATE = EXPR;
			case EXPR if (c == "}".code):  // {{ expr }}
				c = s.fastCodeAt(i++);
				if (c != "}".code)
					continue;
				width = i - 2 - start;
				if (width > 0 && !empty(s, start, width)) {
					var sub = s.substr(start, width);
					PUSH(Context.parse(sub, phere(start, width)));
				}
				start = i;
				STATE = TEXT;
			default:
			}
		}
		if (STATE != TEXT)
			Nvd.fatalError("Expected }", pos);
		width = len + 1 - start;
		if (width > 0 && !empty(s, start, width))
			PUSH( {expr: EConst(CString( s.substr(start, width) )), pos: phere(start, width)} );
		return switch(col.length) {
		case 0:
			null;
		case 1:
			col[0];
		default:
			concat(col);
		}
	}

	function concat( col : Array<Expr> ) {
		var group = [];
		var prev  = null;
		function APPEND(e) {
			if (prev != null) {
				group.push(prev);
				prev = null;
			}
			group.push(e);
		}
		for (e in col) {
			switch (e.expr) {
			case EConst(CIdent(s)) if (s.charCodeAt(0) == "$".code):
				APPEND(macro @:pos(e.pos) $i{s.substr(1, s.length - 1)});
				continue;
			case EMeta({name: "$"}, e): // TODO: I forgot what this is?
				APPEND(e);
				continue;
			default:
				var add = false;
				try {
					var t = Context.follow(Context.typeof(e));
					add = RElement.match( haxe.macro.TypeTools.toString(t) );
				} catch (_) {
					add = true;
				}
				if (add) {
					APPEND(e);
					continue;
				}
			}
			if (prev != null) {
				prev = {expr: EBinop(OpAdd, prev, e), pos : e.pos};
			} else {
				prev = e;
			}
		}
		if (prev != null)
			group.push(prev);
		return switch(group.length) {
		case 0:
			null;
		case 1:
			group[0];
		default:
			var pos = Utils.punion(group[0].pos, group[group.length-1].pos);
			macro @:pos(pos) $a{group};
		}
	}

	function empty( s : String, i : Int, len : Int ) : Bool {
		len += i;
		if (len > s.length)
			len = s.length;
		while (i < len) {
			var c = s.fastCodeAt(i++);
			if ( !(c == " ".code || (c > 8 && c < 14)) )
				return false;
		}
		return true;
	}

	static var RElement = ~/^(js.html.|Array|Dynamic)/;
}
