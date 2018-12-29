package nvd;

#if macro
import haxe.macro.Expr;
import haxe.macro.Type;
import haxe.macro.Context;
import haxe.macro.PositionTools;
import nvd.p.HXX;
import csss.CValid;
import csss.xml.Xml;
using csss.Query;
using haxe.macro.Tools;

@:forward
private abstract XmlPos({file: String, min: Int}) from {file: String, min: Int} {
	inline function new(o: {file: String, min: Int}) this = o;

	public inline function pos(p, w) return PositionTools.make({
		file: this.file,
		min: this.min + p,
		max: this.min + p + w
	});
	public inline function xml(x: csss.xml.Xml) return pos(x.nodePos, x.nodeName.length);
}

private typedef DOMAttr = {
	xml: Xml,                 // the DOMElement
	ct: ComplexType,          // parsed ComplexType by xml.tagName. If unrecognized, default is `:js.html.DOMElement`
	path: Array<Int>,         // relative to root
	pos: haxe.macro.Position, // the first parameter of DefType
	css: String               // css selector which is used to finding it from root DOMElement.
}

private typedef FieldAccess = {
	ct: ComplexType,
	ac: VarAccess
}

private typedef DefInfo = {
	assoc: DOMAttr,           // Associated DOMElement
	name: String,             // the attribute/property name
	fct: ComplexType,         // the ctype of the attribute/property.
	argt: DefType,            // see below.
	w: Bool,                  // if AccNormal(can be written) then true.
	usecss: Bool,             // keep the css in output/runtime
}

@:enum private abstract DefType(Int) to Int {
	var Elem = 0;
	var Attr = 1;
	var Prop = 2;
	var Style = 3;
}

@:allow(Nvd)
class Macros {
	// for Nvd.h()
	static function attrParse(e: Expr, attr): Expr {
		return switch (e.expr) {
		case EConst(CString(s)):
			var name: String;
			var p = CValid.ident(s, 0, s.length, CValid.is_alpha_u, CValid.is_anum); // no longer allow "." for tagname
			if (p == 0) Context.fatalError('Invalid TagName: "$s"', e.pos);
			if (p == s.length) {
				name = s.toUpperCase();
			} else {
				name = s.substr(0, p).toUpperCase();
				nvd.p.Attr.run(s, p, s.length, attr);
			}
			macro $v{name};
		default:
			Context.fatalError("Unsupported type", e.pos);
		}
	}

	@:persistent static var files = new Map<String, csss.xml.Xml>();   // for Nvd.hx
	// complexType
	static var ct_dom = macro :js.html.DOMElement;
	static var ct_str = macro :String;
	// collections of complexType by tagname
	@:persistent static var ct_maps = new Map<String, ComplexType>();  // full_name => ComplexType
	static function cachedCType(t: Type): ComplexType {
		var ret: ComplexType = null;
		var name = switch (t) {
		case TInst(r, _):
			r.toString();
		case TAbstract(r, _):
			r.toString();
		default:
			null;
		}
		if (name != null) ret = ct_maps.get(name);
		if (ret == null) {
			ret = t.toComplexType();
			if (name != null) ct_maps.set(name, ret);
		}
		return ret;
	}

	static var xmlPos: XmlPos;
	// for detecting whether the field can be written.
	@:persistent static var facc: Map<String, FieldAccess> = null;              // field_name => FieldAccess
	@:persistent static var tacc: Map<String, Map<String, FieldAccess>> = null; // tagName => [faccs]
	@:persistent static var fstyle: Map<String, FieldAccess> = null;            // css => FieldAccess
	static function init() {
		if (facc != null) return;
		facc = new Map();
		tacc = new Map();
		facc.set("text", { ct: ct_str, ac: AccNormal });    // custom property
		facc.set("html", { ct: ct_str, ac: AccNormal });
		extractFVar(facc, Context.getType("js.html.DOMElement"), "js.html.EventTarget");

		fstyle = new Map();
		extractFVar(fstyle, Context.getType("js.html.CSSStyleDeclaration"), "");
	}

