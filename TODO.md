# TODO

* CoffeeScript
    * Track variables in deferrals for Iced CoffeeScript
    * Track functions called with the `new` operator (we currently track `new Array()` (a `Call`), but not `new Array().length` (an `Op`))
    * Track soaked functions (e.g. `func?()`, `obj?.a().b()`)
* JavaScript
    * Tracing
        * `'after'` events
        * Consistent tracing (i.e. pass the trace tests)
    * Variable Tracking
        * Track properties (e.g. `window.location`)
        * Function calls
    * Source mapping
    * Testing
        * Find a test suite for JavaScript

