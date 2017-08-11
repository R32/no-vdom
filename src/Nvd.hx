package;

#if macro
import haxe.macro.Expr;
import haxe.macro.Context;
import csss.CValid.*;
#end

class Nvd {
	macro public static function h(exprs: Array<Expr>) {
		var vattr = {};
		var name = parse(exprs[0], vattr);
		var attr = Reflect.fields(vattr).length == 0 ? macro null : macro $v { vattr };
		var ret = [name, attr];
		for (i in 1...exprs.length) ret.push(exprs[i]);
		return macro new nvd.VNode($a{ret});
	}


#if macro
	static function parse(e: Expr, attr): Expr {
		return switch (e.expr) {
		case EConst(CString(s)):
			var name: String;
			var p = ident(s, 0, s.length, is_alpha_u, is_anumx);
			if (p == 0) Context.error('Invalid TagName: "$s"', e.pos);
			if (p == s.length) {
				name = s.toUpperCase();
			} else {
				name = s.substr(0, p).toUpperCase();
				nvd.p.PAttr.run(s, p, s.length, attr, []);
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