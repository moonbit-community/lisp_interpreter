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
fn parse_tokens(
  tokens : @array.View[@string.View]
) -> (Sexp, @array.View[@string.View])!ParseError {
  match tokens {
    [] => raise ParseError::UnexpectedEOF
    [token, .. rest] =>
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
        (Sexp::Atom(token.to_string()), rest)
      }
  }
}

///|
pub fn tokenize(input : @string.View) -> Array[@string.View] {
  let tokens : Array[@string.View] = []
  outer~: loop input {
    [] => ()
    ['(', .. rest] => {
      tokens.push("(")
      continue rest
    }
    [')', .. rest] => {
      tokens.push(")")
      continue rest
    }
    // [ .. "("  , .. rest] we need support 
    // [ .. "xx" as c ] so that we can get the view
    // but it is constant so it does not matter that much?

    [' ' | '\n' | '\t', .. rest] => continue rest
    [_, ..] as oid =>
      for id = oid, count = 0 {
        match id {
          [] | ['(' | ')' | ' ' | '\n' | '\t', ..] => {
            tokens.push(oid.view(end_offset=count))
            continue outer~ id
          }
          [_, .. rest] =>
            // count += 1 // this is incorrect, we should use the offset
            continue rest, count + 1
        }
      }
  }
  tokens
}
