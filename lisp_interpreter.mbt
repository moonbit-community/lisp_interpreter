///|
pub(all) enum Value {
  Number(Int)
  Boolean(Bool)
  Symbol(String)
  Function(Array[String], Sexp, Env)
  BuiltinFunction(String)
} derive(Show)

///|
pub struct Env(Map[String, Value]) derive(Show)

// ///|
// fn Environment::new() -> Environment {
//   {}
// }

///|
#alias(op_set)
fn Env::set(self : Env, key : String, value : Value) -> Unit {
  self.0[key] = value
}

///|
fn Env::get(self : Env, key : String) -> Value? {
  self.0.get(key)
}

///|
priv suberror EvalError {
  // NotAList(String)
  UnboundSymbol(String)
  NotAFunction(String)
  WrongArgumentCount(String)
  TypeError(String)
} derive(Show)

///|
pub fn Env::builtin() -> Self {
  {
    ".": BuiltinFunction("dummy"),
    "+": BuiltinFunction("+"),
    "-": BuiltinFunction("-"),
    "*": BuiltinFunction("*"),
    "/": BuiltinFunction("/"),
    "=": BuiltinFunction("="),
    "<": BuiltinFunction("<"),
    ">": BuiltinFunction(">"),
    "<=": BuiltinFunction("<="),
    ">=": BuiltinFunction(">="),
  }
}

///|
pub fn evaluate(expr : Sexp) -> Sexp raise Error {
  let env = Env::builtin()
  let result = expr.eval(env)
  sexp_from_value(result)
}

///|
fn Sexp::eval(self : Sexp, env : Env) -> Value raise EvalError {
  match self {
    // Atoms: handle literals and variables
    Atom("true") => Value::Boolean(true)
    Atom("false") => Value::Boolean(false)
    Atom(token) => {
      // Try parsing as an integer
      if token is ['0'..='9', ..] || token is ['-', '0'..='9', ..] {
        try {
          let num = @strconv.parse_int(token)
          return Value::Number(num)
        } catch {
          _ => () // Not a number, continue
        }
      }

      // Try parsing as a boolean
      match token {
        // Look up variables in the environment
        _ => {
          guard env.get(token) is Some(value) else {
            raise UnboundSymbol("Unbound variable: \{token}")
          }
          return value
        }
      }
    }

    // Lists: procedure calls, special forms, etc.
    List([Atom("if"), condition, then_, else_, .. rest]) => {
      guard rest is [] else {
        raise WrongArgumentCount(
          "if: expected exactly 3 arguments, got \{rest.length() + 3}",
        )
      }
      let condition_value = condition.eval(env)
      if is_truthy(condition_value) {
        then_.eval(env)
      } else {
        else_.eval(env)
      }
    }
    // List([Atom("define"), Atom(name), value, ..rest]) => {
    //   guard rest is [] else {
    //     raise WrongArgumentCount("'define' requires exactly 2 arguments")
    //   }
    //   let value = eval(value, env)
    //   env[name] =value
    //   return Value::Symbol("ok")
    // }
    List([Atom("lambda"), List(params_sexp), body, .. rest]) => {
      guard rest is [] else {
        raise WrongArgumentCount(
          "lambda: expected exactly 2 arguments, got \{rest.length() + 2}",
        )
      }
      let params = []
      for param in params_sexp {
        match param {
          Atom(name) => params.push(name)
          _ =>
            raise TypeError("lambda: parameter must be a symbol, got: \{param}")
        }
      }
      return Value::Function(params, body, env)
    }
    List([]) => Symbol("nil")
    List([Atom("begin"), .. expressions]) => {
      let mut result = Value::Symbol("nil")
      for expression in expressions {
        result = expression.eval(env)
      }
      result
    }
    List(elements) => {

      // Get the first element (operator or special form)
      let first = elements[0]

      // Special forms
      match first {
        Atom("define") => {
          guard elements.length() == 3 else {
            raise WrongArgumentCount(
              "define: expected exactly 2 arguments, got \{elements.length() - 1}",
            )
          }
          match elements[1] {
            Atom(name) => {
              let value = elements[2].eval(env)
              env.set(name, value)
              Value::Symbol("ok")
            }
            List(func_parts) => {
              // Function definition shorthand: (define (name arg1 arg2) body)
              guard func_parts.length() > 0 else {
                raise TypeError("define: invalid function definition syntax")
              }
              match func_parts[0] {
                Atom(name) => {
                  // Extract parameters
                  let params = []
                  for i = 1; i < func_parts.length(); i = i + 1 {
                    match func_parts[i] {
                      Atom(param) => params.push(param)
                      _ =>
                        raise TypeError(
                          "define: function parameter must be a symbol, got: \{func_parts[i]}",
                        )
                    }
                  }

                  // Create a lambda function and bind it to the name
                  let lambda_value = Value::Function(params, elements[2], env)
                  env.set(name, lambda_value)
                  Value::Symbol("ok")
                }
                _ =>
                  raise TypeError(
                    "define: function name must be a symbol, got: \{func_parts[0]}",
                  )
              }
            }
            // _ => raise TypeError("First argument to 'define' must be a symbol")
          }
        }
        // Evaluate a function call
        _ => {
          // Evaluate the operator
          let operator = elements[0].eval(env)

          // Evaluate the arguments
          let args = []
          for i = 1; i < elements.length(); i = i + 1 {
            let arg = elements[i].eval(env)
            args.push(arg)
          }
          apply(operator, args)
        }
      }
    }
  }
}

