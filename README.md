
# easy-macros: An easy way to write 90% of your macros

[![tdrhq](https://circleci.com/gh/tdrhq/easy-macros.svg?style=shield)](https://app.circleci.com/pipelines/github/tdrhq/easy-macros?branch=main)

Easy-macros help you write macros of this form:

```lisp
  (with-<something> (...args...)
     ...body...)
```

Under the hood, this automates the call-with pattern.

## Examples

Let's rewrite some well known examples to show what we mean.

### ignore-errors

First let's see how we might write `ignore-errors` the Old-Fashioned
way:

```lisp
(defmacro custom-ignore-errors (&body body)
  `(handler-case
     (progn ,@body)
    (error () nil)))
```

Not too bad, but it's error-prone. You might forget to use a `,`, you
might forget to wrap body in `progn` etc. But worst, if you change the
definition of `custom-ignore-errors`, you will have to recompile all
the functions that use it.

You can avoid some of these issues by using the CALL-WITH pattern:

```lisp
(defmacro custom-ignore-errors (&body body)
  `(call-custom-ignore-errors (lambda () ,@body)))

(defun call-custom-ignore-errors (fn)
  (handler-case
    (funcall fn)
   (error () nil)))
```

Now most of the logic is inside a non-backticked function. But there's
still some backquoting and macro expansion we need to do which is
error-prone, and it's also very verbose for simple macros.

Use `def-easy-macro` to essentially automate this process:

```lisp
(def-easy-macro custom-ignore-errors (&fn fn)
  (handler-case
     (funcall fn)
    (error () nil)))
```

This `custom-ignore-errors` has a slightly different API though:

```lisp
(custom-ignore-errors ()
  ...body...)
```

All easy-macros takes a second list for arguments. This is true even
if it takes no arguments and only a body.

Notice a few things:
* We don't use backticks anywhere
* Instead of a body, we get a lambda function. This function is provided by the `&fn` argument.
* If you redefine custom-ignore-errors, all callers of the macro will
  point to the new code, unlike with regular macros. (With some caveats! See below.)

We don't need to use `funcall` by the way, the following is equivalent:

```lisp
(def-easy-macro custom-ignore-errors (&fn fn)
  (handler-case
     (fn)
    (error () nil)))
```

We're still figuring out which one we like better. This version
obviously is lesser code, but it also breaks the expectation that
arguments in the lambda-list are variables. But anyway, moving on to
next examples.


### with-open-file

```lisp
(def-easy-macro with-custom-open-file (&binding stream file &rest args &fn fn)
  (let ((stream (apply #'open file args)))
    (unwind-protect
       (funcall fn stream)
      (close stream))))
```

This can be used almost exactly like with-open-file.

Notice a few things:
* We don't use backticks anywhere
* This function takes one argument. easy-macro knows this based on the
  `&binding` argument, unlike the previous example.

### uiop:with-temporary-file

```lisp
(def-easy-macro my-with-custom-temporary-file (&key &binding stream &binding pathname prefix suffix &fn)
   ;; ... you get the idea
    (funcall fn my-stream my-pathname))
```

I didn't build out the example completely, but I wanted to show you
how you could write more complex arguments in the macro.

All the arguments named with `&binding` are not part of argument-list,
they will be sequentially bound to the `&fn` body function. The rest
of expressions form the lambda-list for the argument-list.

### maplist

Common Lisp comes with `dolist`, but not a `maplist`. Let's implement
a quick `maplist` macro using `loop`:

```lisp
(def-easy-macro maplist (&binding x list &fn fn)
  (loop for value in list collect (funcall fn value))
```

Before `def-easy-macro` this would've been too much work to define for
something simple. With `def-easy-macro` it's just as easy to work with
as any regular function, so you tend to macrofy even tiny abstractions
like this.


## Caveats with redefinitions

Most redefinitions will automatically be applied to all callers. If
you change the lambda-list (either `&binding` or otherwise), the new
definition may not be compatible.

## Installation

We're waiting on this to be part of the next Quicklisp distribution,
in the meantime you can use quick-patch to install:

```lisp
(ql:quickload :quick-patch)
(quick-patch:register "https://github.com/tdrhq/easy-macros.git" "main")
(quick-patch:checkout-all ".quick-patch/")
```

## TODO

This library is NOT very polished.

However, even with its limited polish it's been ridiculously useful in
my work, so I thought I should put it out there and accept feedback
and pull requests. There are few things that I'd personally like to see:

* Less brittle lambda-list parsing: currently it's really hacky
* A way to implement macros of the form:
```lisp
(def-stuff my-stuff (...)
  ,@body)
```
* In a similar vein as above: sometimes in macros you want to pass the
  quoted symbol name instead of the evaluated expression. In theory I
  can build that...
* But I want to limit what this library does. I want to make it easy
  for somebody new to CL to write macros *most* of the time. Just
  because I can doesn't mean I should.

## Author

Arnold Noronha <arnold@screenshotbot.io>

## License

Apache License, Version 2.0
