package test;

import js.Browser.document;
import nvd.VNode;
import nvd.VNode.h;

class Test {
	static function main(){
		var d1 = h("DIV", {
			className: "red some"
		}, [
			h("a[href= 'javascript: void(0)', title = haha][class='hehe']", "link 1"),
			h("br"),
			h("span[title='span span span'][href='#']#hehe.aaa.d-c", { style: {
				opacity: 0.35,
				display: "inline-block", // IE8 opacity bug?
			}}, "span 2"),
			h("br[]"),
			h("a[href='#']", "link 3"),
		]);
		var d1d = d1.create();

		var d2 = h("input", {
		}, "input test");

		var d3 = h("input[type=button].btn", {
			onclick: function(e) {
				d1.subs[0] = h("span", "tag span");
				d1.subs[2].prop.text = "span " + Std.int(Math.random() * 100);
				haxe.Timer.measure(function(){
					d1.update(d1d);
				});
			}
		}, "click");
		document.body.appendChild(d1d);
		document.body.appendChild(d2.create());
		document.body.appendChild(d3.create());
	}
}