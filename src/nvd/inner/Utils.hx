package nvd.inner;

import csss.xml.Xml;
import csss.xml.Parser;
import haxe.macro.Expr;
import haxe.macro.PositionTools.make in pmake;
import haxe.macro.PositionTools.getInfos in pInfos;

class Utils {
	public static function string( e : Expr ) : String {
		return switch (e.expr) {
		case EConst(CString(s)):
			s;
		case EBinop(OpAdd, e1, e2):
			string(e1) + string(e2);
		default:
			Nvd.fatalError("Expected String", e.pos);
		}
	}
	public static function bool( e : Expr ) : Bool {
		return switch (e.expr) {
		case EConst(CIdent("true")): true;
		default: false;
		}
	}
	public static function markup( e : Expr ) : String {
		return switch (e.expr) {
		case EConst(CString(s)):
			s;
		case EMeta({name: ":markup"}, {expr: EConst(CString(s))}):
			s;
		default:
			Nvd.fatalError("Expected String", e.pos);
		}
	}

	public static function parseXML( txt : String, pos : Position ) : Xml {
		return try {
			Xml.parse(txt);
		} catch (e : XmlParserException) {
			var pos = pInfos(pos);
			pos.min += e.position;
			pos.max = pos.min + 1;
			Nvd.fatalError(e.toString(), pmake(pos));
		} catch (unk : Dynamic) {
			Nvd.fatalError(Std.string(unk), pos);
		}
	}

	static public function isSVG( node : Xml ) : Bool {
		var ret = false;
		while(node != null) {
			if (node.nodeName == "svg") {
				ret = true;
				break;
			}
			node = node.parent;
		}
		return ret;
	}
}