package nvd;

#if macro
import haxe.macro.Expr;
import haxe.macro.Type;
import haxe.macro.Context;
import haxe.macro.PositionTools;
import csss.CValid;
import csss.xml.Xml;
using csss.Query;
using haxe.macro.Tools;

@:structInit
private class DOMAttr {
	public var xml(default, null): Xml;                 // the DOMElement
	public var ctype(default, null): ComplexType;       // ComplexType by xml.tagName. If unrecognized then default is `:js.html.DOMElement`
	public var path(default, null): Array<Int>;         // relative to TOP
	public var pos(default, null): haxe.macro.Position; // css-selector/PATH position
	public var css(default, null): Null<String>;        // css-selector, if PATH then the value is null
	public function new(xml, ctype, path, pos, css) {
		this.xml = xml;
		this.ctype = ctype;
		this.path = path;
		this.pos = pos;
		this.css = css;
	}
}

@:structInit
private class FieldAccess {
	public var ctype(default, null): ComplexType;
	public var vacc(default, null): VarAccess;
	public function new(ctype, vacc) {
		this.ctype = ctype;
		this.vacc = vacc;
	}
}

private class FieldInfos {
	public var assoc(default, null): DOMAttr;      // Associated DOMElement
	public var type(default, null): FieldType;
	public var name(default, null): String;        // the attribute/property/style-property name
	public var ctype(default, null): ComplexType;  // the ctype of the attribute/property/style property name
	public var readOnly(default, null): Bool;
	public var keepCSS(default, null): Bool;       // keep the css in output/runtime
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

private enum FieldType {
	Elem;
	Attr;
	Prop;
	Style;
}

private enum HXXState {
	BEGIN;
	BRACE_START;
}

@:access(nvd.Macros)
class XMLComponent {

	// how many XML nodes in this XMLComponent, available after call parseXML
	public var count(default, null): Int;

	public var posOffset(default, null): Int;

	public var path(default, null): String;

	public var top(default, null): csss.xml.Xml;

	public var isSVG(default, null):Bool;

	public var bindings(default, null): Map<String, FieldInfos>;

	public var isHXX: Bool;

	public function new(p, offset, node, svg) {
		init();  // static init
		count = 0;
		path = p;
		posOffset = offset;
		top = node;
		bindings = new Map();
		isSVG = svg;
	}

	public function getCType(tagname:String):ComplexType {
		return tagToCtype(tagname, this.isSVG, false);
	}

	public function offsetPosition(offset:Int, len:Int):Position {
		return PositionTools.make({
			file: path,
			min: posOffset + offset,
			max: posOffset + offset + len
		});
	}

	public inline function childXMLPosition(sub: csss.xml.Xml):Position {
		return offsetPosition(sub.nodePos, sub.nodeName.length);
	}

	public function parseDefs(defs: Expr) {
		switch (defs.expr) {
		case EBlock([]), EConst(CIdent("null")): // if null or {} then skip it
		case EObjectDecl(a):
			for (f in a) {
				if ( bindings.exists(f.field) ) {
					Macros.fatalError("Duplicate definition", f.expr.pos);
				}
				switch (f.expr.expr) {
				case EField(e, property):
					var type = Prop;
					var params = switch(e.expr) {
					case ECall(macro $i{"$"}, params):
						params;
					case EField({expr: ECall(macro $i{"$"}, params), pos: p}, t):
						if (t == "style") {
							type = Style;
						} else if (t == "attr") {
							type = Attr;
						} else {
							Macros.fatalError('Unsupported EField: ' + t, Macros.getEFieldPosition(e.pos, p));
						}
						params;
					case _:
						Macros.fatalError('Unsupported: ' + f.expr.toString(), f.expr.pos);
					}
					var assoc = this.getDOMAttr(params[0]);
					var keepCSS = assoc.css != null && params.length == 2 && Macros.exprBool(params[1]);
					var access: FieldAccess;
					var readOnly = false;
					var isCustom = false;
					if (type == Prop) {
						access = getPropertyAccess(assoc.xml.nodeName, property);
						if (access == null) {
							if (!this.isSVG) {
								access = custom_props_access.get(property);
							}
							if (access == null)
								Macros.fatalError('${assoc.xml.nodeName} has no field "$property"', Macros.getEFieldPosition(f.expr.pos, e.pos));
							isCustom = true;
						}
						readOnly = !(access.vacc == AccNormal && simpleValid(assoc.xml, property));
					} else if (type == Style) {
						access = style_access.get(property);
						if (access == null)
							Macros.fatalError('js.html.CSSStyleDeclaration has no field "$property"', Macros.getEFieldPosition(f.expr.pos, e.pos));
						readOnly = access.vacc != AccNormal;
					} else { // Attr
						access = {
							ctype: ct_str,
							vacc: AccNormal,
						}
						readOnly = false;
					}
					bindings.set(f.field, new FieldInfos(assoc, type, property, access.ctype, readOnly, keepCSS, isCustom));

				case ECall(e, params):
					switch(e.expr) {
					case EConst(CIdent("$")):
						var assoc = this.getDOMAttr(params[0]);
						inline function isKeepCSS(n) return assoc.css != null && params.length > n && Macros.exprBool(params[n]);
						bindings.set(f.field, new FieldInfos(assoc, Elem, null, assoc.ctype, true, isKeepCSS(1), false));
					case _:
						Macros.fatalError('Unsupported EField: ' + f.expr.toString(), f.expr.pos);
					}

				case EArray({expr: EField({expr: ECall(macro $i{"$"}, query), pos: _}, "attr"), pos: _}, macro $v{(attribute:String)}):
					// $(selector).attr["ATTRIBUTE"]
					var assoc = this.getDOMAttr(query[0]);
					var keepCSS = assoc.css != null && query.length >= 2 && Macros.exprBool(query[1]);
					bindings.set(f.field, new FieldInfos(assoc, Attr, attribute, ct_str, false, keepCSS, false));

				default:
					Macros.fatalError('Unsupported argument', f.expr.pos);
				}
			}
		default:
			Macros.fatalError('Unsupported type for "defs"', defs.pos);
		}
	}

