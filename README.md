no-vdom
--------

A haxelib used for static(in compile time) HTML data building

## Installation

```bash
haxelib install no-vdom
```

## Feature

* Intelligent:

  ![screen shot](demo/demo-3.gif)

* **Zero Performance Loss**, Zero runtime dependency

* IE8+ Support. *Note: Needs polyfills such as [textContext](http://eligrey.com/blog/post/textcontent-in-ie8)*

### HXX

Uses `{{` `}}` as variable separator.

```haxe
var title = "hi there";
var content = "click here";
var div = Nvd.HXX(<div><a title="{{ title }}"> LL {{ content }} RR </a></div>);
document.body.appendChild(div);
```

Generated js:

```js
window.document.body.appendChild(dt.h("div",null,dt.h("a",{ title : "hi there"}," LL " + "click here" + " RR ")));
```

If expr with prefix `$` inside `{{ }}` then that will be treated as `Element/TextNode`.

```haxe
var link = HXX(<a>here</a>);
var col = [];
for (i in 0...Std.random(20))
	col.push(HXX(<li>n : {{ i }}</li>));

var ul = HXX(<ul> click {{ $link }} {{ $col }} </ul>);
document.body.appendChild(ul);
```

Generated js:

```js
var link = dt.h("a",null,"here");
var col = [];
var _g = 0;
var _g1 = Std.random(20);
while(_g < _g1) col.push(dt.h("li",null,"n : " + _g++));
window.document.body.appendChild(dt.h("ul",null,[" click ",link,col]));
```

### data binding

.....

#### Syntax

```haxe
/**
@file: Specify an HTML file, Relative to current project.
@root: a css selector which will be queried as **root DOMElement** for the Component.
@defs: Specify property binding, for example:
  {
    btn :   $("button"),
    text:   $("label").textContext,
    value:  $("input[type=button]").attr.value,
    x:      $(null).style.left,  // if selector is null/"" then self(root DOMElement).
    y:      $(null).style.top,
  }
*/
Nvd.build(file: String, root: String, ?defs: Dynamic<Defines>);

/**
@selector: a css selector that used to specify a child DOMElement , if null it's represented as root DOMElement.
@keep: Optional, if true that will keep the "css-selector" in output.
*/
function $(selector:String, ?keep: Bool):AUTO;

/**
There are 4 types available:
  $(...)              => DOMElement
  $(...).XXX          => Property
  $(...).attr.XXX     => Attribute,
  $(...).attr["XXX"]  => Attribute,
  $(...).style.XXX    => Style-Property
*/
```

sample:

```html
<div id="login" style="width: 320px; font-size: 14px">
  <div style="clear: both">
    <label for="name" style="float:left;">Name</label>
    <input style="float:right" type="text" name="name" />
  </div>
  <div style="clear: both">
    <label for="email" style="float:left;">Email address</label>
    <input style="float:right" type="email" name="email">
  </div>
  <div style="clear: both">
    <label style="font-size: 12px"><input type="checkbox" /> Remember me </label>
    <label style="font-size: 12px"><input type="radio" name="herpderp" value="herp" checked="checked" /> Herp </label>
    <label style="font-size: 12px"><input type="radio" name="herpderp" value="derp" /> Derp </label>
    <button style="float:right" type="submit">Submit</button>
  </div>
</div>
```

Component:

```hx
@:build(Nvd.build("index.html", "#login", {
  btn:      $("button[type=submit]"),
  name:     $("input[name=name]").value,
  email:    $("input[name=email]").value,
  remember: $("input[type=checkbox]").checked,
  // Note: IE8 does not support the pseudo-selector ":checked"
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


class Demo {
  static function main() {
    // login
    var login = LoginForm.ofSelector("#login");
    login.btn.onclick = function() {
      trace(login.getData());
    }
  }
}
```

![screen shot](demo/demo.gif)

![screen shot](demo/demo-2.gif)

output:

```js
// Generated by Haxe 4.0.0 (git build development @ e6f3b7d)
(function () { "use strict";
var Demo = function() { };
Demo.main = function() {
  var login = window.document.querySelector("#login");
  login.children[2].children[3].onclick = function() {
    console.log("Demo.hx:9:",{ name : login.children[0].children[1].value, email : login.children[1].children[1].value, remember : login.children[2].children[0].children[0].checked, herpderp : login.querySelector("input[type=radio][name=herpderp]:checked").value});
  };
};
Demo.main();
})();
```

## CHANGES

* `0.5.0.`:
  - Code Refactor
  - Added Simple `HXX`
  - Added SVG elements support(Only for Query)
* `0.4.0`: added new data binding syntax
