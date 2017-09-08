no-vdom
--------

**Works In Progress**

### Example

create dom by VNode.

```hx
import Nvd.h;

class Main {
    static function main() {
        var h = h("h3[title='hi there!']#uniq.red", "Greeting");
        js.Browser.document.body.appendChild(h);
    }
}
```


### Notes

`IE <= 8` do not include white space-only text nodes in `childNodes`

`IE <= 8` includes comment nodes within `children`
