package;

#if macro
import haxe.macro.Expr;
import haxe.macro.Context;
import haxe.macro.PositionTools;
import nvd.Macros.exprString as string;
import nvd.Macros.files;
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
				Context.fatalError("Unsupported type", exprs[1].pos);
			}
		}
		return macro nvd.Dt.make($a{ret});
	}

	@:persistent static var currentXML: csss.xml.Xml;

	macro public static function SELECT(file: ExprOf<String>) {
		var sfile = string(file);
		var xml = files.get(sfile);
		if (xml == null) {
			xml = readFile(sfile, file.pos);
			files.set(sfile, xml);
		}
		currentXML = xml;
		return macro @:pos(file.pos){}
	}
	macro public static function Q(selector:ExprOf<String>):Expr {
		var pos = Context.currentPos();
		if (currentXML == null)
			Context.fatalError( "No XML/HXML files currently selected", pos);
		var node = csss.Query.one(currentXML, string(selector));
		if (node == null)
			Context.error('Invalid selector or Could not find: "${ string(selector )}"', selector.pos);
		var ctype = nvd.Macros.tagToCtype(node.nodeName, node.nodeName == "SVG", false);
		return macro @:pos(pos) (cast js.Browser.document.querySelector($selector): $ctype);
	}

#if macro
	/*
	example:
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
	public static function build(efile: ExprOf<String>, selector: ExprOf<String>, ?defs, create = true) {
		var file = string(efile);
		var css = string(selector);
		var xml = files.get(file);
		if (xml == null) {
			xml = readFile(file, efile.pos);
			files.set(file, xml);
		}
		var root = csss.Query.querySelector(xml, css);
		if (root == null) Context.fatalError('Invalid selector or Could not find: "$css"', selector.pos);
		return nvd.Macros.make(root, defs, {file: file, min: 0}, create);
	}

	public static function buildString(es: ExprOf<String>, ?defs, create = true) {
		var txt = string(es);
		var fp = PositionTools.getInfos(es.pos);
		fp.min += 1; // the 1 width of the quotes
		var root = try {
			csss.xml.Xml.parse(txt).firstElement();
		} catch (err: csss.xml.Parser.XmlParserException) {
			fp.min += err.position;
			fp.max = fp.min + 1;
			Context.fatalError(err.toString(), PositionTools.make(fp));
		}
		return nvd.Macros.make(root, defs, fp, create);
	}

	static function readFile(file, pos): csss.xml.Xml {
		return try {
			 csss.xml.Xml.parse( sys.io.File.getContent(file) );
		} catch(err: csss.xml.Parser.XmlParserException) {
			Context.fatalError(err.toString(), PositionTools.make({
				file: file,
				min: err.position,
				max: err.position + 1
			}));
		} catch (err: Dynamic) {
			Context.fatalError(Std.string(err), pos);
		}
	}
#end
}
