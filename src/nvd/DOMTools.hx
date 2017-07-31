package nvd;

import js.html.DOMElement;

class DOMTools {

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
