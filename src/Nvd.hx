package;

#if macro
import haxe.macro.Expr;
import haxe.macro.Context;
#end

class Nvd {
	/**
	 example:

	 ```hx
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
			case EArrayDecl(_), EConst(_):
				ret.push(macro null);
				ret.push(exprs[1]);
			default:
				for (i in 1...exprs.length) ret.push(exprs[i]);
			}
		}
		return macro nvd.Dt.make($a{ret});
	}
#if macro
	/**
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
	    x: Prop([], "offsetLeft")        // same as ".template-1".offsetLeft
	}) abstract Temp_1(nvd.Comp) {}
	// ....
	var t1 = new Temp_1();
	t1.|
	```
	*/
	public static function build(file: String, selector: String, ?extra, create = true) {
		var root = csss.xml.Xml.parse(sys.io.File.getContent(file)).firstElement();
		var el = csss.Query.querySelector(root, selector);
		if (el == null) Context.error('Invalid selector or Could not find: "$selector"', extra.pos);
		return nvd.Macros.make(el, extra, {file: file, min: 0}, create);
	}

	public static function buildString(es: Expr, selector: String = null, ?extra, create = true) {
		var s = switch (es.expr) {
		case EConst(CString(str)): str;
		default: Context.error("XML String", es.pos);
		}
		var root = csss.xml.Xml.parse(s).firstElement();
		var el = selector == null || selector == "" ? root : csss.Query.querySelector(root, selector);
		if (el == null) Context.error('Invalid selector or Could not find: "$selector"', es.pos);
		var xpos = haxe.macro.PositionTools.getInfos(es.pos);
		xpos.min += 1;  // begein at "1"
		return nvd.Macros.make(el, extra, xpos, create);
	}
#end
}
