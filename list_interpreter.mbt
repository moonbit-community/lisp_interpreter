///|
pub(all) enum Value {
  Number(Int)
  Boolean(Bool)
  Symbol(String)
  Function(Array[String], Sexp, Environment)
  BuiltinFunction(String)
}

///|
pub struct Environment {
  bindings : Map[String, Value]
}

///| Implement Show for Environment to satisfy Value's Show derivation
///
pub impl Show for Environment with output(_, logger) {
  logger.write_string("{...}")
}

///|
fn Environment::new() -> Environment {
  { bindings: {} }
}

///|
fn Environment::set(self : Environment, key : String, value : Value) -> Unit {
  self.bindings[key] = value
}

///|
fn Environment::get(self : Environment, key : String) -> Value? {
  self.bindings.get(key)
}

///|
priv suberror EvalError {
  // NotAList(String)
  UnboundSymbol(String)
  NotAFunction(String)
  WrongArgumentCount(String)
  TypeError(String)
} derive(Show)

///| Implement Show for Value
///
pub impl Show for Value with output(self, logger) {
  match self {
    Value::Number(n) => logger.write_string(n.to_string())
    Value::Boolean(b) => logger.write_string(b.to_string())
    Value::Symbol(s) => logger.write_string(s)
    Value::Function(_, _, _) => logger.write_string("<function>")
    Value::BuiltinFunction(name) =>
      logger.write_string("<builtin:" + name + ">")
  }
}

///|
pub fn create_standard_env() -> Environment {
  let env = Environment::new()

  // Arithmetic operations
  env.set(".", Value::BuiltinFunction("dummy"))
  env.set("+", Value::BuiltinFunction("+"))
  env.set("-", Value::BuiltinFunction("-"))
  env.set("*", Value::BuiltinFunction("*"))
  env.set("/", Value::BuiltinFunction("/"))

  // Comparison operations
  env.set("=", Value::BuiltinFunction("="))
  env.set("<", Value::BuiltinFunction("<"))
  env.set(">", Value::BuiltinFunction(">"))
  env.set("<=", Value::BuiltinFunction("<="))
  env.set(">=", Value::BuiltinFunction(">="))
  env
}

///|
pub fn evaluate(expr : Sexp) -> Sexp raise Error {
  let env = create_standard_env()
  let result = eval(expr, env)
  sexp_from_value(result)
}

///|
fn eval(expr : Sexp, env : Environment) -> Value raise EvalError {
  match expr {
    // Atoms: handle literals and variables
    Sexp::Atom(token) => {
      // Try parsing as an integer
      if token is ['0'..='9', ..] || token is ['-', '0'..='9', ..] {
        try {
          let num = string_to_int(token)
          return Value::Number(num)
        } catch {
          _ => () // Not a number, continue
        }
      }

      // Try parsing as a boolean
      match token {
        "true" => return Value::Boolean(true)
        "false" => return Value::Boolean(false)
        // Look up variables in the environment
        _ => {
          guard env.get(token) is Some(value) else {
            raise UnboundSymbol("Unbound variable: " + token)
          }
          return value
        }
      }
    }

    // Lists: procedure calls, special forms, etc.
    Sexp::List(elements) => {
      guard elements.length() > 0 else {
        return Value::Symbol("nil") // Empty list evaluates to nil
      }

      // Get the first element (operator or special form)
      let first = elements[0]

      // Special forms
      match first {
        Sexp::Atom("if") => {
          guard elements.length() == 4 else {
            raise WrongArgumentCount("'if' requires exactly 3 arguments")
          }
          let condition = eval(elements[1], env)
          let is_true = is_truthy(condition)
          if is_true {
            return eval(elements[2], env)
          } else {
            return eval(elements[3], env)
          }
        }
        Sexp::Atom("define") => {
          guard elements.length() == 3 else {
            raise WrongArgumentCount("'define' requires exactly 2 arguments")
          }
          match elements[1] {
            Sexp::Atom(name) => {
              let value = eval(elements[2], env)
              env.set(name, value)
              return Value::Symbol("ok")
            }
            Sexp::List(func_parts) => {
              // Function definition shorthand: (define (name arg1 arg2) body)
              guard func_parts.length() > 0 else {
                raise TypeError("Invalid function definition")
              }
              match func_parts[0] {
                Sexp::Atom(name) => {
                  // Extract parameters
                  let params = []
                  for i = 1; i < func_parts.length(); i = i + 1 {
                    match func_parts[i] {
                      Sexp::Atom(param) => params.push(param)
                      _ =>
                        raise TypeError("Function parameter must be a symbol")
                    }
                  }

                  // Create a lambda function and bind it to the name
                  let lambda_value = Value::Function(params, elements[2], env)
                  env.set(name, lambda_value)
                  return Value::Symbol("ok")
                }
                _ => raise TypeError("Function name must be a symbol")
              }
            }
            // _ => raise TypeError("First argument to 'define' must be a symbol")
          }
        }
        Sexp::Atom("lambda") => {
          guard elements.length() == 3 else {
            raise WrongArgumentCount("'lambda' requires exactly 2 arguments")
          }

          // Extract parameters
          match elements[1] {
            Sexp::List(params_sexp) => {
              let params = []
              for param in params_sexp {
                match param {
                  Sexp::Atom(name) => params.push(name)
                  _ => raise TypeError("Lambda parameter must be a symbol")
                }
              }
              return Value::Function(params, elements[2], env)
            }
            _ => raise TypeError("Lambda parameters must be a list")
          }
        }
        Sexp::Atom("begin") => {
          let mut result = Value::Symbol("nil")

          // Evaluate each expression in sequence, return the last result
          for i = 1; i < elements.length(); i = i + 1 {
            result = eval(elements[i], env)
          }
          return result
        }

        // Evaluate a function call
        _ => {
          // Evaluate the operator
          let operator = eval(elements[0], env)

          // Evaluate the arguments
          let args = []
          for i = 1; i < elements.length(); i = i + 1 {
            let arg = eval(elements[i], env)
            args.push(arg)
          }
          apply(operator, args)
        }
      }
    }
  }
}

