package nvd.inner;

 using haxe.macro.Tools;
 using haxe.macro.PositionTools;
import haxe.macro.Expr;
import haxe.macro.Type;
import haxe.macro.Context;

 using nvd.inner.Utils;
import nvd.inner.Tags;

 using csss.Query;
import csss.xml.Xml;
import csss.xml.Parser;


enum DFieldType {
	Elem;
	Attr;
	Prop;
	Style;
}

class DOMAttr {
	public var xml(default, null) : Xml;             // the DOMElement
	public var ctype(default, null) : ComplexType;   // ComplexType by xml.tagName. If unrecognized then default is `:js.html.DOMElement`
	public var path(default, null) : Array<Int>;     // relative to TOP
	public var pos(default, null) : Position;        // css-selector position
	public var css(default, null) : Null<String>;    // css-selector, if PATH then the value is null
	public function new(xml, ctype, path, pos, css) {
		this.xml = xml;
		this.ctype = ctype;
		this.path = path;
		this.pos = pos;
		this.css = css;
	}
}

class DFieldInfos {
	public var assoc(default, null) : DOMAttr;      // Associated DOMElement
	public var type(default, null) : DFieldType;
	public var name(default, null) : String;        // the attribute/property/style-property name
	public var ctype(default, null) : ComplexType;  // the ctype of the attribute/property/style property name
	public var readOnly(default, null) : Bool;
	public var keepCSS(default, null) : Bool;       // keep css in output/runtime
	public function new( xml, type, name, ctype, readOnly, keepCSS ) {
		this.assoc = xml;
		this.type = type;
		this.name = name;
		this.ctype = ctype;
		this.readOnly = readOnly;
		this.keepCSS = keepCSS;
	}
}

class AObjectError {
	public var msg : String;
	public var pos : Position;
	public function new( msg, pos ) {
		this.msg = msg;
		this.pos = pos;
	}
}

/**
* parsed data from enum abstract.
*/
class AObject {

	public var comp(default, null) : XMLComponent;

	public var bindings(default, null) : Map<String,DFieldInfos>;

	public function new(comp) {
		this.comp = comp;
		bindings = new Map();
	}

	public function parse( defs : Expr ) {
		switch (defs.expr) {
		case EBlock([]), EConst(CIdent("null")):    // if null or {} then skip it
		case EObjectDecl(a):
			for (f in a)
				objectDeclField(f);
		default:
			raise('Unsupported type for "defs"', defs.pos);
		}
	}

	function raise( msg : String, pos : Position ) : Dynamic throw new AObjectError(msg, pos);

	@:access(nvd.inner.Tags)
	function objectDeclField( f : ObjectField ) {
		if ( bindings.exists(f.field) )
			raise("Duplicate definition", f.expr.pos);
		switch (f.expr.expr) {
		case EField(e, property):                   // $("css-selector").attr|style|xxx
			var type = Prop;
			var params = switch(e.expr) {
			case ECall(macro $i{"$"}, params):
				params;
			case EField({expr: ECall(macro $i{"$"}, params), pos: p}, t):
				if (t == "attr")
					type = Attr;
				else if (t == "style")
					type = Style;
				else
					raise('Unsupported EField: ' + t, posfield(e.pos, p));
				params;
			default:
				raise('Unsupported: ' + f.expr.toString(), f.expr.pos);
			}
			// read attr/prop/style
			var assoc = this.getDOMAttr(params[0]);
			var keepCSS = assoc.css != null && params.length == 2 && params[1].bool();
			var access: FCTAccess;
			var readOnly = false;
			switch(type) {
			case Elem: // unreachble
			case Attr:
				access = {ctype: macro :String, vacc: AccNormal}
				readOnly = false;
			case Prop:
				access = Tags.access(assoc.xml.nodeName, property, comp.isSVG);
				if (access == null)
					raise('${assoc.xml.nodeName} has no field "$property"', posfield(f.expr.pos, e.pos));
				readOnly = !(access.vacc == AccNormal && simpleValid(assoc.xml, property));
			case Style:
				access = Tags.style_access.get(property);
				if (access == null)
					raise('js.html.CSSStyleDeclaration has no field "$property"', posfield(f.expr.pos, e.pos));
				readOnly = access.vacc != AccNormal;
			}
			var info = new DFieldInfos(assoc, type, property, access.ctype, readOnly, keepCSS);
			bindings.set(f.field, info);

		case ECall(e, params):                      // $("css-selector")
			switch(e.expr) {
			case EConst(CIdent("$")):
				var assoc = this.getDOMAttr(params[0]);
				var keepCSS = false;
				var ctype = assoc.ctype;
				var type : Null<Type> = null;
				for (i in 1...params.length) {
					var e = params[i];
					switch(e.expr) {
					case EConst(CIdent(s)):
						if (s == "true" || s == "false") {
							keepCSS = assoc.css != null && s == "true";
							continue;
						}
						try {
							var pack = Context.getLocalModule();
							var full = StringTools.endsWith(pack, "." + s) ? pack : pack + "." + s;
							type = Context.getType(full);
						} catch( _ ) {
							try type = Context.getType(s) catch (x) raise(Std.string(x), e.pos);
						}
					case EField(_):
						type = haxe.macro.Context.getType(e.toString());
					default:
						raise('Unsupported : ' + e.toString(), e.pos);
					}
					if (type != null)
						compValid(assoc, type, e.pos);
				}
				if (type != null) {
					ctype = type.toComplexType();
				}
				var info = new DFieldInfos(assoc, Elem, null, ctype, true, keepCSS);
				bindings.set(f.field, info);
			default:
				raise('Unsupported EField: ' + f.expr.toString(), f.expr.pos);
			}

		case EArray({expr: EField({expr: ECall(macro $i{"$"}, params), pos: _}, "attr"), pos: _}, macro $v{(attr : String)}):
		// $("css-selector").attr["key"]
			var assoc = this.getDOMAttr(params[0]);
			var keepCSS = assoc.css != null && params.length == 2 && params[1].bool();
			var info = new DFieldInfos(assoc, Attr, attr, macro :String, false, keepCSS);
			bindings.set(f.field, info);

		default:
			raise('Unsupported argument', f.expr.pos);
		}
	}

