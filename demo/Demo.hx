
class Demo {
	static function main() {
		// hello world
		var t01 = HelloWorld.ofSelector(".t01 h4");
		t01.text = "你好, 世界!";
		// tick
		var t02 = Tick.ofSelector(".t02 h4");
		t02.run(new haxe.Timer(1000));

		// todo list
		var t03 = Todo.ofSelector(".t03.sec");
		t03.btn.onclick = function() {
			var value = t03.value;
			if (value != "") {
				var li = Nvd.h("li", value);
				t03.list.appendChild(li);
				t03.value = "";
			}
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

// tutorial todo list
@:build(Nvd.build("index.html", ".sec.t03", {
	list: Elem(".todo-list"),
	value: Prop("input[type=text]", "value"),
	btn: Elem("input[type=button]"),
})) abstract Todo(nvd.Comp) {}