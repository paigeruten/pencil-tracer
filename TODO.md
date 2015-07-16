# TODO

* CoffeeScript
    * Tracing
        * Consistent tracing (i.e. pass the trace tests)
        * Trace each method/property definition in a class body separately
    * Variable Tracking
        * Track properties (e.g. `window.location`)
            * Special case: `@` variables
                * Special case: `@` variables as arguments
        * Track variables in loop guards (`when` clauses)
        * Function calls
* JavaScript
    * Tracing
        * `'after'` events
        * Consistent tracing (i.e. pass the trace tests)
    * Variable Tracking
        * Track properties (e.g. `window.location`)
        * Function calls
        * Return values
        * Thrown errors
    * Testing
        * Find a test suite for JavaScript

