# Lisp Machine - MoonPilot

A Lisp interpreter implementation in MoonBit, featuring S-expression parsing and evaluation with support for arithmetic operations, variables, functions, and control flow.

## Features

- **S-expression parsing**: Robust tokenization and parsing of Lisp syntax with proper error handling
- **Arithmetic operations**: Support for `+`, `-`, `*`, `/` operations
- **Comparison operations**: Support for `=`, `<`, `>`, `<=`, `>=` comparisons  
- **Variables**: Define and use variables with `define`
- **Functions**: Create lambda functions and call them
- **Control flow**: Conditional expressions with `if`
- **Sequential evaluation**: Multiple expressions with `begin`
- **Unicode support**: Full support for Unicode characters including emojis

## Usage

### Basic Arithmetic

```moonbit
test {
  let result = evaluate(parse_sexp("(+ 1 2 3)"))
  assert_eq(result, Sexp::Atom("6"))
  
  let nested = evaluate(parse_sexp("(* (+ 2 3) (- 8 2))"))
  assert_eq(nested, Sexp::Atom("30"))
}
```

### Variables and Definitions

```moonbit
test {
  let program = "(begin (define x 10) (define y 5) (+ x y))"
  let result = evaluate(parse_sexp(program))
  assert_eq(result, Sexp::Atom("15"))
}
```

### Conditional Expressions

```moonbit
test "if conditions" {
  let condition = evaluate(parse_sexp("(if (> 5 2) 42 0)"))
  assert_eq(condition, Sexp::Atom("42"))
  
  let comparison = evaluate(parse_sexp("(= 5 5)"))
  assert_eq(comparison, Sexp::Atom("true"))
}
```

### Lambda Functions

```moonbit
test {
  let square_func = "(begin (define square (lambda (x) (* x x))) (square 4))"
  let result = evaluate(parse_sexp(square_func))
  assert_eq(result, Sexp::Atom("16"))
  
  // Higher-order functions
  let higher_order = "(begin (define apply-twice (lambda (f x) (f (f x)))) (define add1 (lambda (x) (+ x 1))) (apply-twice add1 5))"
  let result2 = evaluate(parse_sexp(higher_order))
  assert_eq(result2, Sexp::Atom("7"))
}
```

### Function Definition Shorthand

```moonbit
test {
  // Alternative function definition syntax
  let factorial = "(begin (define (fact n) (if (= n 0) 1 (* n (fact (- n 1))))) (fact 5))"
  let result = evaluate(parse_sexp(factorial))
  assert_eq(result, Sexp::Atom("120"))
}
```

## S-expression Parsing

The parser handles various Lisp syntax constructs:

```moonbit
test {
  // Simple expressions
  let simple = parse_sexp("(hello world)")
  assert_eq(simple, Sexp::List([Sexp::Atom("hello"), Sexp::Atom("world")]))
  
  // Nested expressions
  let nested = parse_sexp("(define (square x) (* x x))")
  assert_eq(nested, Sexp::List([
    Sexp::Atom("define"),
    Sexp::List([Sexp::Atom("square"), Sexp::Atom("x")]),
    Sexp::List([Sexp::Atom("*"), Sexp::Atom("x"), Sexp::Atom("x")])
  ]))
  
  // Unicode support
  let unicode = parse_sexp("(你好 世界 👋🏻)")
  assert_eq(unicode, Sexp::List([Sexp::Atom("你好"), Sexp::Atom("世界"), Sexp::Atom("👋🏻")]))
}
```

## Error Handling

The interpreter provides comprehensive error handling:

```moonbit
test {
  // Parse errors
  try {
    let _ = parse_sexp("(hello (world")
    fail("Should have failed with parse error")
  } catch {
    _ => () // Expected parse error
  }
  
  // Evaluation errors  
  try {
    let _ = evaluate(parse_sexp("(+ x 1)")) // unbound variable
    fail("Should have failed with unbound variable error")
  } catch {
    _ => () // Expected error for unbound variable
  }
}
```

## Architecture

The interpreter consists of two main modules:

1. **`sexp.mbt`**: S-expression parsing and tokenization
   - `Sexp` enum representing atoms and lists
   - `parse_sexp()` function for parsing strings into S-expressions
   - `tokenize()` function for lexical analysis
   - Comprehensive error handling with `ParseError` types

2. **`lisp_interpreter.mbt`**: Expression evaluation and runtime
   - `Value` enum representing runtime values (numbers, booleans, symbols, functions)
   - `Environment` for variable bindings
   - `evaluate()` function for expression evaluation
   - Built-in functions and special forms

## Data Types

### S-expressions
```moonbit
test {
  // Atoms represent symbols, numbers, and literals
  let _atom = Sexp::Atom("hello")
  
  // Lists represent function calls and data structures
  let _list = Sexp::List([Sexp::Atom("+"), Sexp::Atom("1"), Sexp::Atom("2")])
}
```

### Runtime Values
```moonbit
test {
  // The interpreter supports various value types:
  let _number = Value::Number(42)
  let _boolean = Value::Boolean(true)
  let _symbol = Value::Symbol("nil")
  // Functions store parameters, body, and closure environment
  let env = Env::builtin()
  let _func = Value::Function(["x"], parse_sexp("(* x x)"), env)
}
```

## Built-in Operations

- **Arithmetic**: `+`, `-`, `*`, `/`
- **Comparison**: `=`, `<`, `>`, `<=`, `>=`
- **Special Forms**: `if`, `define`, `lambda`, `begin`

## License

Apache-2.0
