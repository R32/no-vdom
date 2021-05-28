package nvd;

import js.html.DOMElement;

/**
DOM Tools
*/
@:native("dt") class Dt {
	/**
	 It's used automatically by the macro
	*/
	@:pure
	static function h( name : String, ?attr : haxe.DynamicAccess<String>, ?sub : Dynamic ) : DOMElement {
		var dom = document.createElement(name);
		if (attr != null) {
			js.Syntax.code("for(var k in {0}) {1}.setAttribute(k, {0}[k])", attr, dom);
		}
		if (sub)
			hrec(dom, sub, false);
		return dom;
	}

	static function hrec( box : js.html.DOMElement, sub : Dynamic, loop : Bool ) {
		if (sub is Array) {
			var i = 0;
			var len = sub.length;
			while (i < len) {
				hrec(box, sub[i], true);
				++ i;
			}
		} else if(js.Syntax.typeof(sub) == "object") { // js.html.DOMElement or js.html.Text
			box.appendChild(sub);
		} else if (loop) {
			box.appendChild(document.createTextNode(sub));
		} else {
			box.innerText = sub;
		}
	}

	public static function setAttr( dom : DOMElement, name : String, value : String ) : String {
		if (value == null)
			dom.removeAttribute(name);
		else
			dom.setAttribute(name, value);
		return value;
	}

	public static function getText( dom : DOMElement ) : String {
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
					return dom.innerText;
			}
		} else if (dom.nodeType != js.html.Node.DOCUMENT_NODE) {
			return dom.nodeValue;
		}
		return null;
	}

	public static function setText( dom : DOMElement, text : String) : String {
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
				dom.innerText = text;
			}
		} else if (dom.nodeType != js.html.Node.DOCUMENT_NODE) { // #text, #comment
			dom.nodeValue = text;
		}
		return text;
	}

	public static function getCss( dom : DOMElement, name : String ) : String {
		if ((cast dom).currentStyle) {
			return (cast dom).currentStyle[cast name];
		} else {
			return js.Browser.window.getComputedStyle(cast dom, null).getPropertyValue(name);
		}
	}

	public static function setStyle( dom : DOMElement, styles : haxe.DynamicAccess<Any> ) : Void {
		js.Syntax.code("for(var k in {0}) {1}[k] = {0}[k]", styles, dom.style);
	}

	public static function lookup( dom : DOMElement, path : Array<Int> ) : DOMElement {
		for (p in path)
			dom = dom.children[p];
		return dom;
	}
}

@:native("document") extern private var document : js.html.Document;
