package nvd;

import js.Browser.document;
import js.html.DOMElement;

class VNode {
	public var name: String;
	public var prop: Prop;
	public var attr: Attr;
	public var subs: Array<VNode>;

	public function new(name: String, a: Attr, p: Prop = null, dyn: Dynamic = null) {

		this.name = name; // toUpperCase() by macro

		if (a != null) attr = a;

		if (p != null) prop = p;

		if (dyn == null) return;

		if (Std.is(dyn, String)) {
			if (this.prop == null) this.prop = new Prop();
			this.prop.text = dyn;
		} else if(Std.is(dyn, Array)) {
			subs = dyn;
		}
	}

	public function create(): DOMElement {
		var d = document.createElement(name);
		if (subslen(subs) > 3) {
			var f = document.createDocumentFragment();
			f.appendChild(d);
		}
		update(d);
		return d;
	}

	public function destory() {
		if (subs != null) {
			for (i in 0...subs.length) {
				subs[i].destory();
			}
		}
		prop = null;
		attr = null;
		subs = null;
	}

	public function update(dom: DOMElement): Bool {
		if (dom == null || dom.tagName != this.name) return false;
		if (subs != null) {
			var sd: DOMElement = null;
			var sv: VNode = null;
			var i = 0;
			var len = subs.length;
			if (dom.hasChildNodes()) {
				while (i < len) {
					sv = subs[i];
					sd = cast dom.childNodes[i];
					if (sd == null) {
						sd = cast document.createElement(sv.name);
						sv.update(sd);
						dom.appendChild(sd);
					} else {
						if (sd.tagName == sv.name) {
							sv.update(sd);
						} else {
							var fd = cast document.createElement(sv.name);
							sv.update(fd);
							dom.insertBefore(fd, sd);
							dom.appendChild(sd); // move to the end
						}
					}
				++ i;
				}
				// remove the extra
				while (dom.childNodes.length > len) {
					// TODO: detach the event bind before removeChild
					// TODO: skip TextNode???
					dom.removeChild(dom.lastChild);
				}
			} else {
				while (i < len) {
					sv = this.subs[i];
					sd = document.createElement(sv.name);
					dom.appendChild(sd);
					sv.update(sd);
				++ i;
				}
			}
		}
		if (attr != null) attr.update(dom);
		if (prop != null) prop.update(dom);
		return true;
	}

	static function subslen(subs: Array<VNode>): Int {
		var len = subs != null ? subs.length : 0;
		var sub: VNode;
		for	(i in 0...len) {
			sub = subs[i];
			if (sub.subs != null) len += subslen(sub.subs);
		}
		return len;
	}

	public static var textContent = untyped __js__("'textContent' in document.documentElement") ? "textContent" : "innerText";
}

@:dce abstract Attr(Dynamic<String>) from Dynamic<String> to Dynamic<String> {

	public inline function new() this = {};

	public inline function get(key: String):String {
		return untyped this[key];
	}

	public inline function set(key: String, value: String):String {
		return untyped this[key] = value;
	}

	public inline function exists(key):Bool return Reflect.hasField(this, key);

	public inline function remove(key):Bool return Reflect.deleteField(this, key);

	public inline function keys():Array<String> return Reflect.fields(this);

	public inline function update(dom: js.html.DOMElement) {
		var v: String;
		for (k in keys()) {
			v = get(k);
			if (v == null)
				dom.removeAttribute(k);
			else if (dom.getAttribute(k) != v)
				dom.setAttribute(k, v);
		}
	}
}

@:dce abstract Prop(Dynamic<Any>) from Dynamic<Any> to Dynamic<Any> {

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

	public var style(get, set): haxe.DynamicAccess<Any>;
	inline function get_style():haxe.DynamicAccess<Any> return this.style;
	inline function set_style(v: haxe.DynamicAccess<Any>):haxe.DynamicAccess<Any> return this.style = v;

	public inline function update(dom: DOMElement) {
		for (k in Reflect.fields(this)) {
			switch (k) {
			case "text": text_update(dom);
			case "style": style_update(dom);
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
				if (Reflect.field(dom, VNode.textContent) != text)
					Reflect.setField(dom, VNode.textContent, text);
			}
		}
	}

	inline function style_update(dom: DOMElement) {
		if (style == null) return;
		var vst = style;
		for (sk in vst.keys()) {
			switch (sk) {
			case "opacity":
				if (VNode.textContent == "innerText") {// if browser below IE9
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
}