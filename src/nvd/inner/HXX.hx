package nvd.inner;

 using StringTools;
import haxe.macro.Expr;
import haxe.macro.Type;
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
				if (width > 0) {
					var sub = s.substr(start, width);
					PUSH({expr: EConst(CString(sub)), pos: phere(start, width)});
				}
				start = i;
				STATE = EXPR;
			case EXPR if (c == "}".code):  // {{ expr }}
				c = s.fastCodeAt(i++);
				if (c != "}".code)
					continue;
				start = leftTrim(s, start, i - 2 - start);  // i - 2 - old-start
				width = rightTrim(s, start, i - 2 - start); // i - 2 - new-start
				if (width > 0) {
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
		if (width > 0)
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
			default:
				var mode = WhatMode.detects(e);
				if (mode != TCString) {
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

	function leftTrim( s : String, start : Int, len : Int ) : Int {
		var max = start + len;
		while(start < max) {
			var c = s.fastCodeAt(start);
			if ( !(c == " ".code || (c > 8 && c < 14)) )
				break;
			start++;
		}
		return start;
	}

	function rightTrim( s : String, start : Int, len : Int ) : Int {
		var i = start + len - 1;
		while(i >= start) {
			var c = s.fastCodeAt(i);
			if ( !(c == " ".code || (c > 8 && c < 14)) )
				break;
			i--;
		}
		return i + 1 - start;
	}
}

class WhatMode {

	static var types : { node : Type, string : Type, simples : EReg };

	static function isBlock( e : Expr ) {
		return switch(e.expr) {
		case EParenthesis(e), ECast(e, _), ECheckType(e, _), EMeta(_, e):
			isBlock(e);
		case EBlock(_), EIf(_), EFor(_), EWhile(_), ESwitch(_), ETry(_), ETernary(_):
			true;
		case ECall(macro nvd.Dt.h, _):
			true;
		default:
			false;
		}
	}

	static function isDynamic( t : Type, e : Expr ) {
		return switch(t) {
		case TDynamic(_):
			true;
		case TMono(_):
			Nvd.fatalError("Unknown: " + haxe.macro.ExprTools.toString(e), e.pos);
		default:
			false;
		}
	}

	public static function detects( e : Expr ) : ContentMode {
		if (types == null) {
			types = {
				node : Context.getType("js.html.Node"),
				string : Context.getType("String"),
				simples : ~/^(Int|Float|Boolean)$/,
			}
		}
		if (e == null)
			return TCNull;
		if (isBlock(e))
			return TCComplex;
		// fast detects
		switch(e.expr) {
		case EConst(CIdent("null")):
			return TCString;
		case EConst(CIdent(_)):
		case EConst(_), EBinop(OpAdd, _, _):
			return TCString;
		default:
		}
		// do unify
		var mode = TCComplex;
		try {
			var t = Context.follow(Context.typeof(e));
			if (isDynamic(t, e)) {
			} else if (Context.unify(t, types.node)) {
				mode = TCNode;
			} else if (Context.unify(t, types.string)) {
				mode = TCString;
			} else if (types.simples.match( haxe.macro.TypeTools.toString(t) )) {
				mode = TCString;
			} else {

			}
		} catch (_) {
		}
		return mode;
	}
}

enum ContentMode {
	TCString;
	TCNode;
	TCComplex;
	TCNull;
}