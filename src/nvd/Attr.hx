package nvd;

import haxe.DynamicAccess;

abstract Attr(Dynamic<String>) from Dynamic<String> to Dynamic<String> {

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