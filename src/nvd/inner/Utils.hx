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

	public static function doParse( markup : Expr ) : Xml {
		return try {
			var txt = switch(markup.expr) {
			case EConst(CString(s)): s;
			case EMeta({name: ":markup"}, macro $v{ (s : String) }): s;
			default:
				throw "Expected String";
			}
			Xml.parse(txt);
		} catch (e : XmlParserException) {
			var pos = markup.pos.getInfos();
			pos.min += e.position;
			pos.max = pos.min + 1;
			Nvd.fatalError(e.toString(), pos.make());
		} catch (e) {
			Nvd.fatalError(Std.string(e), markup.pos);
		}
	}

	static public function isSVG( node : Xml ) : Bool {
		while(node != null) {
			if (node.nodeName == "svg")
				return true;
			node = node.parent;
		}
		return false;
	}

	static public function punion( p1 : Position, p2 : Position ) {
		var pos = p1.getInfos();
		pos.max = p2.getInfos().max; // ???do max(p1.max, p2.max),
		return pos.make();
	}

	// if a.b.c then get c.position
	static public function pfield( full : Position, left : Position ) {
		var pos = full.getInfos();
		pos.min = left.getInfos().max + 1; // ".".length == 1;
		return pos.make();
	}

	// Simply compare the names of XML
	static public function simplyCompare( x1 : Xml, x2 : Xml ) : Bool {
		if (x1 == null || x2 == null || x1.nodeName != x2.nodeName)
			return false;
		var c1 = @:privateAccess x1.children.filter( x -> x.nodeType == Element );
		var c2 = @:privateAccess x2.children.filter( x -> x.nodeType == Element );
		if (c1.length != c2.length)
			return false;
		for (i in 0...c1.length) {
			if (!simplyCompare(c1[i], c2[i]))
				return false;
		}
		return true;
	}
}
