package nvd;

import js.html.DOMElement;
import js.Browser.document;

class Dt {

	@:pure public static function make(name: String, a: Attr, ?p: Prop, ?dyn: Dynamic):DOMElement {
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
					} else { // if (Std.is(v, js.html.Node)) { // TODO: IE8 doesn't support "Node"
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

	public static function setAttr(dom: DOMElement, name: String, value: String): String {
		if (value == null)
			dom.removeAttribute(name);
		else if (dom.getAttribute(name) != value)
			dom.setAttribute(name, value);
		return value;
	}

	public static function getText(dom: DOMElement): String {
		if (dom.nodeType == js.html.Node.ELEMENT_NODE) {
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
		} else if (dom.nodeType != js.html.Node.DOCUMENT_NODE) {
			return dom.nodeValue;
		}
		return null;
	}

	public static function setText(dom: DOMElement, text: String): String {
		if (dom.nodeType == js.html.Node.ELEMENT_NODE) {
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
		} else if (dom.nodeType != js.html.Node.DOCUMENT_NODE) { // #text, #comment
			dom.nodeValue = text;
		}
		return text;
	}

	// Note: getComputedStyle()[abc-def-ght] / currentStyle["abcDefGht"]
	public static function setStyle(dom: DOMElement, style: haxe.DynamicAccess<Any>): Dynamic<Any> {
		if (style != null) {
			var ie8 = textContent == "innerText"; // if browser below IE9
			for (k in style.keys()) {
				if (ie8) {
					switch (k) {
					case "opacity":
						var f: Float = style.get("opacity");
						Reflect.setField(dom.style, "filter", 'progid:DXImageTransform.Microsoft.Alpha(Opacity=${Std.int(f * 100)})');
						continue;
					case "float":
						k = "styleFloat";
					default:
					}
				}
				var value = style.get(k);
				if (Reflect.field(dom.style, k) != value)
					Reflect.setField(dom.style, k, value);
			}
		}
		return style;
	}

	public static function lookup(dom: DOMElement, path: Array<Int>): DOMElement {
		for (p in path) {
			dom = cast dom.childNodes[p];
		}
		return dom;
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
			Dt.setAttr(dom, k, v);
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
			case "text": if (text != null) Dt.setText(dom, text);
			case "html": if (html != null && dom.innerHTML != html) dom.innerHTML = html;
			case "style": Dt.setStyle(dom, style);
			default:
				var value = this.get(k);
				if (Reflect.field(dom, k) != value)
					Reflect.setField(dom, k, this.get(k));
			}
		}
	}
}
