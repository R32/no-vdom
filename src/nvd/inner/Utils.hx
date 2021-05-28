package nvd.inner;

 using haxe.macro.PositionTools;
import csss.xml.Xml;
import csss.xml.Parser;
import haxe.macro.Expr;

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
			var pos = pos.getInfos();
			pos.min += e.position;
			pos.max = pos.min + 1;
			Nvd.fatalError(e.toString(), pos.make());
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

	static public function punion( p1 : Position, p2 : Position ) {
		var pos = p1.getInfos();
		pos.max = p2.getInfos().max; // ???do max(p1.max, p2.max),
		return pos.make();
	}
}