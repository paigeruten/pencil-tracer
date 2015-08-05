# TODO

* CoffeeScript
    * Track variables in deferrals for Iced CoffeeScript
    * Track functions called with the `new` operator (we currently track `new Array()` (a `Call`), but not `new Array().length` (an `Op`))
    * Track soaked functions (e.g. `func?()`, `obj?.a().b()`)
    * Rewrite Iced parts to instrument before the Iced AST transform
* JavaScript
    * Find a test suite for JavaScript
* New features
    * Tracked variables should have id's or scope id's, to know whether two variables with the same name are the same variable or just in different scopes
    * Multiple function calls to the same function being tracked in the same event should be able to be differentiated. Maybe include their locations? Or at least guarantee they're tracked in the same order as they appear in the code.
* Documentation

