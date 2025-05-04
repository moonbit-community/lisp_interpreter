// use sexp::*

///|
test "parse extra tokens" {
  let input = "(hello) world"
  @json.inspect!(parse_sexp?(input), content={
    "Err": { "$tag": "UnmatchedParens", "0": "unexpected tokens at the end" },
  })
}

///|
test "parse unexpected closing paren" {
  let input = ")hello"
  @json.inspect!(parse_sexp?(input), content={
    "Err": { "$tag": "UnexpectedParens", "0": "unexpected closing parenthesis" },
  })
}

///|
test "tokenize" {
  let input = "(hello world)"
  let tokens = tokenize(input)
  @json.inspect!(tokens, content=["(", "hello", "world", ")"])
}

///|
test "tokenize unicode" {
  let input = "(你好 世界)"
  let tokens = tokenize(input)
  @json.inspect!(tokens, content=["(", "你好", "世界", ")"])
}

///|
test "tokenize unicode emoji" {
  let input = "(👋🏻 世界)"
  let tokens = tokenize(input)
  @json.inspect!(tokens, content=["(", "👋🏻", "世界", ")"])
}

///|
test "parse simple" {
  let input = "(hello world)"
  let result = parse_sexp!(input)
  @json.inspect!(result, content={
    "$tag": "List",
    "0": [{ "$tag": "Atom", "0": "hello" }, { "$tag": "Atom", "0": "world" }],
  })
}

///|
test "parse nested" {
  let input = "(define (square x) (* x x))"
  let result = parse_sexp!(input)
  @json.inspect!(result, content={
    "$tag": "List",
    "0": [
      { "$tag": "Atom", "0": "define" },
      {
        "$tag": "List",
        "0": [{ "$tag": "Atom", "0": "square" }, { "$tag": "Atom", "0": "x" }],
      },
      {
        "$tag": "List",
        "0": [
          { "$tag": "Atom", "0": "*" },
          { "$tag": "Atom", "0": "x" },
          { "$tag": "Atom", "0": "x" },
        ],
      },
    ],
  })
}

///|
test "parse error" {
  let input = "(hello (world"
  inspect!(
    parse_sexp?(input),
    content=
      #|Err(UnmatchedParens("missing closing parenthesis"))
    ,
  )
}

///|
test "parse empty" {
  let input = ""
  @json.inspect!(parse_sexp?(input), content={
    "Err": { "$tag": "UnexpectedEOF" },
  })
}

///|
test "parse parens" {
  let input = "(hello (world))"
  let result = parse_sexp!(input)
  @json.inspect!(result, content={
    "$tag": "List",
    "0": [
      { "$tag": "Atom", "0": "hello" },
      { "$tag": "List", "0": [{ "$tag": "Atom", "0": "world" }] },
    ],
  })
}