	// only for js.html.*Element
	static function extractFVar(out: Map<String, FieldAccess>, type: Type, stop = "js.html.Element"): Void {
		switch (type) {
		case TInst(r, _):
			var c: ClassType = r.get();
			while (true) {
				if (c.module == stop || c.module.substr(0, 7) != "js.html") break;
				var fs = c.fields.get();
				for (f in fs) {
					switch (f.kind) {
					case FVar(_, w):
						out.set(f.name, { ct: cachedCType(f.type), ac: w });
					default:
					}
				}
				if (stop != "" && c.superClass != null) {
					c = c.superClass.t.get();
				} else {
					break;
				}
			}
		default:
			Context.fatalError("Unsupported type", PositionTools.here());
		}
	}

	static function make(root: Xml, defs: Expr, xp: XmlPos, create: Bool): Array<Field> {
		xmlPos = xp;
		init();
		var pos = Context.currentPos();
		var cls: ClassType = Context.getLocalClass().get();
		var cls_path = switch (cls.kind) {
		case KAbstractImpl(_.get() => c):
			if (c.type.toString() != "nvd.Comp")
				Context.fatalError('[macro build]: Only for abstract ${c.name}(nvd.Comp) ...', pos);
			{pack: c.pack, name: c.name};
		default:
			Context.fatalError('[macro build]: Only for abstract type', pos);
		}
		var fields = Context.getBuildFields();
		var allFields = new Map<String, Bool>();
		for (f in fields) {
			allFields.set(f.name, true);
		}

		var ct_tag = tagToCtype(root.nodeName, root.nodeName == "SVG", false);
		if (!allFields.exists("_new")) { // abstract class constructor
			fields.push({
				name: "new",
				access: [APublic, AInline],
				pos: pos,
				kind: FFun({
					args: [{name: "d", type: ct_dom}],
					ret: null,
					expr: macro this = cast (d: js.html.DOMElement), // type checking and casting
				})
			});
		}
		fields.push({
			name: "d",
			access: [APublic],
			pos: pos,
			kind: FProp("get", "never", ct_tag)
		});
		fields.push({
			name: "get_d",
			access: [AInline, APrivate],
			pos: pos,
			meta: [{name: ":to", pos: pos}],
			kind: FFun({
				args: [],
				ret: ct_tag,
				expr: macro return cast this
			})
		});
		if (!allFields.exists("ofSelector")) {
			var enew = {expr: ENew(cls_path, [macro js.Browser.document.querySelector(s)]), pos: pos};
			fields.push({
				name: "ofSelector",
				access: [APublic, AInline, AStatic],
				pos: pos,
				kind: FFun({
					args: [{name: "s", type: ct_str}],
					ret: TPath(cls_path),
					expr: macro return $enew
				})
			});
		}
		if (create && !allFields.exists("create")) {
			var ecreate = xmlParse(root);
			ecreate = {expr: ENew(cls_path, [ecreate]), pos: pos};
			fields.push({
				name: "create",
				access: [APublic, AInline, AStatic],
				pos: pos,
				kind: FFun({
					args: [],
					ret: TPath(cls_path),
					expr: macro return $ecreate
				})
			});
		}

		var infos = new Map<String, DefInfo>();
		argParse(root, defs, infos);          // parse defs => infos
		for (k in infos.keys()) {
			var info = infos.get(k);
			var aname = info.name;
			var edom  = if (info.usecss && info.assoc.css != null && info.assoc.css != "") {
				macro cast d.querySelector($v{info.assoc.css});
			} else {
				info.assoc.path.length < 6
				? exprChildren(info.assoc.path, info.assoc.pos)
				: macro @:privateAccess cast this.lookup( $v{ info.assoc.path } );
			}
			edom = {  // same as: (cast this.lookup(): SomeElement)
				expr: ECheckType(edom, info.assoc.ct),
				pos : edom.pos
			};
			fields.push({
				name: k,
				access: [APublic],
				kind: FProp("get", info.w == true ? "set" : "never", info.fct),
				pos: info.assoc.pos,
			});

			fields.push({   // getter
				name: "get_" + k,
				access: [APrivate, AInline],
				kind: FFun( {
					args: [],
					ret: info.fct,
					expr: switch (info.argt) {
					case Elem: macro return $edom;
					case Attr: macro return $edom.getAttribute($v{ aname });
					case Prop:
						switch (aname) {
						case "text": macro return nvd.Dt.getText($edom);
						case "html": macro return $edom.innerHTML;
						default:     macro return $edom.$aname;
						}
					case Style: macro return $edom.style.$aname;  // return nvd.Dt.getCss($edom, $v{aname})???
					}
				}),
				pos: info.assoc.pos,
			});

			if (info.w) {
				fields.push({
					name: "set_" + k,
					access: [APrivate, AInline],
					kind: FFun({
						args: [{name: "v", type: info.fct}],
						ret: info.fct,
						expr: switch (info.argt) {
						case Attr: macro return nvd.Dt.setAttr($edom, $v{ aname }, v);
						case Prop:
							switch (aname) {
							case "text": macro return nvd.Dt.setText($edom, v);
							case "html": macro return $edom.innerHTML = v;
							default: macro return $edom.$aname = v;
							}
						case Style: macro return $edom.style.$aname = v;
						default: throw "ERROR";
						}
					}),
					pos: info.assoc.pos,
				});
			}
		}

		if (xmlPos.min == 0) { // from Nvd.build
			Context.registerModuleDependency(cls.module, xmlPos.file);
		}
		return fields;
	}

