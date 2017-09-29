package nvd;

import js.html.DOMElement;

/**
 for IE8 that use children instead of childNodes.
*/
abstract Comp(DOMElement) to DOMElement {
	public inline function new(d) this = d;
	inline function lookup0(): DOMElement return this;
	inline function lookup1(a): DOMElement return this.children[a];
	inline function lookup2(a, b): DOMElement return this.children[a].children[b];
	inline function lookup3(a, b, c): DOMElement return this.children[a].children[b].children[c];
	inline function lookup4(a, b, c, d): DOMElement return this.children[a].children[b].children[c].children[d];
	inline function lookup5(a, b, c, d, e): DOMElement return this.children[a].children[b].children[c].children[d].children[e];
	inline function lookup(path: Array<Int>) return Dt.lookup(this, path);
}
