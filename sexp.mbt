///|
pub(all) enum Sexp {
  Atom(String)
  List(Array[Sexp])
} derive(Show, Eq, ToJson)

///|
/// TODO(upstream):
/// Warning: The type 'ParseError' does not occur in public signature of 
/// current package, consider marking it as `priv`
/// The above message will be misleading because ParseError is actually used
/// in the public signature.
/// Figure out the `pub`/abstract meaning of suberror
/// This generally makes sense but doesnot make sense for suberror since
/// It is an existential type
pub suberror ParseError {
  UnmatchedParens(String)
  UnexpectedParens(String)
  UnexpectedEOF
} derive(Show, ToJson)

///|
priv enum Token {
  Lparen
  RParen
  Atom(String)
}

///|
impl ToJson for Token with to_json(self) {
  match self {
    Lparen => "("
    RParen => ")"
    Atom(s) => Json::string(s)
  }
}

///|
pub fn parse_sexp(input : String) -> Sexp raise {
  let tokens = Lexer::new(input).decode()
  let (sexp, remaining) = parse_tokens(tokens)
  guard remaining is [] else {
    raise UnmatchedParens("unexpected tokens at the end")
  }
  sexp
}

///|
fn parse_tokens(
  tokens : @array.View[Token],
) -> (Sexp, @array.View[Token]) raise ParseError {
  match tokens {
    [] => raise UnexpectedEOF
    [Lparen, .. rest] => {
      let subexps = []
      loop rest {
        [] => raise UnmatchedParens("missing closing parenthesis")
        [RParen, .. rest] => (List(subexps), rest)
        _ as r => {
          let (subexp, remaining) = parse_tokens(r)
          subexps.push(subexp)
          continue remaining
        }
      }
    }
    [RParen, ..] => raise UnexpectedParens("unexpected closing parenthesis")
    [Atom(token), .. rest] => (Sexp::Atom(token), rest)
  }
}

///|
priv struct Lexer {
  input : String
  mut pos : Int //
}

///|
fn Lexer::new(input : String) -> Lexer {
  { input, pos: 0 }
}

///|
fn Lexer::view(self : Lexer) -> StringView {
  let input = self.input
  let pos = self.pos
  input.view(start_offset=pos)
}

///|
fn Lexer::update_view(self : Lexer, view : StringView) -> Unit {
  self.pos = view.start_offset()
}

///|
fn Lexer::update_view_with_token(self : Lexer, view : StringView) -> String {
  let consumed = self.input.view(
    start_offset=self.pos,
    end_offset=view.start_offset(),
  )
  self.pos = view.start_offset()
  consumed.to_string()
}

///|
fn Lexer::decode(self : Lexer) -> Array[Token] raise {
  let tokens : Array[Token] = []
  loop self.view() {
    [] => ()
    ['(', .. rest] => {
      tokens.push(Lparen)
      continue rest
    }
    [')', .. rest] => {
      tokens.push(RParen)
      continue rest
    }
    [' ' | '\n' | '\t', .. rest] => continue rest
    ['"', ..] as view => {
      self.update_view(view) // mark theh position, do the work
      tokens.push(self.decode_string())
      continue self.view()
    }
    _ as view => {
      self.update_view(view)
      tokens.push(self.decode_atom())
      continue self.view()
    }
  }
  tokens
}

///|
fn Lexer::decode_string(self : Lexer) -> Token raise {
  // self.expect_char('"')
  let next = match self.view() {
    ['"', .. next] => next
    _ => fail("expected \" in the beginning of string")
  }
  let next = loop next {
    ['"', .. next] => next
    ['\n', ..] => fail("unexpected newline in string")
    [_, .. rest] => continue rest
    [] => fail("unexpected end of input")
  }
  Atom(self.update_view_with_token(next))
}

///|
test "decode_string" {
  fn decode_string(s) {
    Ok(Lexer::new(s).decode_string()) catch {
      Failure(err) => Err(err.split("FAILED:")[1:].to_string()) // FIXME: upstream
      err => Err(err.to_string())
    }
  }

  @json.inspect(decode_string("\"hello\""), content={ "Ok": "\"hello\"" })
  @json.inspect(decode_string("\"hello\n\""), content={
    "Err": "[\" unexpected newline in string\"]",
  })
  @json.inspect(
    decode_string(
      (
        #|"abc"
      ),
    ),
    content={ "Ok": "\"abc\"" },
  )
  @json.inspect(decode_string("\"d..\""), content={ "Ok": "\"d..\"" })
}

///|
/// TODO(upstream): fmt add `///|`
fn Lexer::decode_atom(self : Lexer) -> Token {
  let next = loop self.view() {
    [] | ['(' | ')' | ' ' | '\n' | '\t', ..] as next => next
    [_, .. rest] => continue rest
  }
  Atom(self.update_view_with_token(next))
}

