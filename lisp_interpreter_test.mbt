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
  @json.inspect(@lisp_interpreter.eval("(+ 1 2)"), content=["Number", 3])
  @json.inspect(@lisp_interpreter.eval("(- 5 2)"), content=["Number", 3])
  @json.inspect(@lisp_interpreter.eval("(* 2 3)"), content=["Number", 6])
  @json.inspect(@lisp_interpreter.eval("(/ 10 2)"), content=["Number", 5])

  // Nested expressions
  @json.inspect(@lisp_interpreter.eval("(+ 1 (* 2 3))"), content=["Number", 7])
  @json.inspect(@lisp_interpreter.eval("(* (+ 2 3) (- 8 2))"), content=[
    "Number", 30,
  ])
  @json.inspect(@lisp_interpreter.eval("(/ (+ 8 4) 3)"), content=["Number", 4])
}

///|
test "evaluate variables and definitions" {
  let input = "(begin (define x 10) (+ x 5))"
  @json.inspect(@lisp_interpreter.eval(input), content=["Number", 15])
  // let sexp = @lisp_interpreter.parse_sexp(input)
  // let result = @lisp_interpreter.evaluate(sexp)
  // match result {
  //   @lisp_interpreter.Sexp::Atom(value) => assert_eq(value, "15")
  //   _ => fail("Expected atom result, got: " + Show::to_string(result))
  // }
}

///|
#callsite(autofill(args_loc, loc))
fn eval_string(
  s : String,
  content? : Json,
  loc~ : SourceLoc,
  args_loc~ : ArgsLoc,
) -> Unit raise {
  @json.inspect(@lisp_interpreter.eval(s), content?, loc~, args_loc~)
}

///|
test "evaluate conditions" {
  @json.inspect(@lisp_interpreter.eval("(if (> 5 2) 1 0)"), content=1)
  @json.inspect(@lisp_interpreter.eval("(if (< 5 2) 1 0)"), content=0)
  @json.inspect(@lisp_interpreter.eval("(if (= 5 5) 1 0)"), content=1)
  // Test comparison and logical operators
  eval_string("(> 5 2)", content=true)
  eval_string("(< 5 2)", content=false)
  eval_string("(= 5 5)", content=true)
  eval_string("(= 5 2)", content=false)
}

// ///|

///|
test "evaluate lambdas and function calls" {
  fn evaluate_string(input : String) raise Error {
    let sexp = @lisp_interpreter.parse_sexp(input)
    @lisp_interpreter.evaluate(sexp)
    // match result {
    //   @lisp_interpreter.Sexp::Atom(value) =>
    //     @strconv.parse(value) catch {
    //       _ => raise Failure("Expected integer result, got: " + value)
    //     }
    //   _ =>
    //     raise Failure("Expected atom result, got: " + Show::to_string(result))
    // }
  }

  // Define and call a simple function
  let input = "(begin (define square (lambda (x) (* x x))) (square 4))"
  @json.inspect(evaluate_string(input), content=["Number", 16])

  // Use a function as an argument
  let input2 = "(begin (define apply-twice (lambda (f x) (f (f x)))) (define add1 (lambda (x) (+ x 1))) (apply-twice add1 5))"
  @json.inspect(evaluate_string(input2), content=["Number", 7])
}

///|
test "environment shadowing issues - demonstrates problems" {
  // Test 1: Variable shadowing problem - function parameters overwrite globals
  let input1 =
    #|(begin 
    #|    (define x 10)
    #|    (define f (lambda (x) (+ x 1)))
    #|    (f 5)
    #|    x)
  let sexp1 = @lisp_interpreter.parse_sexp(input1)
  let result1 = @lisp_interpreter.evaluate(sexp1)

  // This test shows the problem: x should still be 10, but might be 5
  // due to environment mutation
  // PROBLEM DEMONSTRATED: Global x is overwritten by function parameter!
  @json.inspect(result1, content=["Atom", "5"]) // BUG: Should be ["Atom", "10"]!

  // Test 2: Function parameter collision
  let input2 =
    #|(begin
    #|    (define f1 (lambda (x) (* x 2)))
    #|    (define f2 (lambda (x) (+ x 10)))
    #|    (begin
    #|      (f1 5)
    #|      (f2 3)))
  let sexp2 = @lisp_interpreter.parse_sexp(input2)
  let result2 = @lisp_interpreter.evaluate(sexp2)

  // This should return 13, but may be affected by shared environment
  @json.inspect(result2, content=["Atom", "13"]) // Works by accident, but environment is polluted
}
