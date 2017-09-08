package test;

import js.Browser.document;
import js.Browser.console;
import Nvd.h;

class NvdTest {
	static function main() {
		var d1 = h("div", {
			className: "red some"
		}, [
			h("a[href= 'javascript: void(0)'][title = haha][class='hehe']", "link 1"),

			h("br"),

			h("span[title='span span span'][href='#']#hehe.aaa.d-c", { style: {
				opacity: 0.35,
				display: "inline-block", // IE8 opacity bug?
			}}, "span 2"),

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

		var d2 = h("input", {
		}, "input test");

		var d3 = h("input[type=button].btn", {
			onclick: function(e) {
				var t0 = haxe.Timer.stamp();
				d1.replaceChild(h("span", "tag span"), d1.children[0]);
				nvd.Dt.setText(d1.children[2], "span " + Std.int(Math.random() * 100));
				trace(haxe.Timer.stamp() - t0);
			}
		}, "click");

		document.body.appendChild(d1);
		document.body.appendChild(d2);
		document.body.appendChild(d3);

		var foo = new Foo(document.querySelector("div.flex-table"));
		console.log(foo.input);
		console.log(foo.className);
		console.log(foo.title);
		foo.className = "a b c";
		foo.title = "Greeting";
	}
}

@:build(Nvd.build("bin/index.html", "div.flex-table", {
	input: Elem(".input-block"),
	className: Prop(".input-block", "className"),
	title: Attr([1, 0], "title"),
})) abstract Foo(nvd.Comp) to nvd.Comp {
}


@:build(Nvd.build("bin/index.html", "div.template-1", {
	link:  Elem("a"),                // or Elem([1, 0]). same as ".template-1 a"
	text:  Prop("p", "textContent"), // same as ".template-1 p".textContent
	title: Attr("a", "title"),       // same as ".template-1 a".attribute("title")
	cls:   Prop("a", "className"),   // same as ".template-1 a".className})) abstract Bar(nvd.Comp) to nvd.Comp {
	x: Prop([], "offsetLeft"),       // same as ".template-1".offsetLeft}
})) abstract Bar(nvd.Comp) to nvd.Comp {
}
