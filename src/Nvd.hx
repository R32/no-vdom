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
	 used for create HTMLElement and don't use it for SVG elements

	 example:

	 ```hx
	 h("a.btn", "click here...");          => "<a class="btn">click here...</a>"

	 h("h4", [" tick: ", h("span", "1")]); => "<h4> tick: <span>1</span></h4>"

	 h("div.cls1", [
		h("label", [
			"text node: ",
			h("input[type=text][value='default value']")
		]),
		h("a[href='javascript:void(0)']#uid", "link to ...")
	 ])
	 ```
	*/
	macro public static function h(exprs: Array<Expr>) {
		var attr = {};
		var name = nvd.Macros.attrParse(exprs[0], attr);
		var exprAttr = Reflect.fields(attr).length == 0 ? macro null : macro $v{attr};
		var ret = [name, exprAttr];
		if (exprs.length > 1) {
			switch (exprs[1].expr) {
			case ExprDef.EArrayDecl(_), ExprDef.EConst(_):
				ret.push(exprs[1]); // text, or subs
			default:
				nvd.Macros.fatalError("Unsupported type", exprs[1].pos);
			}
		}
		return macro nvd.Dt.make($a{ret});
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
		var pos = PositionTools.getInfos(es.pos);
		var txt = switch (es.expr) {
			case EConst(CString(s)):
				pos.min += 1; // the 1 width of the quotes
				s;
			case EMeta({name: ":markup"}, {expr: EConst(CString(s))}):
				s;
			default:
				nvd.Macros.fatalError("Expected String", es.pos);
		}
		var top = try {
			csss.xml.Xml.parse(txt).firstElement();
		} catch (err: csss.xml.Parser.XmlParserException) {
			pos.min += err.bpos;
			pos.max = pos.min + 1;
			nvd.Macros.fatalError(err.toString(), PositionTools.make(pos));
		}
		var comp = new XMLComponent(pos.file, pos.min, top, isSVG);
		return nvd.Macros.make(comp, defs);
	}
#end
}