	public function parseXML():Expr {
		return parseXMLInner(this.top);
	}

	function HXXVaribles(s:String, pos:Position, twin:Bool): Expr {
		var ret = {expr: EConst(CString(s)), pos: pos};
		if (!isHXX)
			return ret;
		var wchar = twin ? 2 : 1;
		var yet = twin;
		var col = [];
		var i = 0;
		var len = s.length;
		var start = 0;
		var state = BEGIN;
		while (i < len) {
			var c = StringTools.fastCodeAt(s, i++);
			switch(state) {
			case BEGIN: // BEGIN
				if (c == "{".code) {
					if (yet) {
						yet = false;
					} else {
						if (i > start + wchar) {
							var sub = s.substr(start, i - wchar - start);
							col.push({expr: EConst(CString(sub)), pos: pos});
						}
						start = i;
						state = BRACE_START;
						yet = twin; // reset for next
					}
				}
			case BRACE_START:
				if (c == "}".code) {
					if (yet) {
						yet = false;
					} else {
						if (i > start + wchar) {
							var sub = StringTools.trim( s.substr(start, i - wchar - start) );
							if (sub != "")
								col.push( Context.parse(sub, pos) );
						}
						start = i;
						state = BEGIN;
						yet = twin; // reset for next
					}
				}
			}
		}
		if (state == BRACE_START)
			Macros.fatalError("Expected }", pos);
		if (i > start) {
			var sub = s.substr(start, i - start);
			col.push({expr: EConst(CString(sub)), pos: pos});
		}
		if (col.length == 1) {
			ret = col[0];
		} else if (col.length > 1) {
			var prev = col.shift();
			ret = Lambda.fold(col, (item,prev)->{expr : EBinop(OpAdd, prev, item), pos : item.pos}, prev);
		}
		return ret;
	}

	function parseXMLInner(xml: csss.xml.Xml):Expr {
		var attr = new Array<ObjectField>();
		var a = @:privateAccess xml.attributeMap; // [(attr, value), ...]
		var i = 0;
		while (i < a.length) {
			var name  = a[i];
			var value = a[i + 1];
			var spos = offsetPosition(xml.attrPos(name), name.length);
			attr.push({field: name, expr: HXXVaribles(value, spos, false)});
			i += 2;
		}
		var children = @:privateAccess xml.children;
		var len = children.length;
		var exprs = [];
		var i = 0;
		while (i < len) {
			var child = children[i];
			if (child.nodeType == Element) {
				exprs.push( parseXMLInner(child) );
			} else if (child.nodeType == PCData) {
				var text = child.nodeValue;
				if (text != "") {
					var spos = offsetPosition(child.nodePos , text.length);
					exprs.push( HXXVaribles(text, spos, true) );
				}
			} else {
				Macros.fatalError("Don't put **Comment, CDATA or ProcessingInstruction** in the Qurying Path.", this.childXMLPosition(child) );
			}
			++i;
		}
		var pos = offsetPosition(xml.nodePos, xml.nodeName.length);
		var exprArgs = [macro $v{ xml.nodeName }];
		if ( attr.length > 0 ) {
			exprArgs.push( {expr: EObjectDecl(attr), pos: pos} );
		} else if (exprs.length > 0) {
			exprArgs.push( macro null );
		}
		if (exprs.length > 0) {
			exprArgs.push( len == 1 && children[0].nodeType == PCData ? exprs[0] : macro $a{exprs} );
		}
		this.count++;
		return macro @:pos(pos) nvd.Dt.make( $a{exprArgs} );
	}

