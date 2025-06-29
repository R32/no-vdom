package nvd.inner;

import csss.xml.Xml;
import haxe.macro.Expr;
import haxe.macro.Context;
import haxe.macro.PositionTools;

 using nvd.inner.Utils;
import nvd.inner.HXX;

class XMLComponent {

	var template : HXX;

	public var offset(default, null) : Int;

	public var path(default, null) : String;

	public var top(default, null) : Null<Xml>;

	public var isSVG(default, null) : Bool;

	public var selector : Null<String>;

	public function new( path, offset, node, selector, svg : Bool, useHXX : Bool ) {
		top = node;
		isSVG = svg;
		this.path = path;
		this.offset = offset;
		this.selector = selector;
		template = new HXX(useHXX);
	}

	public function topComplexType() : ComplexType {
		return Tags.ctype(top.nodeName, isSVG, false);
	}

	public function position( i : Int, len : Int ) : Position {
		return PositionTools.make({file: path, min: offset + i, max: offset + i + len});
	}

	public inline function getChildPosition( child : Xml ) : Position {
		return position(child.nodePos, child.nodeName.length);
	}

	public function getChildPath( child : Xml ) : Array<Int> {
		var ret = [];
		while (child != top && child.parent != null) {
			var i = 0;
			var index = 0;
			var found = false;
			var siblings = @:privateAccess child.parent.children;
			while (i < siblings.length) {
				final elem = siblings[i];
				if (elem.nodeType == Element) {
					if (elem == child) {
						found = true;
						break;
					}
					index++;
				} else if (elem.nodeType != PCData) {
					Nvd.fatalError("Comment/CDATA/ProcessingInstruction are not allowed here", getChildPosition(elem));
				}
				i++;
			}
			if (!found)
				break;
			ret.push(index);
			child = child.parent;
		}
		if (child == top) {
			ret.reverse();
		} else {
			ret = null;
		}
		return ret;
	}

	public function parse() : Expr {
		return parseInner(this.top, true);
	}

	function parseInner( xml : Xml, isTop : Bool ) : Expr {
		// attributes
		var attr = new Array<ObjectField>();
		var a = @:privateAccess xml.attributeMap; // [(attr, value), ...]
		var i = 0;
		while (i < a.length) {
			var name  = a[i];
			var value = a[i + 1];
			var pos = this.position(xml.attrPos(name), name.length);
			attr.push( {field: name, expr: template.parse(value, pos)} );
			i += 2;
		}
		var pos = this.getChildPosition(xml);
		// innerHTML
		var html = [];
		inline function PUSH(e) if (e != null) html.push(e);
		var children = @:privateAccess xml.children;
		for (child in children) {
			if (child.nodeType == Element) {
				PUSH( parseInner(child, false) );
			} else if (child.nodeType == PCData) {
				var text = child.nodeValue;
				if (text == "")
					continue;
				PUSH( template.parse(text, this.position(child.nodePos, text.length)) );
			} else {
				Nvd.fatalError("Comment/CDATA/ProcessingInstruction are not allowed here", pos);
			}
		}
		var ctype = topComplexType();
		var name = xml.nodeName;
		var args = [macro $v{ name }];
		if ( attr.length > 0 ) {
			args.push( {expr: EObjectDecl(attr), pos: pos} );
		} else if (html.length > 0) {
			args.push( macro null );
		}
		switch(html.length) {
		case 0:
		case 1:
			var one = html[0];
			// hacks style.textContent for IE
			if (children[0].nodeType == PCData && name.toUpperCase() == "STYLE") {
				var ret = macro {
					final _css : nvd.Dt.VarString = $one;
					final _style = (cast nvd.Dt.Docs.createElement($e{ args[0] }) : $ctype);
					$b{ expandAttributes(macro _style, attr) };
					if ((_style : Dynamic).styleSheet) {
						(_style : Dynamic).styleSheet.cssText = _css;
					} else if ((_style : Dynamic).textContent) {
						_style.textContent = _css;
					} else {
						_style.innerText = _css;
					}
					_style;
				}
				return ret;
			}
			args.push(one);
		default:
			args.push(macro $a{html});
		}
		if (args.length == 1)
			return macro @:pos(pos) (cast nvd.Dt.Docs.createElement($e{ args[0] }) : $ctype);
		var ret = macro @:pos(pos) (cast nvd.Dt.h( $a{args} ) : $ctype);
		return isTop ? tryExpand(ret, args, pos, ctype) : ret;
	}

	function expandAttributes( node : Expr, attributes : Array<ObjectField> ) : Array<Expr> {
		var ret = [];
		for (attr in attributes) {
			var k = attr.field;
			var s = attr.expr;
			var e = switch(k) {
			case "id", "value", "name", "type", "src", "href", "title":
				macro $node.$k = $s;
			case "class":
				macro $node.className = $s;
			case "style":
				macro $node.style.cssText = $s;
			default:
				macro $node.setAttribute($v{ k }, $s);
			}
			e.pos = attr.expr.pos;
			ret.push(e);
		}
		return ret;
	}

	function tryExpand( origin : Expr, args : Array<Expr>, pos : Position, ctype : ComplexType ) : Expr {
		var attr = args[1];
		var content = args[2];
		var mode = HXX.WhatMode.detects(content);
		if (mode == TCComplex)
			return origin;
		var battr = switch(attr.expr) {
		case EObjectDecl(a):
			expandAttributes(macro node, a);
		default:
			[];
		}
		var content = switch(mode) {
		case TCString:
			macro node.innerText = $content;
		case TCNode:
			macro node.appendChild($content);
		default: // TCNull
			macro {};
		}
		return macro @:pos(pos) {
			final node : $ctype = cast nvd.Dt.Docs.createElement($e{ args[0] });
			$b{ battr };
			$content;
			node;
		};
	}

	public static function fromMarkup( markup : Expr, isHXX : Bool ) : XMLComponent {
		var pos = PositionTools.getInfos(markup.pos);
		var top = markup.doParse().firstElement();
		return new XMLComponent(pos.file, pos.min, top, null, top.isSVG(), isHXX);
	}
}

