package;

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
	macro public static function h(exprs: Array<haxe.macro.Expr>) {
		var vattr = {};
		var name = nvd.Macros.attrParse(exprs[0], vattr);
		var attr = Reflect.fields(vattr).length == 0 ? macro null : macro $v{ vattr };
		var ret = [name, attr];
		if (exprs.length > 1) {
			switch (exprs[1].expr) {
			case haxe.macro.Expr.ExprDef.EArrayDecl(_), haxe.macro.Expr.ExprDef.EConst(_):
				ret.push(macro null);
				ret.push(exprs[1]);
			default:
				for (i in 1...exprs.length) ret.push(exprs[i]);
			}
		}
		return macro nvd.Dt.make($a{ret});
	}

	/**
	 for create TextNode.
	*/
	macro public static function text(text: haxe.macro.Expr.ExprOf<String>) {
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
	    link:  Elem("a"),                // or Elem([1, 0]). same as ".template-1 a"
	    text:  Prop("p", "textContent"), // same as ".template-1 p".textContent
	    title: Attr("a", "title"),       // same as ".template-1 a".attribute("title")
	    cls:   Prop("a", "className"),   // same as ".template-1 a".className
	    x: Prop(null, "offsetLeft")      // same as ".template-1".offsetLeft
	    display: Style(null, "display")  // same as ".template-1".style.display
	}) abstract Foo(nvd.Comp) {}
	// ....
	var foo = new Foo();
	foo.|
	```
	*/
	public static function build(file: String, selector: String, ?extra, create = true) {
		if (!nvd.Macros.files.exists(file))
			nvd.Macros.files.set(file, csss.xml.Xml.parse(sys.io.File.getContent(file)).firstElement());
		var root = nvd.Macros.files.get(file);
		var el = csss.Query.querySelector(root, selector);
		if (el == null) haxe.macro.Context.error('Invalid selector or Could not find: "$selector"', extra.pos);
		return nvd.Macros.make(el, extra, {file: file, min: 0}, create);
	}

	public static function buildString(es: haxe.macro.Expr, selector: String = null, ?extra, create = true) {
		var s = nvd.Macros.exprString(es);
		var root;
		try {
			root = csss.xml.Xml.parse(s).firstElement();
		} catch(err: Dynamic) {
			haxe.macro.Context.error("Invalid Xml String", es.pos);
		}
		var el = selector == null || selector == "" ? root : csss.Query.querySelector(root, selector);
		if (el == null) haxe.macro.Context.error('Invalid selector or Could not find: "$selector"', es.pos);
		var xpos = haxe.macro.PositionTools.getInfos(es.pos);
		xpos.min += 1;  // begin at "1"
		return nvd.Macros.make(el, extra, xpos, create);
	}
#end
}