///|
fn string_to_int(s : String) -> Int raise Failure {
  let mut result = 0
  let mut is_negative = false
  if s is ['-', ..] {
    is_negative = true
    // Continue processing from index 1, skipping the '-' sign
    let mut i = 1
    while i < s.length() {
      let char = s[i]
      if char is ('0'..='9') {
        let digit = char - '0'
        result = result * 10 + digit
      } else {
        fail("Invalid integer: " + s)
      }
      i = i + 1
    }
  } else {
    // Process a positive number
    let mut i = 0
    while i < s.length() {
      let char = s[i]
      if char is ('0'..='9') {
        let digit = char - '0'
        result = result * 10 + digit
      } else {
        fail("Invalid integer: " + s)
      }
      i = i + 1
    }
  }
  if is_negative {
    result = -result
  }
  result
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
          "Expected " +
          params.length().to_string() +
          " arguments, got " +
          args.length().to_string(),
        )
      }
      for i = 0; i < params.length(); i = i + 1 {
        call_env.set(params[i], args[i])
      }

      // Evaluate the body in the new environment
      eval(body, call_env)
    }
    Value::BuiltinFunction(name) =>
      match name {
        "+" => {
          let mut result = 0
          for arg in args {
            match arg {
              Value::Number(n) => result = result + n
              _ => raise TypeError("'+' expects numeric arguments")
            }
          }
          Value::Number(result)
        }
        "-" => {
          guard args.length() > 0 else {
            raise WrongArgumentCount("'-' requires at least one argument")
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
                  _ => raise TypeError("'-' expects numeric arguments")
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
              _ => raise TypeError("'*' expects numeric arguments")
            }
          }
          Value::Number(result)
        }
        "/" => {
          guard args.length() > 0 else {
            raise WrongArgumentCount("'/' requires at least one argument")
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
                    guard n != 0 else { raise TypeError("Division by zero") }
                    result = result / n
                  }
                  _ => raise TypeError("'/' expects numeric arguments")
                }
              }
              Value::Number(result)
            }
            _ => raise TypeError("'/' expects numeric arguments")
          }
        }

        // Comparison operators
        "=" => {
          guard args.length() == 2 else {
            raise WrongArgumentCount("'=' requires exactly 2 arguments")
          }
          match (args[0], args[1]) {
            (Value::Number(a), Value::Number(b)) => Value::Boolean(a == b)
            _ => raise TypeError("'=' expects numeric arguments")
          }
        }
        "<" => {
          guard args.length() == 2 else {
            raise WrongArgumentCount("'<' requires exactly 2 arguments")
          }
          match (args[0], args[1]) {
            (Value::Number(a), Value::Number(b)) => Value::Boolean(a < b)
            _ => raise TypeError("'<' expects numeric arguments")
          }
        }
        ">" => {
          guard args.length() == 2 else {
            raise WrongArgumentCount("'>' requires exactly 2 arguments")
          }
          match (args[0], args[1]) {
            (Value::Number(a), Value::Number(b)) => Value::Boolean(a > b)
            _ => raise TypeError("'>' expects numeric arguments")
          }
        }
        _ => raise NotAFunction("Unknown builtin function: " + name)
      }
    _ => raise NotAFunction("Not a function")
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
