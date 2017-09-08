package;

class Nvd {
	macro public static function h(exprs: Array<haxe.macro.Expr>) {
		var vattr = {};
		var name = nvd.Macros.attrParse(exprs[0], vattr);
		var attr = Reflect.fields(vattr).length == 0 ? macro null : macro $v{ vattr };
		var ret = [name, attr];
		for (i in 1...exprs.length) ret.push(exprs[i]);
		return macro nvd.Dt.make($a{ret});
	}
#if macro
	/**
	example:

	```xml
	<div class="template-1">               <!-- epath: [] -->
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
	    x: Prop([], "offsetLeft")        // same as ".template-1".offsetLeft
	}) abstract Temp_1(nvd.Comp) {}
	// ....
	var t1 = new Temp_1();
	t1.|
	```
	*/
	public static function build(file: String, selector: String, ?extra) {
		var root = csss.xml.Xml.parse(sys.io.File.getContent(file)).firstElement();
		var el = csss.Query.querySelector(root, selector);
		if (el == null) haxe.macro.Context.error('Invalid selector or Could not find: "$selector"', extra.pos);
		return nvd.Macros.make(el, extra, file);
	}

	public static function buildString(s: String, selector: String = null, ?extra) {
		var root = csss.xml.Xml.parse(s).firstElement();
		var el = selector == null ? root : csss.Query.querySelector(root, selector);
		if (el == null) haxe.macro.Context.error('Invalid selector or Could not find: "$selector"', extra.pos);
		return nvd.Macros.make(el, extra, null);
	}
#end
}
