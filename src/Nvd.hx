package;

#if macro
import haxe.macro.Expr;
import haxe.macro.Context;
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
				Context.error("Unsupported type", exprs[1].pos);
			}
		}
		return macro nvd.Dt.make($a{ret});
	}

	/**
	 for create TextNode.
	*/
	macro public static function text(text: ExprOf<String>) {
		return macro js.Browser.document.createTextNode($text);
	}

#if macro
	/*
	example:

	```xml
	<div class="template-1">              <!-- epath: [] -->
	  <p>Lorem ipsum dolor sit</p>           <!-- epath: [0] -->
	  <p>                                    <!-- epath: [1] -->
	    amet consectetuer                      <!-- epath: None   -->
	    <a href="#" title="Greeting">hi</a>    <!-- epath: [1, 0] -->
	  </p>
	</div>
	 ```

	```hx
	Nvd.build("file/to/index.html", ".template-1", {
	    link:  Elem("a"),                // or Elem([1, 0]). same as CSS(".template-1 a")
	    text:  Prop("p", "textContent"), // same as CSS(".template-1 p").textContent
	    title: Attr("a", "title"),       // same as CSS(".template-1 a").attribute("title")
	    cls:   Prop("a", "className"),   // same as CSS(".template-1 a").className
	    x: Prop(null, "offsetLeft")      // same as CSS(".template-1").offsetLeft
	    display: Style(null, "display")  // same as CSS(".template-1").style.display
	}) abstract Foo(nvd.Comp) {}
	// ....
	var foo = new Foo();
	foo.|
	```
	*/
	public static function build(file: String, selector: ExprOf<String>, ?defs, create = true) {
		var css = nvd.Macros.exprString(selector);
		var xml = nvd.Macros.files.get(file);
		if (xml == null) {
			xml = csss.xml.Xml.parse(sys.io.File.getContent(file)).firstElement();
			nvd.Macros.files.set(file, xml);
		}
		var root = csss.Query.querySelector(xml, css);
		if (root == null) Context.error('Invalid selector or Could not find: "$css"', selector.pos);
		return nvd.Macros.make(root, defs, {file: file, min: 0}, create);
	}

	public static function buildString(es: haxe.macro.Expr, ?selector: ExprOf<String>, ?defs, create = true) {
		var txt = nvd.Macros.exprString(es);
		var xml;
		try {
			xml = csss.xml.Xml.parse(txt).firstElement();
		} catch(err: Dynamic) {
			Context.error("Invalid Xml String", es.pos);
		}
		var css = null;
		switch (selector.expr) {
		case EConst(CIdent("null")), EConst(CString("")):
		case EConst(CString(s)): css = s;
		default: Context.error("[macro build]: Expected String", selector.pos);
		}
		var root = css == null ? xml : csss.Query.querySelector(xml, css);
		if (root == null) Context.error('Invalid selector or Could not find: "$css"', selector.pos);
		var fp = haxe.macro.PositionTools.getInfos(es.pos);
		return nvd.Macros.make(root, defs, fp, create);
	}
#end
}