	// make sure to call tagToCtype(tagName, tyype, true) before this
	function getPropertyAccess(tagName:String, property:String): FieldAccess {
		var map = this.isSVG ? svg_access_pool.get(tagName) : html_access_pool.get(tagName.toUpperCase());
		if (map != null) {
			var ret = map.get(property);
			if (ret != null) return ret;
		}
		return dom_property_access.get(property);
	}

	function getPath(xml: Xml): Array<Int> {
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
					Macros.fatalError("Don't put **Comment, CDATA or ProcessingInstruction** in the Query Path.", childXMLPosition(col[i]));
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
	function pathLookup(xml: Xml, path: Array<Int>, pi: Int): Xml {
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
	function getDOMAttr(selector: Expr): DOMAttr {
		var xml: Xml = null;
		var path: Array<Int> = [];
		var css: String = null;
		switch (selector.expr) {
		case EConst(CString(s)):
			if (s == "") {
				xml = top;
			} else {
				xml = top.querySelector(s);
				if (xml == null)
					Macros.fatalError('Could not find "$s" in ${top.toSimpleString()}', selector.pos);
				css = s;
				path = getPath(xml);
			}
		case EConst(CIdent("null")):
			xml = top;
		case EArrayDecl(a):
			path = [];
			for (n in a) {
				switch (n.expr) {
				case EConst(CInt(i)): path.push(Std.parseInt(i));
				default:
					Macros.fatalError("Expected Int", n.pos);
				}
			}
			xml = pathLookup(top, path, 0);
			if (xml == null)
				Macros.fatalError('Could not find "${"[" + path.join(",") + "]"}" in ${top.toSimpleString()}', selector.pos);
		default:
			Macros.fatalError("Unsupported type", selector.pos);
		}
		// Note: this method will be extract all ComplexType of the field to "html_access_pool"
		var ctype = tagToCtype(xml.nodeName, this.isSVG, true);
		return {xml: xml, ctype: ctype, path: path, pos: selector.pos, css: css};
	}
	/////////////////// statics
	// complexType
	static var ct_str = macro :String;
	@:persistent static var ct_maps:Map<String, ComplexType>;                        // collections of complexType by tagname

	@:persistent static var html_tags: haxe.DynamicAccess<String>;                   // does not contain SVG elements.
	@:persistent static var html_access_pool: Map<String, Map<String, FieldAccess>>; // html tagName => [dom_property_access]
	@:persistent static var dom_property_access: Map<String, FieldAccess>;           // property_name => FieldAccess
	@:persistent static var custom_props_access: Map<String, FieldAccess>;           // custom properties ony for HTML Element
	@:persistent static var style_access: Map<String, FieldAccess>;                  // css => FieldAccess

	@:persistent static var svg_tags: haxe.DynamicAccess<String>;
	@:persistent static var svg_access_pool: Map<String, Map<String, FieldAccess>>;  // svg tagName => [dom_property_access]

	static function init() {
		if (html_access_pool != null) return;

		ct_maps = new Map();

		html_access_pool = new Map();
		svg_access_pool = new Map();

		custom_props_access = new Map();
		custom_props_access.set("text", { ctype: ct_str, vacc: AccNormal });
		custom_props_access.set("html", { ctype: ct_str, vacc: AccNormal });

		dom_property_access = new Map();
		extractFVar(dom_property_access, Context.getType("js.html.DOMElement"), "js.html.EventTarget");

		style_access = new Map();
		extractFVar(style_access, Context.getType("js.html.CSSStyleDeclaration"), "");

		// All commented items could be (tagName + "Element")
		html_tags = {
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
		}

		svg_tags = {
			//"a"                   : "AElement",
			//"animate"             : "AnimateElement",
			//"animateMotion"       : "AnimateMotionElement",
			//"animateTransform"    : "AnimateTransformElement",
			//"circle"              : "CircleElement",
			//"clipPath"            : "ClipPathElement",
			//"defs"                : "DefsElement",
			//"desc"                : "DescElement",
			//"ellipse"             : "EllipseElement",
			//"feBlend"             : "FEBlendElement",
			//"feColorMatrix"       : "FEColorMatrixElement",
			//"feComponentTransfer" : "FEComponentTransferElement",
			//"feComposite"         : "FECompositeElement",
			//"feConvolveMatrix"    : "FEConvolveMatrixElement",
			//"feDiffuseLighting"   : "FEDiffuseLightingElement",
			//"feDisplacementMap"   : "FEDisplacementMapElement",
			//"feDistantLight"      : "FEDistantLightElement",
			//"feDropShadow"        : "FEDropShadowElement",
			//"feFlood"             : "FEFloodElement",
			//"feFuncA"             : "FEFuncAElement",
			//"feFuncB"             : "FEFuncBElement",
			//"feFuncG"             : "FEFuncGElement",
			//"feFuncR"             : "FEFuncRElement",
			//"feGaussianBlur"      : "FEGaussianBlurElement",
			//"feImage"             : "FEImageElement",
			//"feMerge"             : "FEMergeElement",
			//"feMergeNode"         : "FEMergeNodeElement",
			//"feMorphology"        : "FEMorphologyElement",
			//"feOffset"            : "FEOffsetElement",
			//"fePointLight"        : "FEPointLightElement",
			//"feSpotLight"         : "FESpotLightElement",
			//"feTile"              : "FETileElement",
			//"feTurbulence"        : "FETurbulenceElement",
			//"filter"              : "FilterElement",
			//"foreignObject"       : "ForeignObjectElement",
			//"g"                   : "GElement",
			//"image"               : "ImageElement",
			//"linearGradient"      : "LinearGradientElement",
			//"line"                : "LineElement",
			//"marker"              : "MarkerElement",
			//"mask"                : "MaskElement",
			//"metadata"            : "MetadataElement",
			//"mpath"               : "MPathElement",
			//"path"                : "PathElement",
			//"pattern"             : "PatternElement",
			//"polygon"             : "PolygonElement",
			//"polyline"            : "PolylineElement",
			//"radialGradient"      : "RadialGradientElement",
			//"rect"                : "RectElement",
			//"script"              : "ScriptElement",
			//"set"                 : "SetElement",
			//"stop"                : "StopElement",
			//"style"               : "StyleElement",
			"svg"                 : "SVGElement",
			//"switch"              : "SwitchElement",
			//"symbol"              : "SymbolElement",
			//"text"                : "TextElement",
			//"textPath"            : "TextPathElement",
			//"title"               : "TitleElement",
			"tspan"               : "TSpanElement",
			//"use"                 : "UseElement",
			//"view"                : "ViewElement",
		}
	}

	static public function checkIsSVG(node: csss.xml.Xml):Bool {
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

	static function cachedCType(t: Type): ComplexType {
		var ret: ComplexType = null;
		var name = switch (t) {
		case TInst(r, _):
			r.toString();
		case TAbstract(r, _):
			r.toString(); // follow(Abstract)??
		default:
			null;
		}
		var ret: ComplexType = name == null ? null : ct_maps.get(name);
		if (ret == null) {
			ret = t.toComplexType();
			if (name != null) ct_maps.set(name, ret);
		}
		return ret;
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
						out.set(f.name, { ctype: cachedCType(f.type), vacc: w });
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
			Macros.fatalError("Unsupported type", (macro {}).pos);
		}
	}

	// Note: make sure that tagname is uppercase if svg is false
	static function tagToModule(tagname: String, svg: Bool): String {
		if (svg) {
			var type = svg_tags.get(tagname);  // keep the original case
			if (type == null) {
				if (StringTools.startsWith(tagname, "fe")) {
					type = "FE" + tagname.substr(2) + "Element";
				} else {
					type = tagname.charAt(0).toUpperCase() + tagname.substr(1) + "Element";
				}
				svg_tags.set(tagname, type);
			}
			return "js.html." + "svg." + type;
		} else {
			var type = html_tags.get(tagname);
			if (type == null) {
				type = tagname.charAt(0) + tagname.substr(1).toLowerCase() + "Element";
				html_tags.set(tagname, type);
			}
			return "js.html." + type;
		}
	}

	static public function tagToCtype(tagname: String, svg:Bool, extract:Bool): ComplexType {
		if (!svg) tagname = tagname.toUpperCase();
		var mod = tagToModule(tagname, svg);
		var ct = ct_maps.get(mod);
		if (ct == null) {
			var type = try Context.getType(mod) catch(e:Dynamic){ Context.getType("js.html.DOMElement"); }
			if (extract) {
				var pool = svg ? svg_access_pool : html_access_pool;
				var fc = pool.get(tagname);
				if (fc == null) {
					fc = new Map();
					extractFVar(fc, type);
					pool.set(tagname, fc);
				}
			}
			ct = type.toComplexType();
			ct_maps.set(mod, ct);
		}
		return ct;
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
		default:
		}
		return pass;
	}

	static function __init__() {
		init();
	}
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

	static inline var ERR_PREFIX = "[no-vdom]: ";

	static public inline function fatalError(msg, pos):Dynamic return Context.fatalError(ERR_PREFIX + msg, pos);

	static function make(comp: XMLComponent, defs: Expr): Array<Field> {
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

		comp.parseDefs(defs);

		if (!allFields.exists("_new")) { // abstract class constructor
			var ct_dom = macro :js.html.DOMElement;
			fields.push({
				name: "new",
				access: [APublic, AInline],
				pos: pos,
				kind: FFun({
					args: [{name: "d", type: ct_dom}],
					ret: null,
					expr: macro this = cast (d: $ct_dom), // type checking and casting
				})
			});
		}
		var topCType =  comp.getCType(comp.top.nodeName);
		fields.push({
			name: "d",
			access: [APublic],
			pos: pos,
			kind: FProp("get", "never", topCType)
		});
		fields.push({
			name: "get_d",
			access: [AInline, APrivate],
			pos: pos,
			meta: [{name: ":to", pos: pos}],
			kind: FFun({
				args: [],
				ret: topCType,
				expr: macro return cast this
			})
		});
		if (!allFields.exists("ofSelector")) {
			fields.push({
				name: "ofSelector",
				access: [APublic, AInline, AStatic],
				pos: pos,
				kind: FFun({
					args: [{name: "s", type: macro :String}],
					ret: TPath(cls_path),
					expr: macro return js.Syntax.code("document.querySelector({0})", s)
				})
			});
		}
		if (!comp.isSVG && !allFields.exists("create")) {
			var ecreate = comp.parseXML();
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

		for (k in comp.bindings.keys()) {
			var item = comp.bindings.get(k);
			var aname = item.name;
			var edom  = if (item.keepCSS && item.assoc.css != null && item.assoc.css != "") {
				macro cast d.querySelector($v{item.assoc.css});
			} else {
				item.assoc.path.length < 6
				? exprChildren(item.assoc.path, item.assoc.pos)
				: macro @:privateAccess cast this.lookup( $v{ item.assoc.path } );
			}
			var edom = {  // same as: (cast this.lookup(): SomeElement)
				expr: ECheckType(edom, item.assoc.ctype),
				pos : edom.pos
			};
			fields.push({
				name: k,
				access: [APublic],
				kind: FProp("get", (item.readOnly ? "never": "set"), item.ctype),
				pos: item.assoc.pos,
			});

			fields.push({   // getter
				name: "get_" + k,
				access: [APrivate, AInline],
				kind: FFun( {
					args: [],
					ret: item.ctype,
					expr: switch (item.type) {
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
				pos: item.assoc.pos,
			});

			if (!item.readOnly) {
				fields.push({
					name: "set_" + k,
					access: [APrivate, AInline],
					kind: FFun({
						args: [{name: "v", type: item.ctype}],
						ret: item.ctype,
						expr: switch (item.type) {
						case Attr: macro return nvd.Dt.setAttr($edom, $v{ aname }, v);
						case Prop:
							var expr = macro return $edom.$aname = v;
							if (item.isCustom) {
								switch (aname) {
								case "text": macro return nvd.Dt.setText($edom, v);
								case "html": macro return $edom.innerHTML = v;
								default: expr;
								}
							} else {
								expr;
							}
						case Style: macro return $edom.style.$aname = v;
						default: throw "ERROR";
						}
					}),
					pos: item.assoc.pos,
				});
			}
		}

		if (comp.posOffset == 0) {// from Nvd.build
			Context.registerModuleDependency(cls.module, comp.path);
		}
		return fields;
	}

	// [1,0,3] => this.children[1].children[0].children[3]
	static function exprChildren(a: Array<Int>, pos) {
		var thiz = macro @:pos(pos) cast this;
		return a.length > 0
		? Lambda.fold(a, (item, prev)-> macro @:pos(pos) (cast $prev).children[$v{item}], thiz)
		: thiz;
	}

	static function exprString(e: Expr): String {
		return switch (e.expr) {
		case EConst(CString(s)):
			s;
		case EBinop(OpAdd, e1, e2):
			exprString(e1) + exprString(e2);
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

	// if a.b.c then get c.position
	static function getEFieldPosition(full, left) {
		var pos = PositionTools.getInfos(full);
		pos.min = PositionTools.getInfos(left).max + 1; // ".".length == 1;
		return PositionTools.make(pos);
	}

}
#else
extern class Macros{}
#end