	static function simpleValid(xml: csss.xml.Xml, prop: String): Bool @:privateAccess {
		var pass = true;
		switch (prop) {
		case "textContent":
			pass = xml.children.length == 1 && xml.firstChild().nodeType == PCData;
		case "text":
			switch (xml.nodeName) {
			case "INPUT", "OPTION", "SELECT": // see nvd.Dt.setText();
			default:
				pass = xml.children.length == 1 && xml.firstChild().nodeType == PCData;
			}
		// case "innerHtml", "html":          // no idea how to handle it.
		default:
		}
		return pass;
	}

	static function exprChildren(a: Array<Int>, pos) {
		return a.length > 0
		? {expr: ECast(Context.parseInlineString("d.children[" + a.join("].children[") + "]", pos), null), pos: pos}
		: macro cast this;
	}

	static function exprString(e: Expr): String {
		return switch (e.expr) {
		case EConst(CString(s)):
			s;
		default:
			Context.fatalError("[macro build]: Expected String", e.pos);
		}
	}

	static function exprBool(e: Expr): Bool {
		return switch (e.expr) {
		case EConst(CIdent("true")):
			true;
		default:
			false;
		}
	}

	static function pathLookup(xml: Xml, path: Array<Int>, pi: Int): Xml {
		if (path.length == 0) return xml;
		var i  = 0;
		var ei = 0;
		var childs = @:privateAccess xml.children;
		var max = childs.length;
		var pv = path[pi++];
		while (i < max) {
			if (childs[i].nodeType == Element) {
				if (ei == pv) {
					if (pi == path.length)
						return childs[i];
					else
						return pathLookup(childs[i], path, pi);
				}
				++ ei;
			}
			++ i;
		}
		return null;
	}

	static function getPath(xml: Xml, top: Xml): Array<Int> {
		var ret = [];
		while (xml != top && xml.parent != null) {
			var i = 0;
			var ei = 0;
			var col = @:privateAccess xml.parent.children;
			var len = col.length;
			while (i < len) {
				if (col[i].nodeType == Element) {
					if (col[i] == xml) ret.push(ei);
					++ ei;
				} else if (col[i].nodeType != PCData) {
					Context.fatalError("Don't put **Comment, CDATA or ProcessingInstruction** in the Query Path.", xmlPos.xml(col[i]));
				}
				++ i;
			}
			xml = xml.parent;
		}
		if (xml == top)
			ret.reverse();
		else
			ret = null;
		return ret;
	}

	static function getDOMAttr(root: Xml, selector: Expr): DOMAttr {
		var xml: Xml = null;
		var path: Array<Int> = [];
		var css: String = null;
		switch (selector.expr) {
		case EConst(CString(s)):
			if (s == "") {
				xml = root;
			} else {
				xml = root.querySelector(s);
				if (xml == null)
					Context.fatalError('Could not find "$s" in ${root.toSimpleString()}', selector.pos);
				css = s;
				path = getPath(xml, root);
			}
		case EConst(CIdent("null")):
			xml = root;
		case EArrayDecl(a):
			path = [];
			for (n in a) {
				switch (n.expr) {
				case EConst(CInt(i)): path.push(Std.parseInt(i));
				default:
					Context.fatalError("[macro build]: Expected Int", n.pos);
				}
			}
			xml = pathLookup(root, path, 0);
			if (xml == null)
				Context.fatalError('Could not find "${"[" + path.join(",") + "]"}" in ${root.toSimpleString()}', selector.pos);
		default:
			Context.fatalError("[macro build]: Unsupported type", selector.pos);
		}
		var ct = tagToCtype(xml.nodeName, root.nodeName == "SVG"); // Note: this method will be extract all ComplexType of the field to "tacc"
		return {xml: xml, ct: ct, path: path, pos: selector.pos, css: css};
	}

