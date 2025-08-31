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
  let sexp = @lisp_interpreter.parse_sexp(s)
  let result = @lisp_interpreter.evaluate(sexp)
  @json.inspect(result, content?, loc~, args_loc~)
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
}

// ///|

///|
test "evaluate lambdas and function calls" {
  // Define and call a simple function
  eval_string("(begin (define square (lambda (x) (* x x))) (square 4))", content=16)

  // Use a function as an argument
  eval_string("(begin (define apply-twice (lambda (f x) (f (f x)))) (define add1 (lambda (x) (+ x 1))) (apply-twice add1 5))", content=7)
}

///|
test "environment shadowing issues - demonstrates problems" {
  // Test 1: Variable shadowing problem - function parameters overwrite globals
  // PROBLEM DEMONSTRATED: Global x is overwritten by function parameter!
  let input1 = #|(begin 
    #|    (define x 10)
    #|    (define f (lambda (x) (+ x 1)))
    #|    (f 5)
    #|    x)
  eval_string(input1, content=5) // BUG: Should be 10!

  // Test 2: Function parameter collision
  // This should return 13, but may be affected by shared environment
  let input2 = #|(begin
    #|    (define f1 (lambda (x) (* x 2)))
    #|    (define f2 (lambda (x) (+ x 10)))
    #|    (begin
    #|      (f1 5)
    #|      (f2 3)))
  eval_string(input2, content=13) // Works by accident, but environment is polluted
}
