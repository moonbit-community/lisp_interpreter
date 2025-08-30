// use sexp::*

///|
test "parse extra tokens" {
  let input = "(hello) world"
  @json.inspect(try? @lisp_interpreter.parse_sexp(input), content={
    "Err": ["UnmatchedParens", "unexpected tokens at the end"],
  })
}

///|
test "parse unexpected closing paren" {
  let input = ")hello"
  @json.inspect(try? @lisp_interpreter.parse_sexp(input), content={
    "Err": ["UnexpectedParens", "unexpected closing parenthesis"],
  })
}

///|
test "parse simple" {
  let input = "(hello world)"
  let result = @lisp_interpreter.parse_sexp(input)
  @json.inspect(result, content=["List", [["Atom", "hello"], ["Atom", "world"]]])
}

///|
test "parse nested" {
  let input = "(define (square x) (* x x))"
  let result = @lisp_interpreter.parse_sexp(input)
  @json.inspect(result, content=[
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
  inspect(
    try? @lisp_interpreter.parse_sexp(input),
    content=(
      #|Err(UnmatchedParens("missing closing parenthesis"))
    ),
  )
}

///|
test "parse empty" {
  let input = ""
  @json.inspect(try? @lisp_interpreter.parse_sexp(input), content={
    "Err": "UnexpectedEOF",
  })
}

///|
test "parse parens" {
  let input = "(hello (world))"
  let result = @lisp_interpreter.parse_sexp(input)
  @json.inspect(result, content=[
    "List",
    [["Atom", "hello"], ["List", [["Atom", "world"]]]],
  ])
}
