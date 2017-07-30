package;

#if macro
import haxe.macro.Expr;
import haxe.macro.Context;
import nvd.p.Range;
import nvd.p.AttrParse;
import nvd.p.CharValid.*;
#end

class Nvd {
	macro public static function h(exprs: Array<Expr>) {
		var vattr = {};
		var name = parse_name(exprs[0], vattr);
		var attr = Reflect.fields(vattr).length == 0 ? macro null : macro $v { vattr };
		var ret = [name, attr];
		for (i in 1...exprs.length) ret.push(exprs[i]);
		return macro new nvd.VNode($a{ret});
	}



#if macro
	static function parse_name(e: Expr, attr): Expr {
		return switch (e.expr) {
		case EConst(CString(s)):
			var name: String;
			var r = Range.until(s, 0, is_validchar);
			if (r.left == 0 && r.right == s.length) {
				name = s.toUpperCase();
			} else {
				name = r.substr(s).toUpperCase();
				var ap = new AttrParse(s, r.right, s.length);
				for (k in ap.attr.keys()) {
					Reflect.setField(attr, k, ap.attr.get(k));
				}
			}
			macro $v{name};
		case EConst(CIdent(i)):
			Context.warning('Only for tagName. Do not accept "[attr...]#id.class". Use "String Literal"', e.pos);
			macro $e.toUpperCase();
		default:
			Context.error("Unsupported type", e.pos);
		}
	}
#end
}