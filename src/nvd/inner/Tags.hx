package nvd.inner;

import haxe.macro.Expr;
import haxe.macro.Type;
import haxe.macro.Context;
 using haxe.macro.Tools;
 using StringTools;

@:structInit
class FCTAccess {
	public var ctype(default, null) : ComplexType;
	public var vacc(default, null) : VarAccess;
	public function new(ctype, vacc) {
		this.ctype = ctype;
		this.vacc = vacc;
	}
}

class Tags {

	@:persistent static var ct_maps          : Map<String,ComplexType>;            // tagname => complexType
	@:persistent static var dom_field_access : Map<String,FCTAccess>;              // default field name => FCTAccess
	@:persistent static var style_access     : Map<String,FCTAccess>;              // css name => FCTAccess

	@:persistent static var htmls            : haxe.DynamicAccess<String>;         // html tagname => moudle name
	@:persistent static var svgs             : haxe.DynamicAccess<String>;         //  svg tagname => moudle name
	@:persistent static var html_access_pool : Map<String, Map<String,FCTAccess>>; // html tagName => [dom_field_access]
	@:persistent static var  svg_access_pool : Map<String, Map<String,FCTAccess>>; //  svg tagName => [dom_field_access]

	public static function access( tagName : String, property : String, isSVG : Bool ) : FCTAccess {
		var map = isSVG ? svg_access_pool.get(tagName) : html_access_pool.get(tagName.toUpperCase());
		if (map != null) {
			var ret = map.get(property);
			if (ret != null)
				return ret;
		}
		return dom_field_access.get(property);
	}

	public static function ctype( name : String, svg : Bool, access : Bool ) : ComplexType {
		if (!svg) name = name.toUpperCase();
		var mod = toModule(name, svg);
		var ct = ct_maps.get(mod);
		if (ct == null) {
			var type = try Context.getType(mod) catch(e) Context.getType("js.html.DOMElement");
			if (access) {
				var pool = svg ? svg_access_pool : html_access_pool;
				var fc = pool.get(name);
				if (fc == null) {
					fc = new Map();
					loadFVar(fc, type);
					pool.set(name, fc);
				}
			}
			ct = type.toComplexType();
			ct_maps.set(mod, ct);
		}
		return ct;
	}

	public static function toModule( name : String, isSVG : Bool ) : String {
		if (isSVG) {
			var type = svgs.get(name);  // keep the original case
			if (type == null) {
				if (name.startsWith("fe")) {
					type = "FE" + name.substr(2) + "Element";
				} else {
					type = name.charAt(0).toUpperCase() + name.substr(1) + "Element";
				}
				svgs.set(name, type);
			}
			return "js.html." + "svg." + type;
		} else {
			var type = htmls.get(name);
			if (type == null) {
				type = name.charAt(0) + name.substr(1).toLowerCase() + "Element";
				htmls.set(name, type);
			}
			return "js.html." + type;
		}
	}

	static function loadFVar( out : Map<String, FCTAccess>, type : Type, stop = "js.html.Element" ) : Void {
		switch (type) {
		case TInst(r, _):
			var c: ClassType = r.get();
			while (true) {
				if (c.module == stop || c.module.substr(0, 7) != "js.html")
					break;
				var fs = c.fields.get();
				for (f in fs) {
					switch (f.kind) {
					case FVar(_, w):
						out.set(f.name, { ctype: typect(f.type), vacc: w });
					default:
					}
				}
				if (stop == "" || c.superClass == null)
					break;
				c = c.superClass.t.get();
			}
		default:
			Nvd.fatalError("Unsupported type", (macro {}).pos);
		}
	}

	static function typect( t : Type ) : ComplexType {
		var name = switch (t) {
		case TInst(r, _):
			r.toString();
		case TAbstract(r, _):
			r.toString(); // ??do follow(Abstract)
		default:
			null;
		}
		var ct: ComplexType = name == null ? null : ct_maps.get(name);
		if (ct == null) {
			ct = t.toComplexType();
			if (name != null)
				ct_maps.set(name, ct);
		}
		return ct;
	}

	static function __init__() {
		init();
	}

	static function init() {
		if (html_access_pool != null) return;

		ct_maps = new Map();
		html_access_pool = new Map();
		svg_access_pool = new Map();

		dom_field_access = new Map();
		loadFVar(dom_field_access, Context.getType("js.html.DOMElement"), "js.html.EventTarget");

		style_access = new Map();
		loadFVar(style_access, Context.getType("js.html.CSSStyleDeclaration"), "");

		// All commented items could be (tagName + "Element")
		htmls = {
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

		svgs = {
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
}