	function compValid( rel : DOMAttr, type : Type, pos : Position ) {
		switch(type) {
		case TAbstract(t, params):
			var ac = t.get();
			for (meta in ac.meta.get()) {
				if (meta.name != ":build")
					continue;
				var top : Xml = null;
				switch(meta.params[0].expr) {
				case ECall(macro Nvd.build, args) if (args.length >= 2):
					var path = args[0];
					var css = args[1];
					var cache = CachedXML.get(path.getValue(), path.pos); // NOTE: path.toString() is wrong
					top = cache.xml.querySelector(css.getValue());
				case ECall(macro Nvd.buildString, [xml, _]):
					top = xml.markup().parseXML(xml.pos).firstElement();
				default:
				}
				if (rel.xml.simplyCompare(top))
					return;
			}
		default:
		}
		if (!Context.unify(rel.ctype.toType(), type))
			raise(type.toString() + " is not allowed", pos);
	}

	function getDOMAttr( selector : Expr ) : DOMAttr {
		var xml = null;
		var css = null;
		var path = [];
		var top = comp.top;
		switch (selector.expr) {
		case EConst(CIdent("null")) | EConst(CString("")):
			xml = top;
		case EConst(CString(s)):
			try {
				xml = top.querySelector(s);
			} catch (e) {
				raise(Std.string(e), selector.pos);
			}
			if (xml == null)
				raise('Could not find "$s" in ${top.toSimpleString()}', selector.pos);
			css = s;
			path = relapath(xml);
		case EArrayDecl(a):
			for (n in a) {
				switch (n.expr) {
				case EConst(CInt(i)): path.push(Std.parseInt(i));
				default:
					raise("Expected Int", n.pos);
				}
			}
			xml = lookup(top, path, 0);
			if (xml == null)
				raise('Could not find "${"[" + path.join(",") + "]"}" in ${top.toSimpleString()}', selector.pos);
		default:
			raise("Unsupported type", selector.pos);
		}
		var ctype = Tags.ctype(xml.nodeName, comp.isSVG, true);
		return new DOMAttr(xml, ctype, path, selector.pos, css);
	}

	function lookup( xml : Xml, path : Array<Int>, next : Int ) : Xml {
		if (path.length == 0)
			return xml;
		var i = 0;
		var p = path[next++];
		var hasNext = next == path.length;
		for (child in @:privateAccess xml.children) {
			if (child.nodeType == PCData)
				continue; // don't do (i++)
			if (child.nodeType != Element)
				raise("Comment/CDATA/ProcessingInstruction are not allowed here", comp.childPosition(child));
			if (i == p)
				return hasNext ? lookup(child, path, next) : child;
			i++;
		}
		return null;
	}

	function relapath( xml : Xml ) : Array<Int> {
		var ret = [];
		var top = comp.top;
		while (xml != top && xml.parent != null) {
			var i = 0;
			var ei = 0;
			var found = false;
			var siblings = @:privateAccess xml.parent.children;
			while (i < siblings.length) {
				var sib = siblings[i];
				if (sib.nodeType == Element) {
					if (sib == xml) {
						found = true;
						break;
					}
					ei++;
				} else if (sib.nodeType != PCData) {
					raise("Comment/CDATA/ProcessingInstruction are not allowed here", comp.childPosition(sib));
				}
				i++;
			}
			if (!found)
				break;
			ret.push(ei);
			xml = xml.parent;
		}
		if (xml == top)
			ret.reverse();
		else
			ret = null;
		return ret;
	}


	// if a.b.c then get c.position
	static function posfield( full : Position, left : Position ) {
		var pos = full.getInfos();
		pos.min = left.getInfos().max + 1; // ".".length == 1;
		return pos.make();
	}

	static function simpleValid( xml : Xml, prop : String ): Bool @:privateAccess {
		var pass = true;
		switch (prop) {
		case "textContent", "innerText":
			pass = xml.children.length == 1 && xml.firstChild().nodeType == PCData;
		default:
		}
		return pass;
	}
}
