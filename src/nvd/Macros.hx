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

	public inline function xml(x: csss.xml.Xml) return pos(x.nodePos(), x.nodeName.length);
}

private typedef DOMAttr = {
	xml: Xml,                 // the DOMElement
	ct: ComplexType,          // parsed ComplexType by xml.tagName. If unrecognized, default is `:js.html.DOMElement`
	path: Array<Int>,         // relative to root
	pos: haxe.macro.Position, // the pos of first parameter of DefType
	css: String               // css selector which is used to finding it from root DOMElement.
}

private typedef FCType = {
	ct: ComplexType,
	ac: VarAccess
}

private typedef DefInfo = {
	own: DOMAttr,             // Associated DOMElement
	name: String,             // a field name will be creating
	fct: ComplexType,         // the ctype of the field.
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
			if (p == 0) Context.error('Invalid TagName: "$s"', e.pos);
			if (p == s.length) {
				name = s.toUpperCase();
			} else {
				name = s.substr(0, p).toUpperCase();
				nvd.p.Attr.run(s, p, s.length, attr);
			}
			macro $v{name};
		case EConst(CIdent(i)):
			Context.warning('Note: parameter will be treated as tagname', e.pos);
			macro $e.toUpperCase();
		default:
			Context.error("Unsupported type", e.pos);
		}
	}

	static var files = new Map<String, csss.xml.Xml>();   // for Nvd.hx
	// complexType
	static var ct_dom = macro :js.html.DOMElement;
	static var ct_str = macro :String;
	// collections of complexType by tagname
	static var ct_maps = new Map<String, ComplexType>();  // full_name => ComplexType
	static function cachedCType(t: Type): ComplexType {
		var ret: ComplexType;
		var name = null;
		switch (t) {
		case TInst(r, _):
			name = r.toString();
		case TAbstract(r, _):
			name = r.toString();
		default:
		}
		if (name != null) ret = ct_maps.get(name);
		if (ret == null) {
			ret = t.toComplexType();
			if (name != null) ct_maps.set(name, ret);
		}
		return ret;
	}

	static var file_pos: XmlPos;
	// for detecting whether the field can be written.
	static var fdom: Map<String, FCType> = null;                        // field_name => FCType
	static var fdom_ex: Map<String, Map<String, FCType>> = new Map();   // tagName => [field_name => FCType]
	static var fstyle: Map<String, FCType> = null;                      // css => FCType
	static function initBase() {
		if (fdom != null) return;
		fdom = new Map();
		fdom.set("text", { ct: ct_str, ac: AccNormal });                  // custom prop
		fdom.set("html", { ct: ct_str, ac: AccNormal } );
		extractFVar(fdom, Context.getType("js.html.DOMElement"), "js.html.EventTarget");

		fstyle = new Map();
		extractFVar(fstyle, Context.getType("js.html.CSSStyleDeclaration"), null);
	}

	// only for js.html.*Element, Does not contain the type specified by the "stop"
	static function extractFVar(out: Map<String, FCType>, type: Type, stop = "js.html.Element"): Void {
		switch (type) {
		case TInst(r, _):
			var c: ClassType = r.get();
			while (true) {
				if (!(c.pack[0] == "js" && c.pack[1] == "html")) break; // limit in "js.html"
				var fs = c.fields.get();
				for (f in fs) {
					switch (f.kind) {
					case FVar(_, w):
						out.set(f.name, { ct: cachedCType(f.type), ac: w });
					default:
					}
				}
				if (stop != null && c.superClass != null && c.superClass.t.toString() != stop) {
					c = c.superClass.t.get();
				} else {
					break;
				}
			}
		default:
			Context.error("Unsupported type", haxe.macro.PositionTools.here());
		}
	}

	static function make(root: Xml, defs: Expr, fp: XmlPos, create: Bool): Array<Field> {
		file_pos = fp;
		initBase();
		var pos = Context.currentPos();
		var cls: ClassType = Context.getLocalClass().get();
		var cls_path;
		switch (cls.kind) {
		case KAbstractImpl(_.get() => c):
			cls_path = {pack: c.pack, name: c.name};
			if (c.type.toString() != "nvd.Comp")
				Context.error('[macro build]: Only for abstract ${cls_path.name}(nvd.Comp) ...', pos);
		default:
			Context.error('[macro build]: Only for abstract type', pos);
		}
		var fields = Context.getBuildFields();
		var all_fds = new haxe.ds.StringMap<Bool>();
		for (f in fields) {
			all_fds.set(f.name, true);
		}

		var ct_tag = tag2ctype(root.nodeName, root.nodeName == "SVG", false);
		if (!all_fds.exists("_new")) { // abstract class constructor
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
		if (!all_fds.exists("ofSelector")) {
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

		var infos: haxe.DynamicAccess<DefInfo> = {};
		var ecreate = xmlParse(root, infos, []);  // parse data from XML => infos
		if (create && !all_fds.exists("create")) {
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

		argParse(root, defs, infos);              // parse data by defs => infos

		for (k in infos.keys()) {
			var v = infos.get(k);
			var aname = v.name;
			var elook = "lookup" + v.own.path.length;
			var edom: Expr;
			if (v.usecss && v.own.css != null && v.own.css != "") {
				edom = macro cast d.querySelector($v{v.own.css});
			} else {
				edom = v.own.path.length < 6 // see Comp::lookup
					? macro @:privateAccess cast this.$elook($a{ (v.own.path: Array<Int>).map(function(i){return macro $v{i}}) })
					: macro @:privateAccess cast this.lookup($v{ v.own.path } );
			}
			edom = {  // same as: (cast this.lookup(): SomeElement)
				expr: ECheckType(edom, v.own.ct),
				pos : edom.pos
			};

			fields.push({
				name: k,
				access: [APublic],
				kind: FProp("get", v.w == true ? "set" : "never", v.fct),
				pos: v.own.pos,
			});

			fields.push({   // getter
				name: "get_" + k,
				access: [APrivate, AInline],
				kind: FFun( {
					args: [],
					ret: v.fct,
					expr: switch (v.argt) {
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
				pos: v.own.pos,
			});

			if (v.w) {
				fields.push({
					name: "set_" + k,
					access: [APrivate, AInline],
					kind: FFun({
						args: [{name: "v", type: v.fct}],
						ret: v.fct,
						expr: switch (v.argt) {
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
					pos: v.own.pos,
				});
			}
		}

		if (file_pos.min == 0) { // from Nvd.build
			Context.registerModuleDependency(cls.module, file_pos.file);
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

	static function exprString(e: Expr): String {
		return switch (e.expr) {
		case EConst(CString(s)):
			s;
		default:
			Context.error("[macro build]: Expected String", e.pos);
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

	static function pLookup(xml: Xml, path: Array<Int>, pi: Int): Xml {
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
						return pLookup(childs[i], path, pi);
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
				} else if (col[i].nodeType != PCData) { // (#CData, #ProcessingInstruction => #comment) in IE8
					throw "Error has been reported by xmlParse.";
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

	static function getDOMAttr(root: Xml, pa0: Expr): DOMAttr {
		var x: Xml = null;
		var path: Array<Int> = [];
		var css: String = null;
		switch (pa0.expr) {
		case EConst(CString(s)):
			if (s == "") {
				x = root;
			} else {
				x = root.querySelector(s);
				if (x == null)
					Context.error('Could not find "$s" in ${root.toSimpleString()}', pa0.pos);
				css = s;
				path = getPath(x, root);
			}
		case EConst(CIdent("null")):
			x = root;
		case EArrayDecl(a):
			path = [];
			for (n in a) {
				switch (n.expr) {
				case EConst(CInt(i)): path.push(Std.parseInt(i));
				default:
					Context.error("[macro build]: Expected Int", n.pos);
				}
			}
			x = pLookup(root, path, 0);
			if (x == null)
				Context.error('Could not find "${"[" + path.join(",") + "]"}" in ${root.toSimpleString()}', pa0.pos);
		default:
			Context.error("[macro build]: Unsupported type", pa0.pos);
		}
		var ct = tag2ctype(x.nodeName, root.nodeName == "SVG"); // Note: this method will be extract all ComplexType of the field to "fdom_ex"
		return {xml: x, ct: ct, path: path, pos: pa0.pos, css: css};
	}

	static function argParse(top: Xml, defs: Expr, out:haxe.DynamicAccess<DefInfo>) {
		switch (defs.expr) {
		case EBlock([]), EConst(CIdent("null")): // if null or {} then skip it
		case EObjectDecl(a):
			for (f in a) {
				var prev = out.get(f.field);
				if (prev != null)
					Context.error("Duplicate definition", prev.own.pos);
				switch (f.expr.expr) {
				case ECall(fn, pa):
					var da = getDOMAttr(top, pa[0]);
					inline function isUseCss(n) return da.css != null && pa.length > n && exprBool(pa[n]);
					switch (fn.expr) {
					case EConst(CIdent("Elem")):
						out.set(f.field, {argt: Elem, own: da, name: null, w: false, fct: da.ct, usecss: isUseCss(1)});

					case EConst(CIdent("Attr")):
						out.set(f.field, {argt: Attr, own: da, name: exprString(pa[1]), w: true, fct: ct_str, usecss: isUseCss(2)});

					case EConst(CIdent("Prop")):
						var aname = exprString(pa[1]);
						var fc = fdom.get(aname);
						if (fc == null) {
							var elem = fdom_ex.get(da.xml.nodeName);
							if (elem != null)
								fc = elem.get(aname);
						}
						if (fc == null) Context.error('${da.xml.nodeName} has no field "$aname"', pa[1].pos);
						out.set(f.field, {argt: Prop, own: da, name: aname, w: fc.ac == AccNormal && simpleValid(da.xml, aname), fct: fc.ct, usecss: isUseCss(2)});

					case EConst(CIdent("Style")):
						var cname = exprString(pa[1]);
						var fc = fstyle.get(cname);
						if (fc == null) Context.error('js.html.CSSStyleDeclaration has no field "$cname"', pa[1].pos);
						out.set(f.field, {argt: Style, own: da, name: cname, w: fc.ac == AccNormal, fct: fc.ct, usecss: isUseCss(2)});

					default:
						Context.error('[macro build]: Unsupported argument', fn.pos);
					}
				default:
					Context.error('[macro build]: Unsupported argument', f.expr.pos);
				}
			}
		default:
			Context.error('[macro build]: Unsupported type for "defs"', defs.pos);
		}
	}

	static function xmlParse(xml: Xml, out: haxe.DynamicAccess<DefInfo>, path: Array<Int>): Expr {
		var attr = new haxe.DynamicAccess<String>();
		for (aname in xml.attributes()) {
			if (aname.charCodeAt(0) == ":".code || aname == "id") continue; // It's a posInfo or id
			attr.set(aname, xml.get(aname));
		}
		var children = @:privateAccess xml.children;
		var len = children.length;
		var subpath: Array<Int> = null;
		var exprs = [];
		var i = 0, j = 0;
		while (i < len) {
			var child = children[i];
			if (child.nodeType == Element) {
				subpath = path.slice(0);
				subpath.push(j);
				exprs.push(xmlParse(child, out, subpath));
				++ j;
			} else if (child.nodeType == PCData) {
				if (child.nodeValue != "")
					exprs.push(macro $v{child.nodeValue});
			/* it works, but the "{{value}}" must be initialized when you call `New`
				var textpos = file_pos.pos(child.nodePos(), child.nodeValue.length);
				var hxx = HXX.parse(child.nodeValue);
				if (hxx.length == 1) {
					switch (hxx[0]) {
					case Variable(k, opt):
						var node: Xml;
						var argtype: DefType;
						if (i == 0 && len == 1) {
							node = xml;
							argtype = Prop;
							subpath = path;
						} else {  // len > 1
							subpath = path.slice(0);
							subpath.push(j);
							if (i == 0) {
								node = children[i + 1];
								argtype = TextPrev;
							} else {
								node = children[i - 1];
								argtype = TextNext;
							}
						}
						exprs.push(macro $v{opt == null ? k : opt});
						var da: DOMAttr = {xml: node, path: subpath, pos: textpos, css: null , ct: tag2ctype(xml.nodeName, xml.nodeName == "SVG")};
						if (out.exists(k))
							Context.error("Duplicate definition", textpos);
						out.set(k, {own: da, argt: argtype, name: "textContext", fct: ct_str, w: true, usecss: false});
					case Text(s):
						exprs.push(macro $v{s});
					}

				} else if (hxx.length > 1) {
					Context.error("Unsupported yet", textpos);
				}
			*/
			} else {
				Context.error("Don't put **Comment, CDATA or ProcessingInstruction** in the Qurying Path.", file_pos.xml(child));
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
	static function tag2ctype(tagname: String, svg = false, extract = true): ComplexType {
		var mod = tag2mod(tagname, svg);
		var ct = ct_maps.get(mod);
		if (ct == null) {
			var type = Context.getType(mod);
			if (type == null) {
				ct = ct_dom;  // default
			} else {
				if (extract) {
					if (!svg) {
						var fc = fdom_ex.get(tagname);
						if (fc == null) {
							fc = new Map();
							extractFVar(fc, type);
							fdom_ex.set(tagname, fc);
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
	//	"TEXTAREA"   : "TextAreaElement",
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