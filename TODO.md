# TODO

* CoffeeScript
    * Track variables in deferrals for Iced CoffeeScript
    * Track functions called with the `new` operator (we currently track `new Array()` (a `Call`), but not `new Array().length` (an `Op`))
    * Track soaked functions (e.g. `func?()`, `obj?.a().b()`)
    * Figure out how to instrument Iced programs before they are transformed?
* JavaScript
    * Source mapping
    * Testing
        * Find a test suite for JavaScript

