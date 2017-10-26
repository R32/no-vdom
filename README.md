no-vdom
--------

[中文](README.Zh-cn.md)

![screen shot](demo/demo.gif)

```hx
@:build(Nvd.build("index.html", ".sec.t03", {
  list: Elem(".todo-list"),
  value: Prop("input[type=text]", "value"),
  btn: Elem("input[type=button]"),
})) abstract Todo(nvd.Comp) {}

class Demo {
  static function main() {
    var t03 = Todo.ofSelector(".t03");
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
```
