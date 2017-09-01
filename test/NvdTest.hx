package test;

import js.Browser.document;
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
				nvd.DOMTools.set_text(d1.children[2], "span " + Std.int(Math.random() * 100));
				trace(haxe.Timer.stamp() - t0);
			}
		}, "click");

		document.body.appendChild(d1);
		document.body.appendChild(d2);
		document.body.appendChild(d3);
	}
}