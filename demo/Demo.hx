
class Demo {
	static function main() {
		// hello world
		var t01 = HelloWorld.ofSelector(".t01 h4");
		t01.text = "你好, 世界!";

		// tick
		var t02 = Tick.ofSelector(".t02 h4");
		t02.run(new haxe.Timer(1000));

		// login
		var login = LoginForm.ofSelector("#login");
		login.btn.onclick = function() {
			trace(login.getData());
		}
	}
}

// tutorial hello world
@:build(Nvd.build("index.html", ".t01 h4", {
	text: Prop("", "text")
})) abstract HelloWorld(nvd.Comp) {
}

// tutorial tick
@:build(Nvd.build("index.html", ".t02 h4", {
	ts: Prop("span", "text")
})) abstract Tick(nvd.Comp) {
	public inline function run(timer) {
		timer.run = function() {
			ts = "" + (Std.parseInt(ts) + 1);
		}
	}
}

// form
@:build(Nvd.build("index.html", "#login", {
	btn: Elem("button[type=submit]"),
	name: Prop("input[name=name]", "value"),
	email: Prop("input[name=email]", "value"),
	remember: Prop("input[type=checkbox]", "checked"),
#if (js_es >= 5)
	// IE8 did not support the pseudo-selector ":checked"
	// the last argument "true" is used to keep the css-selector to find in runtime
	herpderp: Prop("input[type=radio][name=herpderp]:checked", "value", true),
#end
})) abstract LoginForm(nvd.Comp) {
	public inline function getData() {
	#if (js_es < 5)
		var herpderp = null;
		var a: Array<js.html.InputElement> = cast this.querySelectorAll("input[name=herpderp]");
		for (r in a)
			if (r.checked) herpderp = r.value;
	#end
		return {
			name: name,
			email: email,
			remember: remember,
			herpderp: herpderp,
		}
	}
}