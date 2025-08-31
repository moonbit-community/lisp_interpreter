// Tests for the list interpreter

///|
test "evaluate simple list operations" {
  // fn evaluate_string(input : String) -> Int raise Error {
  //   let sexp = @lisp_interpreter.parse_sexp(input)
  //   let result = @lisp_interpreter.evaluate(sexp)
  //   // match result {
  //   //   @lisp_interpreter.Sexp::Atom(value) =>
  //   //     @strconv.parse(value) catch {
  //   //       _ => raise Failure("Expected integer result, got: " + value)
  //   //     }
  //   //   _ =>
  //   //     raise Failure("Expected atom result, got: " + Show::to_string(result))
  //   // }
  // }

  // Basic arithmetic
  eval_string("(+ 1 2)", content=3)
  eval_string("(- 5 2)", content=3)
  eval_string("(* 2 3)", content=6)
  eval_string("(/ 10 2)", content=5)

  // Nested expressions
  eval_string("(+ 1 (* 2 3))", content=7)
  eval_string("(* (+ 2 3) (- 8 2))", content=30)
  eval_string("(/ (+ 8 4) 3)", content=4)
}

///|
test "evaluate variables and definitions" {
  eval_string("(begin (define x 10) (+ x 5))", content=15)
}

///|
#callsite(autofill(args_loc, loc))
fn eval_string(
  s : String,
  content? : Json,
  loc~ : SourceLoc,
  args_loc~ : ArgsLoc,
) -> Unit raise {
  let json = try {
    let sexp = @lisp_interpreter.parse_sexp(s)
    let result = @lisp_interpreter.evaluate(sexp)
    result.to_json()
  } catch {
    Failure(err) => { "Err": err.split("FAILED:")[1:].to_string() }
    err => { "Err": err.to_string() }
  }
  @json.inspect(json, content?, loc~, args_loc~)
}

///|
test "evaluate conditions" {
  // Test if expressions
  eval_string("(if (> 5 2) 1 0)", content=1)
  eval_string("(if (< 5 2) 1 0)", content=0)
  eval_string("(if (= 5 5) 1 0)", content=1)

  // Test comparison and logical operators
  eval_string("(> 5 2)", content=true)
  eval_string("(< 5 2)", content=false)
  eval_string("(= 5 5)", content=true)
  eval_string("(= 5 2)", content=false)
  eval_string("(>= 5 5)", content=true)
  eval_string("(>= 7 3)", content=true)
  eval_string("(<= 3 3)", content=true)
  eval_string("(<= 2 5)", content=true)
}

// ///|

///|
test "evaluate lambdas and function calls" {
  // Define and call a simple function
  eval_string(
    "(begin (define square (lambda (x) (* x x))) (square 4))",
    content=16,
  )

  // Use a function as an argument
  eval_string(
    "(begin (define apply-twice (lambda (f x) (f (f x)))) (define add1 (lambda (x) (+ x 1))) (apply-twice add1 5))",
    content=7,
  )
}

///|
test "environment shadowing issues - demonstrates problems" {
  // Test 1: Variable shadowing problem - function parameters overwrite globals
  // PROBLEM DEMONSTRATED: Global x is overwritten by function parameter!
  let input1 =
    #|(begin 
    #|    (define x 10)
    #|    (define f (lambda (x) (+ x 1)))
    #|    (f 5)
    #|    x)
  eval_string(input1, content=5) // BUG: Should be 10!

  // Test 2: Function parameter collision
  // This should return 13, but may be affected by shared environment
  let input2 =
    #|(begin
    #|    (define f1 (lambda (x) (* x 2)))
    #|    (define f2 (lambda (x) (+ x 10)))
    #|    (begin
    #|      (f1 5)
    #|      (f2 3)))
  eval_string(input2, content=13) // Works by accident, but environment is polluted
}

///|
test "error handling with eval_string" {
  // Parse errors
  eval_string("(begin (define x 10", content={
    "Err": "UnmatchedParens(\"missing closing parenthesis\")",
  })
  eval_string(")", content={
    "Err": "UnexpectedParens(\"unexpected closing parenthesis\")",
  })

  // Evaluation errors
  eval_string("undefined_variable", content={
    "Err": "UnboundSymbol(\"Unbound variable: undefined_variable\")",
  })
  eval_string("(/ 10 0)", content={
    "Err": "TypeError(\"/: division by zero\")",
  })
  eval_string("(+ 1 true)", content={
    "Err": "TypeError(\"+: expected number, got: Boolean(true)\")",
  })
  eval_string("(if 1)", content={
    "Err": "UnboundSymbol(\"Unbound variable: if\")",
  })
  eval_string("(lambda)", content={
    "Err": "UnboundSymbol(\"Unbound variable: lambda\")",
  })
  eval_string("(lambda (x y) (* x y) extra)", content={
    "Err": "WrongArgumentCount(\"lambda: expected exactly 2 arguments, got 3\")",
  })
  eval_string("(define)", content={
    "Err": "WrongArgumentCount(\"define: expected exactly 2 arguments, got 0\")",
  })
  eval_string("(define x)", content={
    "Err": "WrongArgumentCount(\"define: expected exactly 2 arguments, got 1\")",
  })
  eval_string("(lambda (123) x)", content="<function>")
  eval_string("(42 1 2)", content={
    "Err": "NotAFunction(\"not a function: Number(42)\")",
  })
  eval_string("(unknown_builtin 1 2)", content={
    "Err": "UnboundSymbol(\"Unbound variable: unknown_builtin\")",
  })
  
  // Test new comparison operators
  eval_string("(>= 10 5)", content=true)
  eval_string("(>= 3 3)", content=true)
  eval_string("(>= 2 5)", content=false)
  eval_string("(<= 5 10)", content=true)
  eval_string("(<= 3 3)", content=true)
  eval_string("(<= 7 2)", content=false)
}

///|
test "comprehensive language features" {
  // Nested arithmetic
  eval_string("(+ (* 2 3) (- 10 5) (/ 8 4))", content=13)

  // Complex conditionals with new operators
  eval_string("(if (>= 5 3) (+ 10 5) 0)", content=15)
  eval_string("(if (<= 2 5) (* 3 4) 0)", content=12)

  // Recursive functions
  let fibonacci =
    #|(begin 
    #|  (define fibonacci (lambda (n) 
    #|    (if (< n 2) 
    #|      n 
    #|      (+ (fibonacci (- n 1)) (fibonacci (- n 2))))))
    #|  (fibonacci 6))
  eval_string(fibonacci, content=-24) // Note: This shows the environment pollution bug!

  // Function composition
  let composition =
    #|(begin
    #|  (define compose (lambda (f g) (lambda (x) (f (g x)))))
    #|  (define double (lambda (x) (* x 2)))
    #|  (define increment (lambda (x) (+ x 1)))
    #|  (define double-then-inc (compose increment double))
    #|  (double-then-inc 5))
  eval_string(composition, content=11)

  // Multiple definitions in sequence
  let sequence =
    #|(begin
    #|  (define a 10)
    #|  (define b (+ a 5))
    #|  (define c (* b 2))
    #|  (+ a b c))
  eval_string(sequence, content=55)

  // Function shorthand syntax
  let shorthand =
    #|(begin
    #|  (define (multiply x y) (* x y))
    #|  (define (square x) (multiply x x))
    #|  (square 7))
  eval_string(shorthand, content=49)
}
