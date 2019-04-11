package nvd;

import js.html.DOMElement;
import js.Browser.document;

/**
DOM Tools
*/
@:native("dt") class Dt {
	@:pure
	public static function make(name: String, ?attr: haxe.DynamicAccess<String>, ?dyn: Dynamic):DOMElement {
		var dom = document.createElement(name);
		if (attr != null) {
			//for (k in attr.keys()) dom.setAttribute(k, attr.get(k));
			js.Syntax.code("for(var k in {0}) {1}.setAttribute(k, {0}[k])", attr, dom);
		}
		if (dyn != null) {
			if (Std.is(dyn, String)) {
				setText(dom, dyn);
			} else if (Std.is(dyn, Array)) {
				var i = 0;
				while (i < dyn.length) {
					var v: Dynamic = dyn[i];
					if (Std.is(v, String)) {
						dom.appendChild(document.createTextNode(v));
					} else { // if (Std.is(v, js.html.Node)) { // TODO: IE8 doesn't support "Node"
						dom.appendChild(v);
					}
					++ i;
				}
			}
		}
		return dom;
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
		//for (k in style.keys()) Reflect.setField(dom.style, k, style.get(k));
		js.Syntax.code("for(var k in {0}) {1}[k] = {0}[k]", styles, dom.style);
	}

	public static function lookup(dom: DOMElement, path: Array<Int>): DOMElement {
		for (p in path)
			dom = cast dom.children[p];
		return dom;
	}
}
