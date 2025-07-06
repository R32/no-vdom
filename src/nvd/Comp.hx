package nvd;

import js.html.DOMElement;

extern abstract Comp(DOMElement) to DOMElement {
	inline function new( d : DOMElement ) this = d;
}
