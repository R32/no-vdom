no-vdom
--------

**Works In Progress**

### Example

create dom by VNode.

```hx
import Nvd.h;

class Main {
    static function main() {
        var h3 = h("h3[title='hi there!']#uniq.red", "Greeting");
        js.Browser.document.body.appendChild(h3.create());
    }
}
```

related js output:

```js
Main.main = function() {
    var h3 = new nvd_VNode("H3",{ title : "hi there!", id : "uniq", 'class' : "red"}, null, "Greeting");
    window.document.body.appendChild(h3.create());
};
```