///|
fn apply(operator : Value, args : Array[Value]) -> Value raise EvalError {
  match operator {
    Value::Function(params, body, closure_env) => {
      // Create a new environment with the closure's environment as parent
      let call_env = closure_env

      // Bind arguments to parameters
      guard params.length() == args.length() else {
        raise WrongArgumentCount(
          "Expected \{params.length()} arguments, got \{args.length()}",
        )
      }
      for i = 0; i < params.length(); i = i + 1 {
        call_env.set(params[i], args[i])
      }

      // Evaluate the body in the new environment
      body.eval(call_env)
    }
    BuiltinFunction(name) =>
      match name {
        "+" => {
          let mut result = 0
          for arg in args {
            match arg {
              Value::Number(n) => result = result + n
              _ => raise TypeError("+: expected number, got: \{arg}")
            }
          }
          Value::Number(result)
        }
        "-" => {
          guard args.length() > 0 else {
            raise WrongArgumentCount("-: expected at least 1 argument, got 0")
          }
          match args[0] {
            Value::Number(first) => {
              if args.length() == 1 {
                return Value::Number(-first)
              }
              let mut result = first
              for i = 1; i < args.length(); i = i + 1 {
                match args[i] {
                  Value::Number(n) => result = result - n
                  _ => raise TypeError("-: expected number, got: \{args[0]}")
                }
              }
              Value::Number(result)
            }
            _ => raise TypeError("'-' expects numeric arguments")
          }
        }
        "*" => {
          let mut result = 1
          for arg in args {
            match arg {
              Value::Number(n) => result = result * n
              _ => raise TypeError("*: expected number, got: \{arg}")
            }
          }
          Value::Number(result)
        }
        "/" => {
          guard args.length() > 0 else {
            raise WrongArgumentCount("/: expected at least 1 argument, got 0")
          }
          match args[0] {
            Value::Number(first) => {
              if args.length() == 1 {
                return Value::Number(1 / first)
              }
              let mut result = first
              for i = 1; i < args.length(); i = i + 1 {
                match args[i] {
                  Value::Number(n) => {
                    guard n != 0 else { raise TypeError("/: division by zero") }
                    result = result / n
                  }
                  _ => raise TypeError("/: expected number, got: \{args[i]}")
                }
              }
              Value::Number(result)
            }
            _ => raise TypeError("/: expected number, got: \{args[0]}")
          }
        }

        // Comparison operators
        "=" => {
          guard args.length() == 2 else {
            raise WrongArgumentCount(
              "=: expected exactly 2 arguments, got \{args.length()}",
            )
          }
          match (args[0], args[1]) {
            (Value::Number(a), Value::Number(b)) => Value::Boolean(a == b)
            _ =>
              raise TypeError(
                "=: expected numbers, got: \{args[0]} and \{args[1]}",
              )
          }
        }
        "<" => {
          guard args.length() == 2 else {
            raise WrongArgumentCount(
              "<: expected exactly 2 arguments, got \{args.length()}",
            )
          }
          match (args[0], args[1]) {
            (Value::Number(a), Value::Number(b)) => Value::Boolean(a < b)
            _ =>
              raise TypeError(
                "<: expected numbers, got: \{args[0]} and \{args[1]}",
              )
          }
        }
        ">" => {
          guard args.length() == 2 else {
            raise WrongArgumentCount(
              ">: expected exactly 2 arguments, got \{args.length()}",
            )
          }
          match (args[0], args[1]) {
            (Value::Number(a), Value::Number(b)) => Value::Boolean(a > b)
            _ =>
              raise TypeError(
                ">: expected numbers, got: \{args[0]} and \{args[1]}",
              )
          }
        }
        _ => raise NotAFunction("unknown builtin function: \{name}")
      }
    _ => raise NotAFunction("not a function: \{operator}")
  }
}

///|
fn is_truthy(val : Value) -> Bool {
  match val {
    Value::Boolean(b) => b
    Value::Number(n) => n != 0
    Value::Symbol("nil") => false
    _ => true
  }
}

///|
fn sexp_from_value(val : Value) -> Sexp {
  match val {
    Value::Number(n) => Sexp::Atom(n.to_string())
    Value::Boolean(b) => Sexp::Atom(b.to_string())
    Value::Symbol(s) => Sexp::Atom(s)
    Value::Function(_, _, _) => Sexp::Atom("<function>")
    Value::BuiltinFunction(name) => Sexp::Atom("<builtin:" + name + ">")
  }
}
