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
private abstract XmlPosition({file: String, min: Int}) from {file: String, min: Int} {
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
	ct: ComplexType,          // parsed ComplexType by xml.tagName. If unrecognized then default is `:js.html.DOMElement`
	path: Array<Int>,         // relative to root
	pos: haxe.macro.Position, // the first parameter of DefType
	css: Null<String>         // css selector which will be used to query from root DOMElement, if use PATH then the value is null
}

private typedef FieldAccess = {
	ct: ComplexType,
	ac: VarAccess
}

private typedef DefInfo = {
	assoc: DOMAttr,           // Associated DOMElement
	name: String,             // the attribute/property/style property name
	fct: ComplexType,         // the ctype of the attribute/property/style property name
	type: DefType,            // see below.
	w: Bool,                  // if AccNormal(can be written) then true.
	usecss: Bool,             // keep the css in output/runtime
}

enum DefType {
	Elem;
	Attr;
	Prop;
	Style;
}

class CachedXMLFile {

	public var xml(default, null): csss.xml.Xml;

	var lastModify: Float;

	function new() {
		lastModify = 0.;
	}
	function update(path: String, pos) {
		try {
			var stat = sys.FileSystem.stat(path);
			var mtile = stat.mtime.getTime();
			if (mtile > this.lastModify) {
				this.xml = csss.xml.Xml.parse( sys.io.File.getContent(path) );
				this.lastModify = mtile;
			}
		} catch(err: csss.xml.Parser.XmlParserException) {
			Macros.fatalError(err.toString(), PositionTools.make({
				file: path,
				min: err.position,
				max: err.position + 1
			}));
		} catch (err: Dynamic) {
			Macros.fatalError(Std.string(err), pos);
		}
	}

	public static function make(path, pos): CachedXMLFile {
		var cache = cached.get(path);
		if (cache == null) {
			cache = new CachedXMLFile();
			cached.set(path, cache);
		}
		cache.update(path, pos);
		return cache;
	}
		// cached xml file
	@:persistent static var cached = new Map<String, CachedXMLFile>();
}

@:allow(Nvd)
class Macros {
	// only for Nvd.h()
	static function attrParse(e: Expr, attr): Expr {
		return switch (e.expr) {
		case EConst(CString(s)):
			var name: String;
			var p = CValid.ident(s, 0, s.length, CValid.is_alpha_u, CValid.is_anum); // no longer allow "." for tagname
			if (p == 0) fatalError('Invalid TagName: "$s"', e.pos);
			if (p == s.length) {
				name = s.toUpperCase();
			} else {
				name = s.substr(0, p).toUpperCase();
				nvd.p.Attr.run(s, p, s.length, attr);
			}
			macro $v{name};
		default:
			fatalError("Unsupported type", e.pos);
		}
	}


	/////////////////////////////////////////////////////////////////////


	static inline var ERR_PREFIX = "[no-vdom]: ";

	static public inline function fatalError(msg, pos):Dynamic return Context.fatalError(ERR_PREFIX + msg, pos);

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

