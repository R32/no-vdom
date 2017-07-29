package nvd;

import js.html.DOMElement;

abstract Prop(Dynamic<Any>) from Dynamic<Any> to Dynamic<Any> {

	public inline function new() this = {};

	public inline function get(key: String):Null<Any> {
		return untyped this[key];
	}

	public inline function set(key: String, value: Any):Null<Any> {
		return untyped this[key] = value;
	}

	@:resolve inline function resolve(key: String): Null<Any> {
		return untyped this[key];
	}

	public inline function exists(key):Bool return Reflect.hasField(this, key);

	public inline function remove(key):Bool return Reflect.deleteField(this, key);

	public inline function keys():Array<String> return Reflect.fields(this);

	public var text(get, set): String;
	inline function get_text(): String return this.text;
	inline function set_text(v: String): String return this.text = v;

	public var html(get, set): String;
	inline function get_html(): String return this.html;
	inline function set_html(v: String): String return this.html = v;

	public var cls(get, set): String;
	inline function get_cls(): String return this.cls;
	inline function set_cls(v: String): String return this.cls = v;

	public var style(get, set): haxe.DynamicAccess<Any>;
	inline function get_style():haxe.DynamicAccess<Any> return this.style;
	inline function set_style(v: haxe.DynamicAccess<Any>):haxe.DynamicAccess<Any> return this.style = v;

	public function update(dom: DOMElement) {
		for (k in Reflect.fields(this)) {
			switch (k) {
			case "text": text_update(dom);
			case "style": style_update(dom);
			case "cls": if (cls != null) dom.className = get(k);
			default:
				Reflect.setField(dom, k, get(k));
			}
		}
	}

	inline function text_update(dom: DOMElement) {
		if (text != null) {
			switch (dom.tagName) {
			case "INPUT":
				(cast dom).value = text;
			case "OPTION":
				(cast dom).text = text;
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
		}
	}

	inline function style_update(dom: DOMElement) {
		if (style == null) return;
		var vst = style;
		for (sk in vst.keys()) {
			switch (sk) {
			case "opacity":
				if (textContent == "innerText") {// if browser below IE9
					var f: Float = vst.get("opacity");
					Reflect.setField(dom.style, "filter", 'progid:DXImageTransform.Microsoft.Alpha(Opacity=${Std.int(f * 100)})');
					//Reflect.setField(dom.style, "filter", 'alpha(opacity=${Std.int(f * 100)})');
					//Reflect.setField(dom.style, "zoom", 1);
					continue;
				}
			default:
			}
			var sv = vst.get(sk);
			if (Reflect.field(dom.style, sk) != sv)
				Reflect.setField(dom.style, sk, sv);
		}
	}

	static var textContent = untyped __js__("'textContent' in document.documentElement") ? "textContent" : "innerText";
}