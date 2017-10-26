no-vdom
--------

[中文](README.Zh-cn.md)

![screen shot](demo/demo.gif)

```hx
// index.html
//<div class="sec t03">
//  <h4>TODO</h4>
//  <form>
//      <input type="text" />
//      <input type="button" value="Add" />
//  </form>
//  <ul class="todo-list"></ul>
//</div>
@:build(Nvd.build("index.html", ".t03", {
  list: Elem(".todo-list"),
  value: Prop("input[type=text]", "value"),
  btn: Elem("input[type=button]"),
})) abstract Todo(nvd.Comp) {
  public inline function add(s: String) {
    var li = Nvd.h("li", s);
    list.appendChild(li);
  }
}

class Demo {
  static function main() {
    var t03 = Todo.ofSelector(".t03");
    t03.btn.onclick = function() {
      t03.add(t03.value);
    }
  }
}
```
