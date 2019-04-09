
class Demo {
	static function main() {
		// hello world
		var hw = HelloWorld.ofSelector(".hello-world");
		hw.text = "你好, 世界!";

		// tick
		var tick = Tick.ofSelector(".tick");
		tick.run(new haxe.Timer(1000));

		// login
		var login = LoginForm.ofSelector("#login");
		login.btn.onclick = function() {
			trace(login.getData());
		}
	}
}

// tutorial hello world
@:build(Nvd.build("index.html", ".hello-world", {
	text: $("h4").textContent,
})) abstract HelloWorld(nvd.Comp) {
}

// tutorial tick
@:build(Nvd.build("index.html", ".tick", {
	ts: $("span").text
})) abstract Tick(nvd.Comp) {
	public inline function run(timer) {
		timer.run = function() {
			ts = "" + (Std.parseInt(ts) + 1);
		}
	}
}

// form
@:build(Nvd.build("index.html", "#login", {
	btn:      $("button[type=submit]"),
	name:     $("input[name=name]").value,
	email:    $("input[name=email]").value,
	remember: $("input[type=checkbox]").checked, // Note: IE8 does not support the pseudo-selector ":checked"
	herpderp: $("input[type=radio][name=herpderp]:checked", true).value,
})) abstract LoginForm(nvd.Comp) {
	public inline function getData() {
		return {
			name: name,
			email: email,
			remember: remember,
			herpderp: herpderp,
		}
	}
}
