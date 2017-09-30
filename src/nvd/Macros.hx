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

@:forward(file, min)
private abstract XmlPos({file: String, min: Int}) from {file: String, min: Int} {
	inline function new(o: {file: String, min: Int}) this = o;

	public inline function xmlPos(p, w) return PositionTools.make({
		file: this.file,
		min: this.min + p,
		max: this.min + p + w
	});
}

private typedef XmlCt = {
	xml: Xml,
	ct: ComplexType,
	path: Array<Int>,
	pos: haxe.macro.Position // pos of arg
}

private typedef FCType = {
	t: ComplexType,
	w: VarAccess
}

private typedef Extra = {
	own: XmlCt,
	name: String,
	fct: ComplexType,
	argt: ExtraArgType,
	w: Bool,
}

@:enum private abstract ExtraArgType(Int) to Int {
	var Elem = 0;
	var Attr = 1;
	var Prop = 2;
}

@:allow(Nvd)
class Macros {
	static function attrParse(e: Expr, attr): Expr {
		return switch (e.expr) {
		case EConst(CString(s)):
			var name: String;
			var p = CValid.ident(s, 0, s.length, CValid.is_alpha_u, CValid.is_anumx);
			if (p == 0) Context.error('Invalid TagName: "$s"', e.pos);
			if (p == s.length) {
				name = s.toUpperCase();
			} else {
				name = s.substr(0, p).toUpperCase();
				nvd.p.PAttr.run(s, p, s.length, attr);
			}
			macro $v{name};
		case EConst(CIdent(i)):
			Context.warning('Only for tagName. Do not accept "[attr...]#id.class". Use "String Literal"', e.pos);
			macro $e.toUpperCase();
		default:
			Context.error("Unsupported type", e.pos);
		}
	}

