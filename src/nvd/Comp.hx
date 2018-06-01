package nvd;

import js.html.DOMElement;

extern abstract Comp(DOMElement) to DOMElement {
	inline function new(d: DOMElement) this = d;
	private inline function lookup0():DOMElement return this;
	private inline function lookup1(a: Int):DOMElement return this.children[a];
	private inline function lookup2(a: Int, b: Int):DOMElement return this.children[a].children[b];
	private inline function lookup3(a: Int, b: Int, c: Int):DOMElement return this.children[a].children[b].children[c];
	private inline function lookup4(a: Int, b: Int, c: Int, d: Int):DOMElement return this.children[a].children[b].children[c].children[d];
	private inline function lookup5(a: Int, b: Int, c: Int, d: Int, e: Int):DOMElement return this.children[a].children[b].children[c].children[d].children[e];
	private inline function lookup(path: Array<Int>):DOMElement return Dt.lookup(this, path);
}