	static var xml_position: XmlPosition;
	// for detecting whether the field can be written.
	@:persistent static var dom_property_access: Map<String, FieldAccess> = null;          // property_name => FieldAccess
	@:persistent static var tag_dom_access: Map<String, Map<String, FieldAccess>> = null;  // tagName => [dom_property_access]
	@:persistent static var style_access: Map<String, FieldAccess> = null;                 // css => FieldAccess
	static function init(xmlpos: XmlPosition) {
		xml_position = xmlpos;
		if (dom_property_access != null) return;
		dom_property_access = new Map();
		tag_dom_access = new Map();
		dom_property_access.set("text", { ct: ct_str, ac: AccNormal });    // custom property
		dom_property_access.set("html", { ct: ct_str, ac: AccNormal });
		extractFVar(dom_property_access, Context.getType("js.html.DOMElement"), "js.html.EventTarget");

		style_access = new Map();
		extractFVar(style_access, Context.getType("js.html.CSSStyleDeclaration"), "");
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
			fatalError("Unsupported type", PositionTools.here());
		}
	}

	static function make(root: Xml, defs: Expr, xmlpos: XmlPosition, create: Bool): Array<Field> {
		init(xmlpos);
		var pos = Context.currentPos();
		var cls: ClassType = Context.getLocalClass().get();
		var cls_path = switch (cls.kind) {
		case KAbstractImpl(_.get() => c):
			if (c.type.toString() != "nvd.Comp")
				fatalError('Only for abstract ${c.name}(nvd.Comp) ...', pos);
			{pack: c.pack, name: c.name};
		default:
			fatalError('Only for abstract type', pos);
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
			fields.push({
				name: "ofSelector",
				access: [APublic, AInline, AStatic],
				pos: pos,
				kind: FFun({
					args: [{name: "s", type: ct_str}],
					ret: TPath(cls_path),
					expr: macro return js.Syntax.code("document.querySelector({0})", s)
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
					expr: switch (info.type) {
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
						expr: switch (info.type) {
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

		if (xml_position.min == 0) { // from Nvd.build
			Context.registerModuleDependency(cls.module, xml_position.file);
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
			fatalError("Expected String", e.pos);
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
					fatalError("Don't put **Comment, CDATA or ProcessingInstruction** in the Query Path.", xml_position.xml(col[i]));
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
					fatalError('Could not find "$s" in ${root.toSimpleString()}', selector.pos);
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
					fatalError("Expected Int", n.pos);
				}
			}
			xml = pathLookup(root, path, 0);
			if (xml == null)
				fatalError('Could not find "${"[" + path.join(",") + "]"}" in ${root.toSimpleString()}', selector.pos);
		default:
			fatalError("Unsupported type", selector.pos);
		}
		var ct = tagToCtype(xml.nodeName, root.nodeName == "SVG"); // Note: this method will be extract all ComplexType of the field to "tag_dom_access"
		return {xml: xml, ct: ct, path: path, pos: selector.pos, css: css};
	}

	static function calcEFieldPosition(full, left) {
		var p1 = PositionTools.getInfos(full);
		var min = PositionTools.getInfos(left).max + 1; // ".".length == 1
		p1.min = min;
		return PositionTools.make(p1);
	}

	static function argParse(top: Xml, defs: Expr, out:Map<String, DefInfo>) {
		switch (defs.expr) {
		case EBlock([]), EConst(CIdent("null")): // if null or {} then skip it
		case EObjectDecl(a):
			for (f in a) {
				if (out.get(f.field) != null) fatalError("Duplicate definition", f.expr.pos);

				switch (f.expr.expr) {
				case EField(e, property):        //  $("sel").PROPERTY, $("sel").style.PROPERTY, $("sel").attr.ATTRIBUTE
					var type:DefType = Prop;
					var params = switch(e.expr) {
					case ECall(macro $i{"$"}, params):
						params;
					case EField({expr: ECall(macro $i{"$"}, params), pos: _}, t):
						if (t == "style") {
							type = Style;
						} else if (t == "attr") {
							type = Attr;
						} else {
							fatalError('Unsupported EField: ' + f.expr.toString(), f.expr.pos);
						}
						params;
					case _:
						fatalError('Unsupported EField: ' + f.expr.toString(), f.expr.pos);
					}
					var assoc = getDOMAttr(top, params[0]);
					var usecss = assoc.css != null && params.length == 2 && exprBool(params[1]);
					var access: FieldAccess;
					var write = false;
					if (type == Prop) {
						access = dom_property_access.get(property);
						if (access == null) {
							var elem = tag_dom_access.get(assoc.xml.nodeName);
							if (elem != null) {
								access = elem.get(property);
							}
						}
						if (access == null)
							fatalError('${assoc.xml.nodeName} has no field "$property"', calcEFieldPosition(f.expr.pos, e.pos));
						write = access.ac == AccNormal && simpleValid(assoc.xml, property);
					} else if (type == Style) {
						access = style_access.get(property);
						if (access == null)
							fatalError('js.html.CSSStyleDeclaration has no field "$property"', calcEFieldPosition(f.expr.pos, e.pos));
						write = access.ac == AccNormal;
					} else { // Attr
						access = {
							ct: ct_str,
							ac: AccNormal,
						}
						write = true;
					}
					out.set(f.field, {type: type, assoc: assoc, name: property, w: write, fct: access.ct, usecss: usecss});

				case ECall(e, params):
					switch(e.expr) {
					case EConst(CIdent(s)): // For compatibility with old
						var assoc = getDOMAttr(top, params[0]);
						inline function isUseCss(n) return assoc.css != null && params.length > n && exprBool(params[n]);
						switch(s) {
						case "$" | "Elem":
							out.set(f.field, {type: Elem, assoc: assoc, name: null, w: false, fct: assoc.ct, usecss: isUseCss(1)});
						case "Attr":
							out.set(f.field, {type: Attr, assoc: assoc, name: exprString(params[1]), w: true, fct: ct_str, usecss: isUseCss(2)});
						case "Prop":
							var property = exprString(params[1]);
							var access = dom_property_access.get(property);
							if (access == null) {
								var elem = tag_dom_access.get(assoc.xml.nodeName);
								if (elem != null) {
									access = elem.get(property);
								}
							}
							if (access == null)
								fatalError('${assoc.xml.nodeName} has no field "$property"', params[1].pos);
							var write = access.ac == AccNormal && simpleValid(assoc.xml, property);
							out.set(f.field, {type: Prop, assoc: assoc, name: property, w: write, fct: access.ct, usecss: isUseCss(2)});
						case "Style":
							var property = exprString(params[1]);
							var access = style_access.get(property);
							if (access == null)
								fatalError('js.html.CSSStyleDeclaration has no field "$property"', params[1].pos);
							out.set(f.field, {type: Style, assoc: assoc, name: property, w: access.ac == AccNormal, fct: access.ct, usecss: isUseCss(2)});
						case _:
							fatalError('Unsupported : ' + s, e.pos);
						}
					case _:
						fatalError('Unsupported EField: ' + f.expr.toString(), f.expr.pos);
					}

				case EArray({expr: EField({expr: ECall(macro $i{"$"}, query), pos: _}, "attr"), pos: _}, macro $v{(attribute:String)}):
					// $(selector).attr["ATTRIBUTE"]
					var assoc = getDOMAttr(top, query[0]);
					var usecss = assoc.css != null && query.length == 2 && exprBool(query[1]);
					out.set(f.field, {type: Attr, assoc: assoc, name: attribute, w: true, fct: ct_str, usecss: usecss});

				default:
					fatalError('Unsupported argument', f.expr.pos);
				}
			}
		default:
			fatalError('Unsupported type for "defs"', defs.pos);
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
				fatalError("Don't put **Comment, CDATA or ProcessingInstruction** in the Qurying Path.", xml_position.xml(child));
			}
			++i;
		}
		var exprArgs = [macro $v{ xml.nodeName.toUpperCase() }];
		if ( attr.iterator().hasNext() ) { // ?? Lambda.empty(attr) didn't work
			exprArgs.push( macro $v{attr} );
		} else if (exprs.length > 0) {
			exprArgs.push( macro null );
		}
		if (exprs.length > 0) {
			exprArgs.push( len == 1 && children[0].nodeType == PCData ? exprs[0] : macro $a{exprs} );
		}
		return macro nvd.Dt.make( $a{exprArgs} );
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
						var fc = tag_dom_access.get(tagname);
						if (fc == null) {
							fc = new Map();
							extractFVar(fc, type);
							tag_dom_access.set(tagname, fc);
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