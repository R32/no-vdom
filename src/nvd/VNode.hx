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
}

@:forward(get, set, exists, remove, keys)
@:dce abstract Attr(haxe.DynamicAccess<String>) from Dynamic<String> to Dynamic<String> {

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
@:dce abstract Prop(haxe.DynamicAccess<Any>) from Dynamic<Any> to Dynamic<Any> {

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
