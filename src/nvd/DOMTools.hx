package nvd;

import js.html.DOMElement;
import js.Browser.document;

class DOMTools {

	public static function make(name: String, a: Attr, p: Prop = null, dyn: Dynamic = null):DOMElement {
		var dom = document.createElement(name);

		if (a != null) a.update(dom);

		if (dyn != null) {
			if (Std.is(dyn, String)) {
				if (p == null) p = new Prop();
				p.text = dyn;
			} else if (Std.is(dyn, Array)) {
				if (subslen((dyn: Array<Dynamic>)) > 3) {
					document.createDocumentFragment().appendChild(dom);
				}
				for (v in (dyn: Array<Dynamic>)) {
					if (Std.is(v, String)) {
						dom.appendChild(document.createTextNode(v));
					} else if (Std.is(v, js.html.Node)) {
						dom.appendChild(v);
					}
				}
			}
		}

		if (p != null) p.update(dom);

		return dom;
	}

	static function subslen(subs: Array<Dynamic>): Int {
		var len = subs != null ? subs.length : 0;
		for	(v in subs) {
			if (v.childNodes != null && v.childNodes.length > 0) {
				len += subslen(v.childNodes);
			}
		}
		return len;
	}

	public static function get_text(dom: DOMElement): String {
		switch (dom.tagName) {
			case "INPUT":
				return (cast dom).value;
			case "OPTION":
				return (cast dom).text;
			case "SELECT":
				var select: js.html.SelectElement = cast dom;
				return (cast select.options[select.selectedIndex]).text;
			default:
				return Reflect.field(dom, textContent);
		}
	}

	public static function set_text(dom: DOMElement, text: String): String {
		switch (dom.tagName) {
		case "INPUT":
			if ((cast dom).value != text)(cast dom).value = text;
		case "OPTION":
			if ((cast dom).text != text) (cast dom).text = text;
		case "SELECT":
			var select: js.html.SelectElement = cast dom;
			if ((cast select.options[select.selectedIndex]).text != text) {
				for (i in 0...select.options.length) {
					if ((cast select.options[i]).text == text) {
						select.selectedIndex = i;
						break;
					}
				}
			}
		default:
			if (Reflect.field(dom, textContent) != text)
				Reflect.setField(dom, textContent, text);
		}
		return text;
	}

	// Note: getComputedStyle()[abc-def-ght] / currentStyle["abcDefGht"](float=>styleFloat) is too hard
	public static function set_style(dom: DOMElement, style: haxe.DynamicAccess<Any>): Dynamic<Any> {
		if (style != null) {
			for (k in style.keys()) {
				switch (k) {
				case "opacity":
					if (textContent == "innerText") { // if browser below IE9
						var f: Float = style.get("opacity");
						Reflect.setField(dom.style, "filter", 'progid:DXImageTransform.Microsoft.Alpha(Opacity=${Std.int(f * 100)})');
						continue;
					}
				default:
					var value = style.get(k);
					if (Reflect.field(dom.style, k) != value)
						Reflect.setField(dom.style, k, value);
				}
			}
		}
		return style;
	}

	static var textContent = untyped __js__("'textContent' in document.documentElement") ? "textContent" : "innerText";
}


@:forward(get, set, exists, remove, keys)
@:dce private abstract Attr(haxe.DynamicAccess<String>) from Dynamic<String> to Dynamic<String> {

	public inline function new() this = {};

	public inline function update(dom: js.html.DOMElement) {
		var v: String;
		for (k in this.keys()) {
			v = this.get(k);
			if (v == null)
				dom.removeAttribute(k);
			else if (dom.getAttribute(k) != v)
				dom.setAttribute(k, v);
		}
	}
}

@:forward(get, set, exists, remove, keys)
@:dce private abstract Prop(haxe.DynamicAccess<Any>) from Dynamic<Any> to Dynamic<Any> {

	public inline function new() this = {};

	public var text(get, set): String;
	inline function get_text(): String return this.get("text");
	inline function set_text(v: String): String return this.set("text", v);

	public var html(get, set): String;
	inline function get_html(): String return this.get("html");
	inline function set_html(v: String): String return this.set("html", v);

	public var style(get, set): haxe.DynamicAccess<Any>;
	inline function get_style():haxe.DynamicAccess<Any> return this.get("style");
	inline function set_style(v: haxe.DynamicAccess<Any>):haxe.DynamicAccess<Any> return this.set("style", v);

	public inline function update(dom: DOMElement) {
		for (k in this.keys()) {
			switch (k) {
			case "text": if (text != null) DOMTools.set_text(dom, text);
			case "html": if (html != null && dom.innerHTML != html) dom.innerHTML = html;
			case "style": DOMTools.set_style(dom, style);
			default:
				var value = this.get(k);
				if (Reflect.field(dom, k) != value)
					Reflect.setField(dom, k, this.get(k));
			}
		}
	}
}
