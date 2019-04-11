package;

#if macro
import haxe.macro.Expr;
import haxe.macro.Context;
import haxe.macro.PositionTools;
import nvd.Macros.exprString;
import nvd.Macros.CachedXMLFile;
#end

class Nvd {
	/*
	 used for create Tag/Element

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
			nvd.Macros.fatalError('Invalid selector or Could not find: "$selector" in $path', exprSelector.pos);
		var ctype = nvd.Macros.tagToCtype(node.nodeName, node.nodeName == "SVG", false);
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
	public static function build(efile: ExprOf<String>, selector: ExprOf<String>, ?defs, create = true) {
		var file = exprString(efile);
		var css = exprString(selector);
		var cache = CachedXMLFile.make(file, efile.pos);
		var root = csss.Query.querySelector(cache.xml, css);
		if (root == null) nvd.Macros.fatalError('Invalid selector or Could not find: "$css"', selector.pos);
		return nvd.Macros.make(root, defs, {file: file, min: 0}, create);
	}

	public static function buildString(es: ExprOf<String>, ?defs, create = true) {
		var txt = exprString(es);
		var fp = PositionTools.getInfos(es.pos);
		fp.min += 1; // the 1 width of the quotes
		var root = try {
			csss.xml.Xml.parse(txt).firstElement();
		} catch (err: csss.xml.Parser.XmlParserException) {
			fp.min += err.position;
			fp.max = fp.min + 1;
			nvd.Macros.fatalError(err.toString(), PositionTools.make(fp));
		}
		return nvd.Macros.make(root, defs, fp, create);
	}
#end
}