///|
test "decode_atom" {
  // only toplevel can have labelled arguments  
  // fn aux(s,content~) raise{
  //   @json.inspect(s, content~)
  // }  
  fn decode_atom(s) {
    Lexer::new(s).decode_atom()
    // catch {
    //   Failure(err) => Err(err.split("FAILED:")[1:].to_string()) // FIXME: upstream
    //   err => Err(err.to_string())
    // }
  }

  @json.inspect(decode_atom("hello "), content="hello")
  @json.inspect(decode_atom("hell("), content="hell")
  @json.inspect(decode_atom("hello+ "), content="hello+")
}

///|
/// TODO(upstream):
/// support regular expression # to remove some regex
/// native support of end of input
// for input = input {
//   match input using longest {
//     (re"[ \n \t]+", rest) => continue rest
//     (re"\(", rest) => { tokens.push("("); continue rest }
//     (re"\)", rest) => { tokens.push(")"); continue rest }
//     (re"(?<id>[a-zA-Z_0-9\+\-\*]+)", rest) => {tokens.push(id.to_string()); continue rest}
//     // (re"", _) => break // empty input
//     (re"",rest) => if rest is [] {break} else {fail("Unexpected token: \"\{input}\"")}
//     _ => fail("Unexpected token: \"\{input}\"")
//   }
// }
// pub fn tokenize(input : StringView) -> Array[StringView] raise {
//   if false {
//     fail("may fail")
//   }
//   let tokens : Array[StringView] = []
//   outer~: loop input {
//     [] => ()
//     ['(', .. rest] => {
//       tokens.push("(")
//       continue rest
//     }
//     [')', .. rest] => {
//       tokens.push(")")
//       continue rest
//     }
//     [' ' | '\n' | '\t', .. rest] => continue rest
//     [_, ..] as oid =>
//       for id = oid, count = 0 {
//         match id {
//           [] | ['(' | ')' | ' ' | '\n' | '\t', ..] => {
//             tokens.push(oid.view(end_offset=count))
//             continue outer~ id
//           }
//           [c, .. rest] =>
//             continue rest, count + (if c > '\u{ffff}' { 2 } else { 1 })
//         }
//       }
//   }
//   tokens
// }
test "decode" {
  fn tokenize(s) {
    Ok(Lexer::new(s).decode()) catch {
      Failure(err) => Err(err.split("FAILED:")[1:].to_string()) // FIXME: upstream
      err => Err(err.to_string())
    }
  }

  @json.inspect(tokenize("(hello world)"), content={
    "Ok": ["(", "hello", "world", ")"],
  })
  @json.inspect(tokenize("(hello \"world\")"), content={
    "Ok": ["(", "hello", "\"world\"", ")"],
  })
  @json.inspect(tokenize("(hello \"world\")"), content={
    "Ok": ["(", "hello", "\"world\"", ")"],
  })
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

///|
test {
  fn tokenize(s) {
    Ok(Lexer::new(s).decode()) catch {
      Failure(err) => Err(err.split("FAILED:")[1:].to_string()) // FIXME: upstream
      err => Err(err.to_string())
    }
  }

  let tokens = tokenize("(begin (define x 10) (define y 5) (+ x y))")
  // let tokens = tokenize(v)
  @json.inspect(tokens, content={
    "Ok": [
      "(", "begin", "(", "define", "x", "10", ")", "(", "define", "y", "5", ")",
      "(", "+", "x", "y", ")", ")",
    ],
  })
  let tokens = tokenize("(if (> 5 2) 42 0)")
  @json.inspect(tokens, content={
    "Ok": ["(", "if", "(", ">", "5", "2", ")", "42", "0", ")"],
  })
  let tokens = tokenize("(= 5 5)")
  @json.inspect(tokens, content={ "Ok": ["(", "=", "5", "5", ")"] })
}

///|
test "tokenize" {
  let input = "(hello world)"
  let tokens = Lexer::new(input).decode()
  @json.inspect(tokens, content=["(", "hello", "world", ")"])
}

///|
test "tokenize unicode" {
  let input = "(你好 世界)"
  let tokens = Lexer::new(input).decode()
  @json.inspect(tokens, content=["(", "你好", "世界", ")"])
}

///|
test "tokenize unicode emoji" {
  let input = "(👋🏻 世界)"
  let tokens = Lexer::new(input).decode()
  @json.inspect(tokens, content=["(", "👋🏻", "世界", ")"])
}

///|
// #cfg(false)
// fn Lexer::expect_char(self : Lexer, ch : Char) -> Unit raise {
//   match self.view() {
//     [] => fail("unexpected end of input")
//     [next, .. rest] => {
//       if next != ch {
//         fail("expected char \{ch} ,but got \{next}")
//       }
//       self.update_view(rest)
//     }
//   }
// }
