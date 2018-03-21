package test;

import js.Browser.document;
import js.Browser.console;
import Nvd.h;

class NvdTest {
	static function main() {
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
		console.log(foo.input);
		console.log(foo.value);
		console.log(foo.title);
		foo.value = "a b c";
		foo.title = "Greeting";

		var bar: Bar = Bar.ofSelector("div.template-1");
		console.log(bar.x);
		console.log(bar.y);
		console.log(bar.text);

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
})) abstract Bar(nvd.Comp) {
}

@:build(Nvd.buildString('<div class="hehe hahs"><label> some thing <input type="text" value="no work!" /></label></div>', null, {
	value: Prop("input", "value")
})) abstract Tee(nvd.Comp) {
}