	static function argParse(top: Xml, defs: Expr, out:Map<String, DefInfo>) {
		switch (defs.expr) {
		case EBlock([]), EConst(CIdent("null")): // if null or {} then skip it
		case EObjectDecl(a):
			for (f in a) {
				if (out.get(f.field) != null)
					Context.fatalError("Duplicate definition", f.expr.pos);
				switch (f.expr.expr) {
				case ECall(func, params):
					var assoc = getDOMAttr(top, params[0]);
					inline function isUseCss(n) return assoc.css != null && params.length > n && exprBool(params[n]);
					switch (func.expr) {
					case EConst(CIdent("Elem")):
						out.set(f.field, {argt: Elem, assoc: assoc, name: null, w: false, fct: assoc.ct, usecss: isUseCss(1)});

					case EConst(CIdent("Attr")):
						out.set(f.field, {argt: Attr, assoc: assoc, name: exprString(params[1]), w: true, fct: ct_str, usecss: isUseCss(2)});

					case EConst(CIdent("Prop")):
						var aname = exprString(params[1]);
						var fc = facc.get(aname);
						if (fc == null) {
							var elem = tacc.get(assoc.xml.nodeName);
							if (elem != null)
								fc = elem.get(aname);
						}
						if (fc == null) Context.fatalError('${assoc.xml.nodeName} has no field "$aname"', params[1].pos);
						out.set(f.field, {argt: Prop, assoc: assoc, name: aname, w: fc.ac == AccNormal && simpleValid(assoc.xml, aname), fct: fc.ct, usecss: isUseCss(2)});

					case EConst(CIdent("Style")):
						var cname = exprString(params[1]);
						var fc = fstyle.get(cname);
						if (fc == null) Context.fatalError('js.html.CSSStyleDeclaration has no field "$cname"', params[1].pos);
						out.set(f.field, {argt: Style, assoc: assoc, name: cname, w: fc.ac == AccNormal, fct: fc.ct, usecss: isUseCss(2)});

					default:
						Context.fatalError('[macro build]: Unsupported argument', func.pos);
					}
				default:
					Context.fatalError('[macro build]: Unsupported argument', f.expr.pos);
				}
			}
		default:
			Context.fatalError('[macro build]: Unsupported type for "defs"', defs.pos);
		}
	}

	static function xmlParse(xml: Xml): Expr {
		var attr = new haxe.DynamicAccess<String>();
		var a: Array<String> = @:privateAccess xml.attributeMap;
		var i = 0;
		while (i < a.length) {
			attr.set(a[i], a[i + 1]);
			i += 2;
		}
		attr.remove("id");
		var children = @:privateAccess xml.children;
		var len = children.length;
		var exprs = [];
		var i = 0, j = 0;
		while (i < len) {
			var child = children[i];
			if (child.nodeType == Element) {
				exprs.push(xmlParse(child));
				++ j;
			} else if (child.nodeType == PCData) {
				// discard HXX.parse
				if (child.nodeValue != "")
					exprs.push(macro $v{child.nodeValue});
			} else {
				Context.fatalError("Don't put **Comment, CDATA or ProcessingInstruction** in the Qurying Path.", xmlPos.xml(child));
			}
			++i;
		}
		var subs: Expr;
		if (exprs.length == 0)
			subs = macro null;
		else
			subs = len == 1 && children[0].nodeType == PCData ? exprs[0] : macro $a{exprs};
		return macro nvd.Dt.make($v{xml.nodeName}, $v{attr}, $subs);
	}

	static function tag2mod(tagname: String, svg: Bool): String {
		var name = tags.get(tagname);
		if (name == null) {
			name = tagname.charAt(0).toUpperCase() + tagname.substr(1).toLowerCase() + "Element";
			if (svg) name = "svg." + name;
			tags.set(tagname, name);
		}
		return "js.html." + name;
	}

