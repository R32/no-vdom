package;

import js.Browser.document;
import js.Browser.console;
import Nvd.h;
import nvd.p.HXX;

class NvdTest {
	static function test_hxx() {
		var str = " this is a {{pen}}, it comes from {{ city || 'bei jing' }}.";
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
		eq(x[1], "pen", null);
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
	display: Style(null, "display"),
	input: Elem(".input-block"),
	value: Prop(".input-block", "value", true),
	title: Attr([1, 0], "title"),
})) abstract Foo(nvd.Comp) {
}


@:build(Nvd.build("bin/index.html", "div.template-1", {
	link:  Elem("a"),                // or Elem([1, 0]). same as ".template-1 a"
	text:  Prop("p", "text"),        // custom prop, same as ".template-1 p".(textContent | innerText)
	title: Attr("a", "title"),       // same as ".template-1 a".attribute("title")
	cls:   Prop("a", "className"),   // same as ".template-1 a".className})) abstract Bar(nvd.Comp) to nvd.Comp {
	x: Prop("", "offsetLeft"),       // same as ".template-1".offsetLeft}
	y: Prop([], "offsetTop"),        // same as ".template-1".offsetTop}
	text_node: Prop("a", "previousSibling"),
})) abstract Bar(nvd.Comp) {
}

@:build(Nvd.buildString('<div class="hehe hahs"><label> some thing <input type="text" value="no work!" /></label><span></span></div>', {
	value: Prop("input", "value")
})) abstract Tee(nvd.Comp) {
}