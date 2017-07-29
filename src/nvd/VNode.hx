package nvd;

#if !macro
import js.Browser.document;
import js.html.DOMElement;
import nvd.p.Range;
import nvd.p.AttrParse;
import nvd.p.CharValid.*;
#end

class VNode {
#if !macro
	public var dom: DOMElement;
	public var name: String;
	public var prop: Prop;
	public var attr: Attr;
	public var subs: Array<VNode>;

	public function new(name: String, p: Prop = null, dyn: Dynamic = null) {

		setAttr(name);

		if (p != null) prop = p;

		if (dyn == null) return;

		if (Std.is(dyn, String)) {
			if (this.prop == null) this.prop = new Prop();
			this.prop.text = dyn;
		} else if(Std.is(dyn, Array)) {
			subs = dyn;
		}
	}

	function setAttr(s: String) {
		var r = Range.until(s, 0, is_alpha);

		if (r.left == 0 && r.right == s.length) {
			name = s.toUpperCase();
		} else {
			name = r.substr(s).toUpperCase();
			var ap = new AttrParse(s, r.right, s.length);
			if (!ap.empty()) {
				attr = ap.attr;
				ap.destory();
			}
		}
	}

	public function create(): DOMElement {
		var d = document.createElement(name);
		update(d, true);
		return d;
	}

	public function destory() {
		dom = null;
		prop = null;
		attr = null;
		subs = null;
	}

	public inline function refresh() update(this.dom, true);

	public function update(dom: DOMElement, top: Bool): Bool {
		if (dom == null) dom = this.dom;
		if (dom == null || dom.tagName != this.name) return false;
		this.dom = dom;
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
						sv.update(sd, true);
						dom.appendChild(sd);
					} else {
						if (sd.tagName == sv.name) {
							sv.update(sd, true);
						} else {
							var fd = cast document.createElement(sv.name);
							sv.update(fd, true);
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
				if (top) { // use fragment
					var frags = document.createDocumentFragment();
					while (i < len) {
						sv = this.subs[i];
						sd = document.createElement(sv.name);
						frags.appendChild(sd);
						sv.update(sd, false);
					++ i;
					}
					dom.appendChild(frags);
				} else {
					while (i < len) {
						sv = this.subs[i];
						sd = document.createElement(sv.name);
						sv.update(sd, false);
						dom.appendChild(sd);
					++ i;
					}
				}
			}
		}
		if (attr != null) attr.update(dom);
		if (prop != null) prop.update(dom);
		return true;
	}

	static function subslen(subs: Array<VNode>): Int {
		var len = subs.length;
		var sub: VNode;
		for	(i in 0...len) {
			sub = subs[i];
			if (sub.subs != null) len += subslen(sub.subs);
		}
		return len;
	}

#end
	macro public static function h(exprs: Array<haxe.macro.Expr>) {
		return macro new nvd.VNode($a{exprs});
	}
}