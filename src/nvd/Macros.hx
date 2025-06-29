package nvd;

#if macro
 using haxe.macro.Tools;
import haxe.macro.Expr;
import haxe.macro.Type;
import haxe.macro.Context;

import nvd.inner.XMLComponent;
import nvd.inner.AObject;
import nvd.inner.Tags;
import Nvd.fatalError;

@:allow(Nvd)
class Macros {
	static function make(comp: XMLComponent, defs: Expr): Array<Field> {
		var pos = Context.currentPos();
		var cls : ClassType = Context.getLocalClass().get();
		var cls_path = switch (cls.kind) {
		case KAbstractImpl(_.get() => c):
			if (c.type.toString() != "nvd.Comp")
				fatalError('Only for abstract ${c.name}(nvd.Comp) ...', pos);
			{pack: c.pack, name: c.name};
		default:
			fatalError('Only for abstract type', pos);
		}
		var fields = Context.getBuildFields();
		var reserve = new Map<String, Bool>();
		for (f in fields)
			reserve.set(f.name, true);

		var aobj = new AObject(comp);
		try {
			aobj.parse(defs);
		} catch ( e : AObjectError ) {
			fatalError(e.msg, e.pos);
		}

		// haxe#12005 "_new" => "_hx_new" (abstract constructor)
		if (!(reserve.exists("_new") || reserve.exists("_hx_new"))) {
			var ct_dom = macro :js.html.DOMElement;
			fields.push({
				name: "new",
				access: [APublic, AInline],
				pos: pos,
				kind: FFun({
					args: [{name: "d", type: ct_dom}],
					ret: null,
					expr: macro this = cast (d: $ct_dom), // type checking and casting
				})
			});
		}
		var ct_top =  comp.topComplexType();
		fields.push({
			name: "dom",
			access: [APublic],
			pos: pos,
			kind: FProp("get", "never", ct_top)
		});
		fields.push({
			name: "get_dom",
			access: [AInline, APrivate],
			pos: pos,
			meta: [{name: ":to", pos: pos}],
			kind: FFun({
				args: [],
				ret: ct_top,
				expr: macro return cast this
			})
		});
		var ct_cls = TPath(cls_path);
		if (!reserve.exists("ofSelector")) {
			fields.push({
				name: "ofSelector",
				access: [APublic, AInline, AStatic],
				pos: pos,
				kind: FFun({
					args: [{name: "s", type: macro :String}],
					ret: ct_cls,
					expr: macro return (cast nvd.Dt.Docs.querySelector(s) : $ct_cls)
				})
			});
		}
		if (!comp.isSVG && !reserve.exists("create")) {
			var ecreate = comp.parse();
			ecreate = {expr: ECast(ecreate, null), pos: pos};
			fields.push({
				name: "create",
				access: [APublic, AInline, AStatic],
				pos: pos,
				kind: FFun({
					args: [],
					ret: ct_cls,
					expr: macro return $ecreate
				})
			});
		}
		if (comp.selector != null) {
			fields.push({
				name: "SELECTOR",
				access: [APublic, AInline, AStatic],
				pos: pos,
				kind : FVar(null, macro $v{ comp.selector })
			});
		}
		for (k in aobj.bindings.keys()) {
			var item = aobj.bindings.get(k);
			var aname = item.name;
			var edom  = if (item.keepCSS && item.markup.css != null) {
				macro cast dom.querySelector($v{item.markup.css});
			} else {
				item.markup.path.length < 2
				? htmlChildren(item.markup.path, item.markup.pos)
				: macro @:privateAccess cast this.lookup( $v{ item.markup.path } );
			}
			var edom = {
				expr: ECheckType(edom, item.markup.ctype),
				pos : item.markup.pos
			};
			fields.push({
				name: k,
				access: k.charCodeAt(0) == "_".code ? [APrivate] : [APublic],
				kind: FProp("get", (item.readOnly ? "never": "set"), item.ctype),
				pos: item.markup.pos,
			});
			fields.push({   // getter
				name: "get_" + k,
				access: [APrivate, AInline],
				kind: FFun( {
					args: [],
					ret: item.ctype,
					expr: switch (item.mode) {
					case Elem if(item.markup.ctype != item.ctype): macro return cast $edom;
					case Elem: macro return $edom;
					case Attr: macro return $edom.getAttribute($v{ aname });
					case Prop: macro return $edom.$aname;
					case Style: macro return $edom.style.$aname;  // return nvd.Dt.getCss($edom, $v{aname})???
					}
				}),
				pos: item.markup.pos,
			});
			if (item.readOnly)
				continue;
			fields.push({
				name: "set_" + k,
				access: [APrivate, AInline],
				kind: FFun({
					args: [{name: "v", type: item.ctype}],
					ret: item.ctype,
					expr: switch (item.mode) {
					case Attr: macro { $edom.setAttribute($v{ aname }, v);  return v; }
					case Prop: macro return $edom.$aname = v;
					case Style: macro return $edom.style.$aname = v;
					default: throw "ERROR";
					}
				}),
				pos: item.markup.pos,
			});
		}

		if (comp.offset == 0) {// from Nvd.build
			Context.registerModuleDependency(cls.module, comp.path);
		}
		return fields;
	}

	// [1,0,3] => this.children[1].children[0].children[3]
	static function htmlChildren( a : Array<Int>, pos ) {
		var thiz = macro @:pos(pos) cast this;
		return a.length > 0
		? Lambda.fold(a, (item, prev)-> macro @:pos(pos) (cast $prev).children[$v{item}], thiz)
		: thiz;
	}
}
#else
extern class Macros{}
#end