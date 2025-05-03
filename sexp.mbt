///|
pub(all) enum Sexp {
  Atom(String)
  List(Array[Sexp])
} derive(Show, Eq, ToJson)

///|
type! ParseError {
  UnmatchedParens(String)
  UnexpectedParens(String)
  UnexpectedEOF
} derive(Show, ToJson)

///|
pub fn parse_sexp(input : String) -> Sexp!ParseError {
  let tokens = tokenize(input)
  let (sexp, remaining) = parse_tokens!(tokens)
  if remaining.length() > 0 {
    raise ParseError::UnmatchedParens("unexpected tokens at the end")
  }
  sexp
}

///|
fn parse_tokens(tokens : Array[String]) -> (Sexp, Array[String])!ParseError {
  if tokens.length() == 0 {
    raise ParseError::UnexpectedEOF
  }
  let token = tokens[0]
  let rest_view = tokens[1:]
  let rest = Array::new()
  for t in rest_view {
    rest.push(t)
  }
  if token == "(" {
    let subexps = Array::new()
    let mut curr_tokens = rest
    while curr_tokens.length() > 0 && curr_tokens[0] != ")" {
      let (subexp, remaining) = parse_tokens!(curr_tokens)
      subexps.push(subexp)
      curr_tokens = remaining
    }
    if curr_tokens.length() == 0 {
      raise ParseError::UnmatchedParens("missing closing parenthesis")
    }
    let remaining_view = curr_tokens[1:]
    let remaining = Array::new()
    for t in remaining_view {
      remaining.push(t)
    }
    (Sexp::List(subexps), remaining)
  } else if token == ")" {
    raise ParseError::UnexpectedParens("unexpected closing parenthesis")
  } else {
    (Sexp::Atom(token), rest)
  }
}

///|
pub fn tokenize(input : String) -> Array[String] {
  let tokens = Array::new()
  let mut current_token = StringBuilder::new()
  for c in input {
    if c == '(' || c == ')' {
      if current_token.to_string().length() > 0 {
        tokens.push(current_token.to_string())
        current_token = StringBuilder::new()
      }
      // tokens.push([c].iter().to_string())
      tokens.push([c])
    } else if c == ' ' || c == '\n' || c == '\t' {
      if current_token.to_string().length() > 0 {
        tokens.push(current_token.to_string())
        current_token = StringBuilder::new()
      }
    } else {
      current_token.write_char(c)
    }
  }
  if current_token.to_string().length() > 0 {
    tokens.push(current_token.to_string())
  }
  tokens
}
