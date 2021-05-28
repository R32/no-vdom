package nvd;

import js.html.DOMElement;

extern abstract Comp(DOMElement) to DOMElement {
	inline function new( d : DOMElement ) this = d;
	private inline function lookup( path : Array<Int> ) : DOMElement return Dt.lookup(this, path);
}
