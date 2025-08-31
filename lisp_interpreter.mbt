///|
pub(all) enum Value {
  Number(Int)
  Boolean(Bool)
  Symbol(String)
  Function(Array[String], Sexp, Env)
  BuiltinFunction(String)
} derive(Show)

///|
pub impl ToJson for Value with to_json(self) {
  match self {
    Number(n) => n.to_json()
    Boolean(b) => Json::boolean(b)
    Symbol(s) => Json::string(s)
    Function(_, _, _) => Json::string("<function>")
    BuiltinFunction(name) => Json::string("<builtin:" + name + ">")
  }
}

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
pub fn evaluate(expr : Sexp) -> Value raise Error {
  let env = Env::builtin()
  expr.eval(env)
}

///|
pub fn eval(s : String) -> Value raise Error {
  let sexp = parse_sexp(s)
  evaluate(sexp)
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
      return Function(params, body, env)
    }
    List([]) => Symbol("nil")
    List([Atom("begin"), .. expressions]) => {
      let mut result = Value::Symbol("nil")
      for expression in expressions {
        result = expression.eval(env)
      }
      result
    }
    List([Atom("define"), Atom(name), value]) => {
      let evaluated_value = value.eval(env)
      env.set(name, evaluated_value)
      Value::Symbol("ok")
    }
    List([Atom("define"), List([Atom(name), .. params_sexp]), body]) => {
      let params = []
      for param in params_sexp {
        match param {
          Atom(param) => params.push(param)
          _ =>
            raise TypeError(
              "define: function parameter must be a symbol, got: \{param}",
            )
        }
      }
      let lambda_value = Value::Function(params, body, env)
      env.set(name, lambda_value)
      Value::Symbol("ok")
    }
    List([Atom("define"), .. rest]) =>
      // TODO: report a generic syntax error  
      raise WrongArgumentCount(
        "define: expected exactly 2 arguments, got \{rest.length()}",
      )
    List([operator, .. args]) => {
      let operator_value = operator.eval(env)
      let args_value = []
      for arg in args {
        let arg_value = arg.eval(env)
        args_value.push(arg_value)
      }
      apply(operator_value, args_value)
    }
  }
}

///|
fn apply(operator : Value, args : Array[Value]) -> Value raise EvalError {
  match operator {
    Function(params, body, closure_env) => {
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
              Value::Number(n) => result += n
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
                  Value::Number(n) => result -= n
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
              Value::Number(n) => result *= n
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
                    result /= n
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
    Boolean(b) => b
    Number(n) => n != 0
    Symbol("nil") => false
    _ => true
  }
}