	// complexType
	static var ct_dom = macro :js.html.DOMElement;
	static var ct_str = macro :String;
	static var ct_map = new Map<String, ComplexType>();  // full_name => ComplexType
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
		if (name != null) ret = ct_map.get(name);
		if (ret == null) {
			ret = t.toComplexType();
			if (name != null) ct_map.set(name, ret);
		}
		return ret;
	}

	// for detecting whether the field can be written.
	static var fdom: Map<String, FCType> = null;                        // field_name => FCType
	static var fdom_ex: Map<String, Map<String, FCType>> = new Map();   // tagName => [field_name => FCType]
	static function initBaseElems() {
		if (fdom != null) return;
		fdom = new Map();
		fdom.set("text", { t: ct_str, w: AccNormal });                  // custom prop
		fdom.set("html", { t: ct_str, w: AccNormal } );
		extractFVar(fdom, Context.getType("js.html.DOMElement"), "js.html.EventTarget");
	}

	// only for js.html.*Element;
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
						out.set(f.name, { t: cachedCType(f.type), w: w });
					default:
					}
				}
				if (c.superClass != null && c.superClass.t.toString() != stop) {
					c = c.superClass.t.get();
				} else {
					break;
				}
			}
		default:
			Context.error("Unsupported type", haxe.macro.PositionTools.here());
		}
	}

	static var fpos: XmlPos;
	static function make(el: Xml, extra: Expr, fp: XmlPos, create: Bool): Array<Field> {
		fpos = fp;
		initBaseElems();
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

		if (!all_fds.exists("_new")) { // abstract class constructor
			fields.push({
				name: "new",
				access: [APublic, AInline],
				pos: pos,
				kind: FFun({
					args: [{name: "d", type: ct_dom}],
					ret: null,
					expr: macro this = new nvd.Comp(d),
				})
			});
		}

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

		var ex: haxe.DynamicAccess<Extra> = {};
		// TODO: parse Xml
		var ecreate = xmlParse(el, ex, []);
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
		// parse extra args as FProp
		argParse(el, extra, ex);

		for (k in ex.keys()) {
			var v = ex.get(k);
			var aname = v.name;
			var elook = "lookup" + v.own.path.length;
			var edom = v.own.path.length < 6 // see Comp::lookup
				? macro @:privateAccess cast this.$elook($a{ (v.own.path: Array<Int>).map(function(i){return macro $v{i}}) })
				: macro @:privateAccess cast this.lookup($v { v.own.path } );
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
							case "text":  macro return nvd.Dt.setText($edom, v);
							case "html":  macro return $edom.innerHTML = v;
							default:      macro return $edom.$aname = v;
							}
						default: throw "ERROR";
						}
					}),
					pos: v.own.pos,
				});
			}
		}

		if (fpos.min == 0) { // from Nvd.build
			Context.registerModuleDependency(cls.module, fpos.file);
		}
		return fields;
	}

	static function exprString(e: Expr): String {
		return switch (e.expr) {
		case EConst(CString(s)):
			s;
		default:
			Context.error("[macro build]: Expected String", e.pos);
		}
	}

	static function epfind(xml: Xml, epath: Array<Int>, pi: Int): Xml {
		if (epath.length == 0) return xml;
		var i  = 0;
		var ei = 0;
		var childs = @:privateAccess xml.children;
		var max = childs.length;
		var pv = epath[pi++];
		while (i < max) {
			if (childs[i].nodeType == Element) {
				if (ei == pv) {
					if (pi == epath.length)
						return childs[i];
					else
						return epfind(childs[i], epath, pi);
				}
				++ ei;
			}
			++ i;
		}
		return null;
	}

	static function getEPath(xml: Xml, top: Xml): Array<Int> {
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
					throw "Do not include Comment-Node in the template";
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

	static function argXmlCt(top: Xml, e: Expr): XmlCt {
		var x: Xml = null;
		var ep: Array<Int>;
		var sel: String;
		switch (e.expr) {
		case EConst(CString(s)):
			x = s == "" ? top : top.querySelector(s);
			sel = s;
		case EArrayDecl(a):
			ep = [];
			for (n in a) {
				switch (n.expr) {
				case EConst(CInt(i)): ep.push(Std.parseInt(i));
				default:
					Context.error("[macro build]: Expected Int", n.pos);
				}
			}
			x = epfind(top, ep, 0);
			sel = "[" + ep.join(",") + "]";
		default:
			Context.error("[macro build]: Unsupported type", e.pos);
		}
		if (x == null) Context.error('Could not find "$sel" in ${top.toSimpleString()}', fpos.xmlPos(top.nodePos(), top.nodeName.length));
		if (ep == null) ep = getEPath(x, top);
		var ct = tag2ctype(x.nodeName, top.nodeName == "SVG"); // Note: this method will be extract all field ComplexType to "fdom_ex"
		return {xml: x, ct: ct, path: ep, pos: e.pos};
	}

	static function argParse(top: Xml, extra: Expr, out:haxe.DynamicAccess<Extra>) {
		switch (extra.expr) {
		case EBlock([]):
		case EConst(CIdent("null")):
		case EObjectDecl(a):
			for (f in a) {
				var val = f.expr;
				var xc: XmlCt = null;
				switch (val.expr) {
				case ECall(fn, pa):
					xc = argXmlCt(top, pa[0]);
					switch (fn.expr) {
					case EConst(CIdent("Elem")):
						out.set(f.field, {argt: Elem, own: xc, name: null, w: false, fct: xc.ct});
					case EConst(CIdent("Attr")):
						out.set(f.field, {argt: Attr, own: xc, name: exprString(pa[1]), w: true, fct: ct_str});
					case EConst(CIdent("Prop")):
						var aname = exprString(pa[1]);
						var fc = fdom.get(aname);
						if (fc == null) {
							var elem = fdom_ex.get(xc.xml.nodeName);
							if (elem != null)
								fc = elem.get(aname);
						}
						if (fc == null) Context.error('${xc.xml.nodeName} has no field "$aname"', pa[1].pos);
						out.set(f.field, {argt: Prop, own: xc, name: aname, w: fc.w == AccNormal, fct: fc.t});
					default:
						Context.error('[macro build]: Unsupported argument', fn.pos);
					}
				default:
					Context.error('[macro build]: Unsupported argument', val.pos);
				}
			}
		default:
			Context.error('[macro build]: Unsupported type for "extra"', extra.pos);
		}
	}

	static function xmlParse(xml: Xml, out: haxe.DynamicAccess<Extra>, epath: Array<Int>): Expr {
		var attr = new haxe.DynamicAccess<String>();
		for (aname in xml.attributes()) {
			if (aname.charCodeAt(0) == ":".code) continue; // It's a posInfo
			var value = xml.get(aname);
			var av = HXX.parse(value);
			var ap = fpos.xmlPos(xml.attrPos(aname), value.length);
			if (av.length > 1) Context.error("Do not supported currently", ap);
			switch (av[0]) {
			case Key(k):
				var xc = {xml: xml, ct: tag2ctype(xml.nodeName, xml.nodeName == "SVG"), path: epath, pos: ap};
				out.set(k, {own: xc, name: aname, fct: ct_str, w: true, argt: Attr });
			case Str(s, _):
				attr.set(aname, s);
			}
		}
		var subs = macro null;
		var children = @:privateAccess xml.children;
		var len = children.length;
		if (len == 1 && children[0].nodeType == PCData) {
			var value = children[0].nodeValue;
			var av = HXX.parse(value);
			var ap = fpos.xmlPos(children[0].nodePos(), value.length);
			if (av.length > 1) Context.error("Do not supported currently", ap);
			switch (av[0]) {
			case Key(k):
				var xc = {xml: xml, ct: tag2ctype(xml.nodeName, xml.nodeName == "SVG"), path: epath, pos: ap};
				out.set(k, {own: xc, name: "text", fct: ct_str, w: true, argt: Prop }); // custom prop "text"
				subs = macro $v{k};
			case Str(s, _):
				subs = macro $v{s};
			}
		} else if(len > 0) {
			var a = [];
			var i = 0, j = 0;
			while (i < len) {
				var child = children[i];
				var sp = epath.slice(0); // copy
				sp.push(j);
				if (child.nodeType == Element) {
					a.push(xmlParse(child, out, sp));
					++ j;
				} else if (child.nodeType == PCData) {
					var value = child.nodeValue;
					if (CValid.until(value, 0, value.length, CValid.is_space) < value.length)  // skip spaces text node
						a.push(macro $v{value.split("\r\n").join("\n")});                      // replace "\r\n" to "\n"
				} else {
					Context.error("Unsupported XML Type", fpos.xmlPos(child.nodePos(), child.nodeName.length));
				}
				++ i;
			}
			subs = macro $a{a};
		}
		return macro nvd.Dt.make($v{xml.nodeName}, $v{attr}, null, $subs);
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

	// got ComplexType by tagName and extract it all fields...
	static function tag2ctype(tagname: String, svg = false, extract = true): ComplexType {
		var mod = tag2mod(tagname, svg);
		var ct = ct_map.get(mod);
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
				ct_map.set(mod, ct);
			}
		}
		return ct;
	}

	// Do not contain SVG child elements.
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