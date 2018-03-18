package nvd;

import js.html.DOMElement;
import js.Browser.document;

/**
DOM Tools
*/
@:native("dt") class Dt {

	@:native("h")
	public static function make(name: String, a: Attr, ?p: Prop, ?dyn: Dynamic):DOMElement {
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
		else
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
					return dom.textContent;
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
				(dom: Dynamic).value = text;
			case "OPTION":
				(dom: Dynamic).text = text;
			case "SELECT":
				var select: js.html.SelectElement = cast dom;
				for (i in 0...select.options.length) {
					if ((cast select.options[i]).text == text) {
						select.selectedIndex = i;
						break;
					}
				}
			default:
				dom.textContent = text;
			}
		} else if (dom.nodeType != js.html.Node.DOCUMENT_NODE) { // #text, #comment
			dom.nodeValue = text;
		}
		return text;
	}

	public static function getCss(dom: DOMElement, name: String): String {
		if ((dom: Dynamic).currentStyle != null) {
			return ((dom: Dynamic).currentStyle: haxe.DynamicAccess<String>)[name];
		} else {
			return js.Browser.window.getComputedStyle(cast dom, null).getPropertyValue(name);
		}
	}

	public static function setStyle(dom: DOMElement, style: haxe.DynamicAccess<Any>): Void {
		if (style == null) return;
		for (k in style.keys())
			Reflect.setField(dom.style, k, style.get(k));
	}

	public static function lookup(dom: DOMElement, path: Array<Int>): DOMElement {
		for (p in path)
			dom = cast dom.children[p];
		return dom;
	}
}


@:forward
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

@:forward
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
