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

	public function new( path, offset, node, svg : Bool, useHXX : Bool ) {
		top = node;
		isSVG = svg;
		this.path = path;
		this.offset = offset;
		template = new HXX(useHXX);
	}

	public function topComplexType() : ComplexType {
		return Tags.ctype(top.nodeName, isSVG, false);
	}

	public function position( i : Int, len : Int ) : Position {
		return PositionTools.make({file: path, min: offset + i, max: offset + i + len});
	}

	public inline function childPosition( child : Xml ) : Position {
		return position(child.nodePos, child.nodeName.length);
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
		var pos = this.childPosition(xml);
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
					$b{ inlineAttributes(macro _style, attr) };
					if ((_style : Dynamic).styleSheet) {
						(_style : Dynamic).styleSheet.cssText = _css;
					} else {
						_style.textContent = _css;
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
		return isTop ? tryInline(ret, args, pos, ctype) : ret;
	}

	function inlineAttributes( node : Expr, attributes : Array<ObjectField> ) : Array<Expr> {
		var ret = [];
		for (attr in attributes) {
			var e = switch(attr.field) {
			case "id":
				macro $node.id = $e{ attr.expr }
			case "class":
				macro $node.className = $e{ attr.expr }
			case name:
				macro $node.setAttribute($v{ name }, $e{ attr.expr });
			}
			e.pos = attr.expr.pos;
			ret.push(e);
		}
		return ret;
	}

	function tryInline( origin : Expr, args : Array<Expr>, pos : Position, ctype : ComplexType ) : Expr {
		var attr = args[1];
		var content = args[2];
		var mode = HXX.WhatMode.detects(content);
		if (mode == TCComplex)
			return origin;
		var battr = switch(attr.expr) {
		case EObjectDecl(a):
			inlineAttributes(macro node, a);
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
			final node = (cast nvd.Dt.Docs.createElement($e{ args[0] }) : $ctype);
			$b{ battr };
			$content;
			node;
		};
	}

	public static function fromMarkup( e : Expr, isHXX : Bool ) : XMLComponent {
		var pos = PositionTools.getInfos(e.pos);
		var txt = e.markup();
		var top = txt.parseXML(e.pos).firstElement();
		return new XMLComponent(pos.file, pos.min, top, top.isSVG(), isHXX);
	}
}

