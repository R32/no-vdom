package nvd.inner;

 using haxe.macro.Tools;
import haxe.macro.Expr;
import haxe.macro.Type;
import haxe.macro.PositionTools.make in pmake;
import haxe.macro.PositionTools.getInfos in pInfos;

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

@:structInit
class DOMAttr {
	public var xml(default, null) : Xml;                 // the DOMElement
	public var ctype(default, null) : ComplexType;       // ComplexType by xml.tagName. If unrecognized then default is `:js.html.DOMElement`
	public var path(default, null) : Array<Int>;         // relative to TOP
	public var pos(default, null) : Position;            // css-selector position
	public var css(default, null) : Null<String>;        // css-selector, if PATH then the value is null
	public function new(xml, ctype, path, pos, css) {
		this.xml = xml;
		this.ctype = ctype;
		this.path = path;
		this.pos = pos;
		this.css = css;
	}
}

class DFieldInfos {
	public var assoc(default, null): DOMAttr;      // Associated DOMElement
	public var type(default, null): DFieldType;
	public var name(default, null): String;        // the attribute/property/style-property name
	public var ctype(default, null): ComplexType;  // the ctype of the attribute/property/style property name
	public var readOnly(default, null): Bool;
	public var keepCSS(default, null): Bool;       // keep css in output/runtime
	public var isCustom(default, null): Bool;      // if defined by custom_props_access
	public function new(xml, type, name, ctype, readOnly, keepCSS , isCustom = false) {
		this.assoc = xml;
		this.type = type;
		this.name = name;
		this.ctype = ctype;
		this.readOnly = readOnly;
		this.keepCSS = keepCSS;
		this.isCustom = isCustom;
	}
}

/**
* parsed data from enum abstract.
*/
class AObject {

	var comp : XMLComponent;

	public var bindings(default, null) : Map<String,DFieldInfos>;

	public function new(comp) {
		this.comp = comp;
		bindings = new Map();
	}

	public function parse(defs : Expr) {
		switch (defs.expr) {
		case EBlock([]), EConst(CIdent("null")): // if null or {} then skip it
		case EObjectDecl(a):
			for (f in a)
				objectDeclField(f);
		default:
			Nvd.fatalError('Unsupported type for "defs"', defs.pos);
		}
	}

	@:access(nvd.inner.Tags)
	function objectDeclField(f : ObjectField) {
		if ( bindings.exists(f.field) )
			Nvd.fatalError("Duplicate definition", f.expr.pos);
		switch (f.expr.expr) {
		case EField(e, property):
			var type = Prop;
			// read params
			var params = switch(e.expr) {
			case ECall(macro $i{"$"}, params):
				params;
			case EField({expr: ECall(macro $i{"$"}, params), pos: p}, t):
				if (t == "attr")
					type = Attr;
				else if (t == "style")
					type = Style;
				else
					Nvd.fatalError('Unsupported EField: ' + t, posfield(e.pos, p));
				params;
			case _:
				Nvd.fatalError('Unsupported: ' + f.expr.toString(), f.expr.pos);
			}
			// read attr/prop/style
			var assoc = this.getDOMAttr(params[0]);
			var keepCSS = assoc.css != null && params.length == 2 && params[1].bool();
			var access: FCTAccess;
			var readOnly = false;
			var isCustom = false;
			switch(type) {
			case Elem: // unreachble
			case Attr:
				access = {ctype: macro :String, vacc: AccNormal}
				readOnly = false;
			case Prop:
				access = Tags.access(assoc.xml.nodeName, property, comp.isSVG);
				if (access == null) {
					if (!comp.isSVG)
						access = Tags.custom_props_access.get(property);
					if (access == null)
						Nvd.fatalError('${assoc.xml.nodeName} has no field "$property"', posfield(f.expr.pos, e.pos));
					isCustom = true;
				}
				readOnly = !(access.vacc == AccNormal && simpleValid(assoc.xml, property));
			case Style:
				access = Tags.style_access.get(property);
				if (access == null)
					Nvd.fatalError('js.html.CSSStyleDeclaration has no field "$property"', posfield(f.expr.pos, e.pos));
				readOnly = access.vacc != AccNormal;
			}
			var info = new DFieldInfos(assoc, type, property, access.ctype, readOnly, keepCSS, isCustom);
			bindings.set(f.field, info);

		case ECall(e, params):
			switch(e.expr) {
			case EConst(CIdent("$")):
				var assoc = this.getDOMAttr(params[0]);
				var keepCSS = assoc.css != null && params.length == 2 && params[1].bool();
				var info = new DFieldInfos(assoc, Elem, null, assoc.ctype, true, keepCSS, false);
				bindings.set(f.field, info);
			case _:
				Nvd.fatalError('Unsupported EField: ' + f.expr.toString(), f.expr.pos);
			}

		case EArray({expr: EField({expr: ECall(macro $i{"$"}, params), pos: _}, "attr"), pos: _}, macro $v{(attr : String)}):
			// $(selector).attr["key"]
			var assoc = this.getDOMAttr(params[0]);
			var keepCSS = assoc.css != null && params.length == 2 && params[1].bool();
			var info = new DFieldInfos(assoc, Attr, attr, macro :String, false, keepCSS, false);
			bindings.set(f.field, info);

		default:
			Nvd.fatalError('Unsupported argument', f.expr.pos);
		}
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
			xml = top.querySelector(s);
			if (xml == null)
				Nvd.fatalError('Could not find "$s" in ${top.toSimpleString()}', selector.pos);
			css = s;
			path = relapath(xml);
		case EArrayDecl(a):
			for (n in a) {
				switch (n.expr) {
				case EConst(CInt(i)): path.push(Std.parseInt(i));
				default:
					Nvd.fatalError("Expected Int", n.pos);
				}
			}
			xml = lookup(top, path, 0);
			if (xml == null)
				Nvd.fatalError('Could not find "${"[" + path.join(",") + "]"}" in ${top.toSimpleString()}', selector.pos);
		default:
			Nvd.fatalError("Unsupported type", selector.pos);
		}
		// it will be extract all fields of ComplexType to "html_access_pool"
		var ctype = Tags.ctype(xml.nodeName, comp.isSVG, true);
		return {xml: xml, ctype: ctype, path: path, pos: selector.pos, css: css};
	}

	function lookup(xml : Xml, path : Array<Int>, next : Int) : Xml {
		if (path.length == 0)
			return xml;
		var i = 0;
		var p = path[next++];
		var hasNext = next == path.length;
		for (child in @:privateAccess xml.children) {
			if (child.nodeType == PCData)
				continue; // don't do (i++)
			if (child.nodeType != Element)
				Nvd.fatalError("Comment/CDATA/ProcessingInstruction are not allowed here", comp.childPosition(child));
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
					Nvd.fatalError("Comment/CDATA/ProcessingInstruction are not allowed here", comp.childPosition(sib));
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
	static function posfield(full, left) {
		var pos = pInfos(full);
		pos.min = pInfos(left).max + 1; // ".".length == 1;
		return pmake(pos);
	}

	static function simpleValid( xml : Xml, prop : String ): Bool @:privateAccess {
		var pass = true;
		switch (prop) {
		case "textContent":
			pass = xml.children.length == 1 && xml.firstChild().nodeType == PCData;
		case "text":
			switch (xml.nodeName.toUpperCase()) {
			case "INPUT", "OPTION", "SELECT": // see nvd.Dt.setText();
			default:
				pass = xml.children.length == 1 && xml.firstChild().nodeType == PCData;
			}
		default:
		}
		return pass;
	}
}
