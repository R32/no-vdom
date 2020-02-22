package nvd;

import js.html.DOMElement;
import js.Browser.document;

/**
DOM Tools
*/
@:native("dt") class Dt {
	/**
	 it will be called automatically by macro
	*/
	@:pure
	static function h(name: String, ?attr: haxe.DynamicAccess<String>, ?sub: Dynamic):DOMElement {
		var dom = document.createElement(name);
		if (attr != null) {
			js.Syntax.code("for(var k in {0}) {1}.setAttribute(k, {0}[k])", attr, dom);
		}
		if (sub)
			hrec(dom, sub);
		return dom;
	}

	static function hrec( box : js.html.DOMElement, sub : Dynamic ) {
		//if (sub == null)
		//	return;
		if (Std.is(sub, Array)) {
			var i = 0;
			var len = sub.length;
			while (i < len) {
				hrec(box, sub[i]);
				++ i;
			}
		} else if (Std.is(sub, String)) {
			box.appendChild(document.createTextNode(sub));
		} else {// if (Std.is(sub, js.html.DOMElement) || Std.is(sub, js.html.Text)) {
			box.appendChild(sub);
		}
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

	public static function setStyle(dom: DOMElement, styles: haxe.DynamicAccess<Any>): Void {
		js.Syntax.code("for(var k in {0}) {1}[k] = {0}[k]", styles, dom.style);
	}

	public static function lookup(dom: DOMElement, path: Array<Int>): DOMElement {
		for (p in path)
			dom = cast dom.children[p];
		return dom;
	}
}
