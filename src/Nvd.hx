package;

#if macro
import haxe.macro.Expr;
import haxe.macro.Context;
import haxe.macro.PositionTools;
import nvd.Macros.exprString;
import nvd.Macros.CachedXMLFile;
import nvd.Macros.XMLComponent;
#end

class Nvd {
	/*
	simple HXX.

	Uses `{code}` in attribute-value, no spaces are allowed if there are no quotes.

	Uses `{{code}}` in textContent

	```hx
		var title = "hi there";
		var content = "click here";
		var fn = function(){ return "string"; }
		var div = HXX(
			<div>
				<a class="btn" title="{ title }"> LL {{ content }} RR </a>
				<br />
				<span title={title}>{{ fn() }}</span>
			</div>
		);
		document.body.appendChild(div);
	```
	*/
	macro public static function HXX(markup: Expr) {
		var comp = parseMarkup(markup, false);
		comp.isHXX = true;
		var expr = comp.parseXML();
		var ctype = comp.getCType(comp.top.nodeName);
		return macro @:pos(markup.pos) (cast $expr: $ctype);
	}
#if macro
	/**
	since you can't build "macro function" from macro, So you need to write it manually:

	```hx
	// Note: This method should be placed in "non-js" class
	macro public static function one(selector) {
		return Nvd.buildQuerySelector("bin/index.html", selector);
	}
	```
	*/
	public static function buildQuerySelector(path: String, exprSelector: ExprOf<String>): Expr {
		var pos = Context.currentPos();
		var cache = CachedXMLFile.make(path, pos);
		var selector = exprString(exprSelector);
		var node = csss.Query.one(cache.xml, selector);
		if (node == null)
			nvd.Macros.fatalError('Could not find: "$selector" in $path', exprSelector.pos);
		var ctype = XMLComponent.tagToCtype(node.nodeName, XMLComponent.checkIsSVG(node) , false);
		return macro @:pos(pos) (js.Syntax.code("document.querySelector({0})", $exprSelector): $ctype);
	}

	/*
	example:
	```hx
	Nvd.build("file/to/index.html", ".template-1", {
	    link:    $("a"),
	    text:    $("p").textContent,
	    title:   $("a").title,
	    cls:     $("a").className,
	    x:       $(null).style.offsetLeft
	    display: $(null).display
	}) abstract Foo(nvd.Comp) {}
	// ....
	var foo = new Foo();
	foo.|
	```
	*/
	public static function build(efile: ExprOf<String>, selector: ExprOf<String>, ?defs, isSVG = false) {
		var file = exprString(efile);
		var css = exprString(selector);
		var cache = CachedXMLFile.make(file, efile.pos);
		var top = csss.Query.querySelector(cache.xml, css);
		if (top == null) nvd.Macros.fatalError('Could not find: "$css" in $file', selector.pos);
		var comp = new XMLComponent(file, 0, top, isSVG);
		return nvd.Macros.make(comp, defs);
	}

	public static function buildString(es: ExprOf<String>, ?defs, isSVG = false) {
		return nvd.Macros.make(parseMarkup(es, isSVG), defs);
	}

	static function parseMarkup(markup: Expr, isSVG: Bool): XMLComponent {
		var pos = PositionTools.getInfos(markup.pos);
		var txt = switch (markup.expr) {
			case EConst(CString(s)):
				pos.min += 1; // the 1 width of the quotes
				s;
			case EMeta({name: ":markup"}, {expr: EConst(CString(s))}):
				s;
			default:
				nvd.Macros.fatalError("Expected String", markup.pos);
		}
		var top = try {
			csss.xml.Xml.parse(txt).firstElement();
		} catch (err: csss.xml.Parser.XmlParserException) {
			pos.min += err.position;
			pos.max = pos.min + 1;
			nvd.Macros.fatalError(err.toString(), PositionTools.make(pos));
		}
		return new XMLComponent(pos.file, pos.min, top, isSVG);
	}
#end
}
