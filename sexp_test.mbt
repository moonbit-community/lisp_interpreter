// use sexp::*

///|
test "parse extra tokens" {
  let input = "(hello) world"
  try @lisp_interpreter.parse_sexp(input) catch {
    @lisp_interpreter.UnmatchedParens(_) as err =>
      json_inspect(err, content=[
        "UnmatchedParens", "unexpected tokens at the end",
      ])
    err => fail("unexpected error: \{err}")
  } noraise {
    _ => fail("expected parse_sexp to raise")
  }
}

///|
test "parse unexpected closing paren" {
  let input = ")hello"
  try @lisp_interpreter.parse_sexp(input) catch {
    @lisp_interpreter.UnexpectedParens(_) as err =>
      json_inspect(err, content=[
        "UnexpectedParens", "unexpected closing parenthesis",
      ])
    err => fail("unexpected error: \{err}")
  } noraise {
    _ => fail("expected parse_sexp to raise")
  }
}

///|
test "parse simple" {
  let input = "(hello world)"
  let result = @lisp_interpreter.parse_sexp(input)
  json_inspect(result, content=["List", [["Atom", "hello"], ["Atom", "world"]]])
}

///|
test "parse nested" {
  let input = "(define (square x) (* x x))"
  let result = @lisp_interpreter.parse_sexp(input)
  json_inspect(result, content=[
    "List",
    [
      ["Atom", "define"],
      ["List", [["Atom", "square"], ["Atom", "x"]]],
      ["List", [["Atom", "*"], ["Atom", "x"], ["Atom", "x"]]],
    ],
  ])
}

///|
test "parse error" {
  let input = "(hello (world"
  try @lisp_interpreter.parse_sexp(input) catch {
    @lisp_interpreter.UnmatchedParens(_) as err =>
      inspect(
        err,
        content=(
          #|UnmatchedParens("missing closing parenthesis")
        ),
      )
    err => fail("unexpected error: \{err}")
  } noraise {
    _ => fail("expected parse_sexp to raise")
  }
}

///|
test "parse empty" {
  let input = ""
  try @lisp_interpreter.parse_sexp(input) catch {
    @lisp_interpreter.UnexpectedEOF as err =>
      json_inspect(err, content="UnexpectedEOF")
    err => fail("unexpected error: \{err}")
  } noraise {
    _ => fail("expected parse_sexp to raise")
  }
}

///|
test "parse parens" {
  let input = "(hello (world))"
  let result = @lisp_interpreter.parse_sexp(input)
  json_inspect(result, content=[
    "List",
    [["Atom", "hello"], ["List", [["Atom", "world"]]]],
  ])
}
