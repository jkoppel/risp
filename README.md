Interpreter for a Lisp, mostly based on Common Lisp, but with a few ideas taken from Paul Graham's early writings on Arc. The main feature of interest is that calls to undefined functions will naturally be treated as Ruby method calls to the first argument, making this in some ways a Lisp syntax for Ruby.

The parser is recursive-descent with dynamic dispatch based on the first charcter seen. The upside to this is that reader-macros were easy to implement. The downside is that programs which end in whitespace or comments will not parse.

This was written in 2007 (age 15). I attempted to implement macros the same way as in Arc, by overriding the lisp-eval function in Lisp itself. Doing this properly with integration with the Ruby method call fallback required a way to check what class/module a method was defined in, a feature not available until Ruby 1.9, and hence I left this project.