	// got ComplexType by tagName and extract all fields from it...
	static function tagToCtype(tagname: String, svg = false, extract = true): ComplexType {
		var mod = tag2mod(tagname, svg);
		var ct = ct_maps.get(mod);
		if (ct == null) {
			var type = Context.getType(mod);
			if (type == null) {
				ct = ct_dom;  // default
			} else {
				if (extract) {
					if (!svg) {
						var fc = tacc.get(tagname);
						if (fc == null) {
							fc = new Map();
							extractFVar(fc, type);
							tacc.set(tagname, fc);
						}
					} else {
						throw "TODO: do not support svg elements for now";
					}
				}
				ct = type.toComplexType();
				ct_maps.set(mod, ct);
			}
		}
		return ct;
	}

	// Does not contain SVG elements.
	static var tags: haxe.DynamicAccess<String> = {
		"A"          : "AnchorElement",
	//	"AREA"       : "AreaElement",
	//	"AUDIO"      : "AudioElement",
	//	"BASE"       : "BaseElement",
	//	"BODY"       : "BodyElement",
		"BR"         : "BRElement",
	//	"BUTTON"     : "ButtonElement",
	//	"CANVAS"     : "CanvasElement",
	//	"DATA"       : "DataElement",
		"DATALIST"   : "DataListElement",
	//	"DIV"        : "DivElement",
	//	"EMBED"      : "EmbedElement",
		"FIELDSET"   : "FieldSetElement",
	//	"FONT"       : "FontElement",
	//	"FORM"       : "FormElement",
	//	"FRAME"      : "FrameElement",
		"FRAMESET"   : "FrameSetElement",
	//	"HEAD"       : "HeadElement",
		"H1"         : "HeadingElement",
		"H2"         : "HeadingElement",
		"H3"         : "HeadingElement",
		"H4"         : "HeadingElement",
		"H5"         : "HeadingElement",
		"H6"         : "HeadingElement",
		"HR"         : "HRElement",
	//	"HTML"       : "HtmlElement",
	//	"IFRAME"     : "IFrameElement",
		"IMG"        : "ImageElement",
	//	"INPUT"      : "InputElement",
	//	"LABEL"      : "LabelElement",
	//	"LEGEND"     : "LegendElement",
		"LI"         : "LIElement",
	//	"LINK"       : "LinkElement",

	//	"MENU"       : "MenuElement",
		"MENUITEM"   : "MenuItemElement",
	//	"META"       : "MetaElement",
	//	"METER"      : "MeterElement",

		"INS"        : "ModElement",
		"DEL"        : "ModElement",
	//	"OBJECT"     : "ObjectElement",
		"OL"         : "OListElement",
		"OPTGROUP"   : "OptGroupElement",
	//	"OPTION"     : "OptionElement",
	//	"OUTPUT"     : "OutputElement",
		"P"          : "ParagraphElement",
	//	"PARAM"      : "ParamElement",
	//	"PRE"        : "PreElement",
		"BLOCKQUOTE" : "QuoteElement",
		"Q"          : "QuoteElement",
	//	"SCRIPT"     : "ScriptElement",
	//	"SELECT"     : "SelectElement",
	//	"SOURCE"     : "SourceElement",
	//	"SPAN"       : "SpanElement",
	//	"STYLE"      : "StyleElement",
		"CAPTION"    : "TableCaptionElement",
		"TH"         : "TableCellElement",
		"TD"         : "TableCellElement",
		"COL"        : "TableColElement",
		"COLGROUP"   : "TableColElement",
	//	"TABLE"      : "TableElement",
		"TR"         : "TableRowElement",
		"THEAD"      : "TableSectionElement",
		"TBODY"      : "TableSectionElement",
		"TFOOT"      : "TableSectionElement",
	//	"TEMPLATE"   : "TemplateElement",
		"TEXTAREA"   : "TextAreaElement",
	//	"TITLE"      : "TitleElement",
	//	"TRACK"      : "TrackElement",
		"UL"         : "UListElement",
	//	"VIDEO"      : "VideoElement",
		"SVG"        : "svg.SVGElement",
	}
}
#else
extern class Macros{}
#end