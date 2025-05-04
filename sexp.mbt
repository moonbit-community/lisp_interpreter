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
  guard remaining is [] else {
    raise UnmatchedParens("unexpected tokens at the end")
  }
  sexp
}

///|
fn parse_tokens(
  tokens : @array.View[@string.View]
) -> (Sexp, @array.View[@string.View])!ParseError {
  match tokens {
    [] => raise UnexpectedEOF
    ["(", .. rest] => {
      let subexps = []
      loop rest {
        [] => raise UnmatchedParens("missing closing parenthesis")
        [")", .. rest] => (List(subexps), rest)
        _ as r => {
          let (subexp, remaining) = parse_tokens!(r)
          subexps.push(subexp)
          continue remaining
        }
      }
    }
    [")", ..] => raise UnexpectedParens("unexpected closing parenthesis")
    [token, .. rest] => (Sexp::Atom(token.to_string()), rest)
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
    [' ' | '\n' | '\t', .. rest] => continue rest
    [_, ..] as oid =>
      for id = oid, count = 0 {
        match id {
          [] | ['(' | ')' | ' ' | '\n' | '\t', ..] => {
            tokens.push(oid.view(end_offset=count))
            continue outer~ id
          }
          [c, .. rest] =>
            continue rest, count + (if c > '\u{ffff}' { 2 } else { 1 })
        }
      }
  }
  tokens
}

// [ .. "("  , .. rest] we need support 
// [ .. "xx" as c ] so that we can get the view
// but it is constant so it does not matter that much?
// let mut curr_tokens = rest
// while curr_tokens is [next, .. _] && next != ")" {
//   let (subexp, remaining) = parse_tokens!(curr_tokens)
//   subexps.push(subexp)
//   curr_tokens = remaining
// }
// TODO: finish for loop is scope issue
// guard curr_tokens is [_, .. remaining_view] else {
//   raise UnmatchedParens("missing closing parenthesis")
// }
// (Sexp::List(subexps), remaining_view)
