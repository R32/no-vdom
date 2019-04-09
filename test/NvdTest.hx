package;

import js.Browser.document;
import js.Browser.console;
import Nvd.h;
import nvd.p.HXX;
import NvdQuery.one;

class NvdTest {
	static function test_hxx() {
		var str = " this is a {{apply}}, it comes from {{ city || 'bei jing' }}.";
		var x = HXX.parse(str, 0);
		function eq(v, str:String, ?opt: String, ?pos: haxe.PosInfos) {
			var r = false;
			switch (v) {
			case Variable(a, d):
				r = a == str && d == opt;
			case Text(s):
				r = s == str;
			}
			if (r == false) throw new js.Error("haxe line: " + pos.lineNumber);
		}
		eq(x[0], " this is a ");
		eq(x[1], "apply", null);
		eq(x[2], ", it comes from ");
		eq(x[3], "city", "bei jing");
		eq(x[4], ".");
		var str = " other {{ some {{ one }} xxxx {{ two || hehehe }}   ";
		var x = HXX.parse(str);
		eq(x[0], " other {{ some ");
		eq(x[1], "one", null);
		eq(x[2], " xxxx ");
		eq(x[3], "two", "hehehe");
		trace("HXX is done!");
	}
	static function main() {
		test_hxx();
		one("div");
		var d1 = h("div.red.some", [

			h("label", [
				"text node: ",
				h("input[type=text][value='default value']")
			]),

			h("br"),

			h("a[href= 'javascript: void(0)'][title = haha][class='hehe']", "link 1"),

			h("br"),

			h("span[title='span span span'][href='#']#hehe.aaa.d-c", "span 2"),

			h("br"),

			h("a[href='#']", "link 3"),

			h("ol.hehe", [
				h("li", "1"),
				h("li", "2"),
				h("li", "3"),
				h("li", "4"),
				h("li", "5"),
			])
		]);


		var d2 = h("input", "input test");

		var d3 = h("input[type=button].btn", "click");

		document.body.appendChild(d1);
		document.body.appendChild(d2);
		document.body.appendChild(d3);

		var foo = new Foo(document.querySelector("div.flex-table"));
		trace(foo.value);
		trace(foo.title);
		foo.value = "a b c";
		foo.title = "Greeting";

		var bar: Bar = Bar.ofSelector("div.template-1");
		trace(bar.x);
		trace(bar.y);
		trace(bar.text);
		trace(bar.text_node.nodeValue);

		var tee = Tee.create();
		document.body.appendChild(tee);
		document.body.appendChild(Bar.create());
	}
}

@:build(Nvd.build("bin/index.html", "div.flex-table", {
	display: $(null).style.display,
	input:   $(".input-block"),
	value:   $(".input-block", true).value,
	title:   $([1, 0]).attr.title,       // or .attr["title"]
})) abstract Foo(nvd.Comp) {
}

@:build(Nvd.build("bin/index.html", "div.template-1", {
	link:    $("a"),
	text:    $("p").text,
	title:   $("a").attr.title,
	cls:     $("a").className,
	x:       $(null).offsetLeft,
	y:       $(null).offsetTop,
	text_node: $("a").previousSibling,
})) abstract Bar(nvd.Comp) {
}

@:build(Nvd.buildString(
'<div class="hehe haha">
	<label> some thing <input type="text" value="no work!" /></label>
	<span></span>
</div>', {
	value:   $("input").value
})) abstract Tee(nvd.Comp) {
}
