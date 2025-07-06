package;

import js.Browser.document;
import js.Browser.console;
import Nvd.HXX;

class NvdTest {
	static function test_markup() {
		var link = "variable link";
		var haha = "haha";
		var div = HXX(
			<div class="red some">
				<label>text node: </label>
				<input type="text" value="default value" />
				<br />
				<a href="javascript:void(0)" class="{{ haha }}" title={{haha}}>the {{link}} 1</a>
				<br />
				<a id="hehe" class="aaa d-c" title="span span span" href="#">the {{link}} 2</a>
				<br />
				<ol>
					<li>1</li>
					<li>2</li>
					<li>3</li>
					<li>4</li>
				</ol>
			</div>
		);
		document.body.appendChild(div);
		var link = HXX(<a>here</a>);
		var col = [];
		for (i in 0...Std.random(20))
			col.push(HXX(<li>n : {{ i }}</li>));

		var ul = HXX(<ul> click {{ link }} {{ col }} </ul>);
		document.body.appendChild(ul);

		var css = "body { margin : 0; }";
		var style = HXX( <style class="xyz">{{ css }}</style> );
		document.head.appendChild(style);
	}

	static function test_comp() {
		var foo = new Foo(document.querySelector("div.flex-table"));
		foo.value = "a b c";
		foo.title = "Greeting";
		trace(foo.value);
		trace(foo.title);

		var bar: Bar = Bar.ofSelector("div.template-1");
		trace(bar.x);
		trace(bar.y);
		trace(bar.text);
		bar.text = "abc";
		trace(bar.textNode.nodeValue);

		var testSVG = TestSVG.ofSelector("#testSVG");

		// buildString
		var tee = Tee.create();
		document.body.appendChild(tee);
		document.body.appendChild(Bar.create());

		// svg element
		var lyrics = [
			"you are my fire",
			"the one desire",
			"Believe when I say",
			"I want it that way",
		];
		var lyricsIndex = 0;
		testSVG.rectOnclick = function(e) {
			trace(testSVG.text);
			lyricsIndex = (lyricsIndex + 1) % lyrics.length;
			testSVG.text = lyrics[lyricsIndex];
		}

		var text = Depth.ofSelector(".depth").selected;
		trace(text, text == "p3 2");
	}

	static function main() {
		var text = "Click here";
		var a = HXX(<a id = "linkid" style="color : {{ color }}">{{ text }}</a>);
		document.body.appendChild(a);

		var title = "hi there";
		var content = "click here";
		var div = HXX(<div><a title="{{ title }}"> LL {{ content }} RR </a></div>);
		document.body.appendChild(div);

		test_markup();
		test_comp();
	}

	static inline var RED = "red";
	static inline var color = RED;
}

@:build(Nvd.build("bin/index.html", "div.flex-table", {
	display: $(null).style.display,
	input:   $(".input-block"),
	value:   @:keep $(".input-block").value,
	title:   $("[title]").attr["title"],
	sub:     ($(".flex-table-item-primary") : FooChild),
})) abstract Foo(nvd.Comp) {
}

@:build(Nvd.build("bin/index.html", "div.flex-table-item-primary", {
})) abstract FooChild(nvd.Comp) {
}

@:build(Nvd.build("bin/index.html", "div.template-1", {
	link:    $("a"),
	text:    $("p").innerText, // text is custom property
	title:   $("a").attr.title,
	cls:     $("a").className,
	x:       $(null).offsetLeft,
	y:       $("").offsetTop,
	textNode: $("a").previousSibling,
})) abstract Bar(nvd.Comp) {
}

// svg element
@:build(Nvd.build("bin/index.html", "#testSVG", {
	rectOnclick:  $("rect").onclick,
	text:         $("text").textContent,
}, true)) abstract TestSVG(nvd.Comp) {
	public function new( dom : js.html.DOMElement ) {
		this = cast dom;
	}
}


@:build(Nvd.build("bin/index.html", ".depth", {
	selected : $("[selected]").innerText,
})) extern abstract Depth(nvd.Comp) {
}


// buildString
@:build(Nvd.buildString(
<div class="hehe haha">
	<label> some thing <input type="text" value={{hello}} /></label>
	<span></span>
</div>)) abstract Tee(nvd.Comp) {
}
