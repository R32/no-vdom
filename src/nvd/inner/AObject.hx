package nvd.inner;

 using haxe.macro.Tools;
 using haxe.macro.PositionTools;
import haxe.macro.Expr;
import haxe.macro.Type;
import haxe.macro.Context;

 using nvd.inner.Utils;
import nvd.inner.Utils.pfield;
import nvd.inner.AObject.raise;
import nvd.inner.Tags;

 using csss.Query;
import csss.xml.Xml;
import csss.xml.Parser;

class Markup {
	public var ctype : ComplexType; // ComplexType by xml.tagName. If unrecognized then default is `:js.html.DOMElement`
	public var path : Array<Int>;   // relative to TOP
	public var css : Null<String>;  // css-selector
	public var pos : Position;      // css-selector position
	public var xml : Xml;           // the XML Node
	var ownerField : FieldInfo;

	public function new( field, selector ) {
		ownerField = field;
		load(selector);
	}

	function load( selector : Expr ) {
		var component = ownerField.ownerAObject.component;
		switch (selector.expr) {
		case EConst(CIdent("null")) | EConst(CString("")):
			this.xml = component.top;
			this.path = [];
		case EConst(CString(s)):
			var xml = try component.top.querySelector(s) catch (_) null;
			if (xml == null)
				raise('Could not find "$s" in ${component.top.toSimpleString()}', selector.pos);
			this.css = s;
			this.xml = xml;
			this.path = component.getChildPath(xml);
		default:
			raise("UnSupported: " + selector.toString(), selector.pos);
		}
		this.pos = selector.pos;
		this.ctype = Tags.ctype(this.xml.nodeName, component.isSVG, true);
	}

	public function unify( type : Type ) {
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
					var cache = CachedXML.get(path);
					top = cache.xml.querySelector(css.getValue());
				case ECall(macro Nvd.buildString, [markup, _]):
					top = markup.doParse().firstElement();
				default:
				}
				if (top == this.xml || top.simplyCompare(this.xml))
					return true;
			}
		default:
		}
		return Context.unify(this.ctype.toType(), type);
	}
}

enum FieldMode {
	Elem;
	Attr;
	Prop;
	Style;
}

class FieldInfo { // Field

	public var readOnly : Bool;     // for "name"
	public var keepCSS : Bool;      // keep css in output/runtime
	public var markup : Markup;     // Associated makrup
	public var ctype : ComplexType; // the ctype of the attribute/property/style property name
	public var mode : FieldMode;    // what mode of "name"
	public var name : String;       // the attribute/property/style-property name

	@:allow(nvd.inner.Markup)
	var ownerAObject : AObject;
	var paths : Array<{name : String, pos : Position}>; // .style.display => ["display", "style"];

	public function new( aobj : AObject, expr : Expr ) {
		paths = [];
		ownerAObject = aobj;
		keepCSS = false;
		loadrec(expr);
	}

	function loadrec( e : Expr ) {
		switch(e.expr) {
		case EField(e2, field):
			paths.push({name : field, pos : pfield(e.pos, e2.pos)});
			loadrec(e2);
		case ECall(macro $i{"$"}, params):
			readPaths();
			this.markup = new Markup(this, params[0]);
			this.compatible(params);
			this.readAccess();
		case EArray(e, {expr : EConst(CString(name)), pos : pos}):
			paths.push({name : name, pos : pos});
			loadrec(e);
		case EParenthesis({expr: ECheckType(e, ct), pos: pos}):
			loadrec(e); // load info first
			if (!this.markup.unify(Context.resolveType(ct, pos)))
				raise(ct.toString() + " should be " + this.markup.ctype.toString(), pos);
			this.ctype = ct;
		case EParenthesis(e):
			loadrec(e);
		case EMeta(m, e):
			this.keepCSS = m.name == ":keep";
			loadrec(e);
		default:
			raise("UnSupported: " + e.toString(), e.pos);
		}
	}

	function compatible( params : Array<Expr> ) {
		var i = 1;
		var len = params.length;
		while (i < len) {
			var arg = params[i++];
			// old keepCSS syntax
			switch(arg.expr) {
			case EConst(CIdent("true")):
				this.keepCSS = true;
				continue;
			case EConst(CIdent("false")):
			default:
				raise("UnExpected: " + arg.toString(), arg.pos);
			}
		}
	}

	@:access(nvd.inner.Tags)
	function readAccess(){
		inline function posname() return this.paths[0].pos; // see readPaths()
		var access : FCTAccess = null;
		switch(this.mode) {
		case Elem:
			access = {ctype: this.markup.ctype, vacc: AccNo};
		case Attr:
			access = {ctype: macro :String, vacc: AccNormal};
		case Prop:
			access = Tags.access(markup.xml.nodeName, this.name, ownerAObject.component.isSVG);
			if (access == null)
				raise('<${markup.xml.nodeName}/> has no field "${this.name}"', posname());
			if (!simpleValid(this.markup.xml, this.name))
				access = {ctype: access.ctype, vacc: AccNo};
		case Style:
			access = Tags.style_access.get(this.name);
			if (access == null)
				raise('Style has no field "${this.name}"', posname());
		}
		this.ctype = access.ctype;
		this.readOnly = access.vacc != AccNormal;
	}

	// $("css").style.display => ["display", "style"]
	function readPaths() {
		var len = paths.length;
		switch(len) {
		case 0:
			this.mode = Elem;
		case 1:
			this.mode = Prop;
			this.name = paths[0].name;
		case 2:
			var mode = paths[1];
			switch(mode.name) {
			case "attr":
				this.mode = Attr;
			case "style":
				this.mode = Style;
			case unknown:
				// e.g: "$('s').parentNode.firstChild" is Not Yet Supported.
				raise("UnSupported Mode: " + unknown, mode.pos);
			}
			this.name = paths[0].name;
		default:
			paths.resize(len - 2);
			paths.reverse();
			var p1 = paths[0].pos;
			var p2 = paths[len - (2 + 1)].pos;
			raise("Not Yet Supported: " + paths.map(o -> o.name).join("."), p1.punion(p2));
		}
	}

	@:access(csss.xml.Xml)
	static function simpleValid( xml : Xml, prop : String ): Bool {
		return switch (prop) {
		case "textContent", "innerText":
			xml.children.length == 1 && xml.firstChild().nodeType == PCData;
		default:
			true;
		}
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

	public var bindings(default, null) : Map<String,FieldInfo>;

	public var component(default, null) : XMLComponent;

	public function new(comp) {
		component = comp;
		bindings = new Map();
	}

	public function parse( defs : Expr ) {
		switch (defs.expr) {
		case EBlock([]), EConst(CIdent("null")): // if null or {} then skip it
		case EObjectDecl(a):
			for (f in a) {
				if ( bindings.exists(f.field) )
					raise("Duplicate definition", f.expr.pos);
				bindings.set(f.field, new FieldInfo(this, f.expr));
			}
		default:
			raise("UnSupported: " + '"defs"', defs.pos);
		}
	}

	public static function raise( msg : String, pos : Position ) : Dynamic throw new AObjectError(msg, pos);
}
