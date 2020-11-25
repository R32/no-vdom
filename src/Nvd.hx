package;

#if macro
 using nvd.inner.Utils;
import nvd.inner.Tags;
import nvd.inner.CachedXML;
import nvd.inner.XMLComponent;
 using csss.Query;
import csss.xml.Xml;
import haxe.macro.Expr;
import haxe.macro.Context;
#end
class Nvd {
	/*
	Uses `{{` `}}` as variable separator.

	```hx
		var title = "hi there";
		var content = "click here";
		var fn = function(){ return "string"; }
		var div = HXX(
			<div>
				<a class="btn" title="{{ title }}"> LL {{ content }} RR </a>
				<br />
				<span title={{title}}>{{ fn() }}</span>
			</div>
		);
		document.body.appendChild(div);
	```
	*/
	macro public static function HXX( markup : Expr ) {
		var comp = XMLComponent.fromMarkup(markup, true);
		var expr = comp.parse();
		var ctype = comp.topComplexType();
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
	public static function buildQuerySelector( path : String, eCSS : ExprOf<String>) : Expr {
		var pos = Context.currentPos();
		var cha = CachedXML.get(path, pos);
		var css = eCSS.string();
		var node = cha.xml.querySelector(css);
		if (node == null)
			fatalError('Could not find: "$css" in $path', eCSS.pos);
		var ctype = Tags.ctype(node.nodeName, node.isSVG() , false);
		return macro @:pos(pos) (js.Syntax.code("document.querySelector({0})", $eCSS): $ctype);
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
	public static function build( ePath : ExprOf<String>, eCSS : ExprOf<String>, ?defs, isSVG = false ) {
		var path = ePath.string();
		var css = eCSS.string();
		var cha = CachedXML.get(path, ePath.pos);
		var top = cha.xml.querySelector(css);
		if (top == null)
			Nvd.fatalError('Could not find: "$css" in $path', eCSS.pos);
		var comp = new XMLComponent(path, 0, top, isSVG, false);
		return nvd.Macros.make(comp, defs);
	}

	public static function buildString( e : Expr, ?defs) {
		var comp = XMLComponent.fromMarkup(e, false);
		return nvd.Macros.make(comp, defs);
	}

	static inline var ERR_PREFIX = "[no-vdom]: ";

	static public function fatalError(msg, pos) : Dynamic return Context.fatalError(ERR_PREFIX + msg, pos);
#end
}
