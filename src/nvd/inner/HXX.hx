package nvd.inner;

import haxe.macro.Expr;
import haxe.macro.Context;

private enum HXXState {
	BEGIN;
	BRACE_START;
}

class HXX {

	var ignore : Bool;

	public function new(hxx) {
		ignore = !hxx;
	}

	public function parse( s : String, pos : Position, evenInit : Bool ) : Expr {
		var ret = {expr: EConst(CString(s)), pos: pos};
		if (ignore)
			return ret;
		var wchar = evenInit ? 2 : 1;
		var even = evenInit; // if evenInit == true then uses "{{" as delimiter, otherwise "{"
		var col = [];
		var i = 0;
		var len = s.length;
		var start = 0;
		var state = BEGIN;
		while (i < len) {
			var c = StringTools.fastCodeAt(s, i++);
			switch(state) {
			case BEGIN if (c == "{".code): // BEGIN
				if (even) {
					even = false;
					continue;
				}
				if (i > start + wchar) {
					var sub = s.substr(start, i - wchar - start);
					col.push({expr: EConst(CString(sub)), pos: pos});
				}
				start = i;
				state = BRACE_START;
				even = evenInit; // reset for next
			case BRACE_START if (c == "}".code):
				if (even) {
					even = false;
					continue;
				}
				if (i > start + wchar) {
					var sub = StringTools.trim( s.substr(start, i - wchar - start) );
					if (sub != "")
						col.push( Context.parse(sub, pos) );
				}
				start = i;
				state = BEGIN;
				even = evenInit; // reset for next
			default:
			}
		}
		if (state == BRACE_START)
			Nvd.fatalError("Expected }", pos);
		if (i > start) {
			var sub = s.substr(start, i - start);
			col.push({expr: EConst(CString(sub)), pos: pos});
		}
		if (col.length == 1) {
			ret = col[0];
		} else if (col.length > 1) {
			var prev = col.shift();
			ret = Lambda.fold(col, (item,prev)->{expr : EBinop(OpAdd, prev, item), pos : item.pos}, prev);
		}
		return ret;
	}
}