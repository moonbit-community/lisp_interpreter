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
    content=16)

  // Use a function as an argument
  eval_string(
    "(begin (define apply-twice (lambda (f x) (f (f x)))) (define add1 (lambda (x) (+ x 1))) (apply-twice add1 5))",
    content=7)
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
  eval_string(input1, content=10)

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
test "deep environment scoping and shadowing" {
  // Test 1: Multiple levels of shadowing
  let multilevel_shadowing =
    #|(begin
    #|  (define x 100)
    #|  (define f1 (lambda (x) (+ x 10)))
    #|  (define result1 (f1 5))
    #|  (define f2 (lambda (z) (+ z 200)))
    #|  (define result2 (f2 3))
    #|  (+ result1 result2 x))
  eval_string(multilevel_shadowing, content=318)

  // Test 2: Closure captures correct environment
  let closure_capture =
    #|(begin
    #|  (define make-counter (lambda (start)
    #|    (lambda (inc) (+ start inc))))
    #|  (define counter1 (make-counter 10))
    #|  (define counter2 (make-counter 100))
    #|  (+ (counter1 5) (counter2 7)))
  eval_string(closure_capture, content=122)

  // Test 3: Nested function calls don't interfere
  let nested_calls =
    #|(begin
    #|  (define x 1000)
    #|  (define f (lambda (x) (* x 2)))
    #|  (define g (lambda (y) (+ (f y) x)))
    #|  (g 5))
  eval_string(nested_calls, content=1010)

  // Test 4: Parameters shadow correctly in nested lambdas
  let nested_lambda_params =
    #|(begin
    #|  (define outer (lambda (x)
    #|    (lambda (x) (* x x))))
    #|  (define inner (outer 10))
    #|  (inner 7))
  eval_string(nested_lambda_params, content=49)

  // Test 5: Mutual recursion with proper scoping
  let mutual_recursion =
    #|(begin
    #|  (define even? (lambda (n)
    #|    (if (= n 0) 
    #|      true
    #|      (odd? (- n 1)))))
    #|  (define odd? (lambda (n)
    #|    (if (= n 0)
    #|      false
    #|      (even? (- n 1)))))
    #|  (if (even? 6) 1 0))
  eval_string(mutual_recursion, content=1)
}

///|
test "higher-order functions with complex scoping" {
  // Test 1: Map function implementation
  let map_impl =
    #|(begin
    #|  (define map (lambda (f lst)
    #|    (if (= lst 0)
    #|      0
    #|      (+ (f 3) (f 4)))))
    #|  (define double (lambda (x) (* x 2)))
    #|  (map double 1))
  eval_string(map_impl, content=14)

  // Test 2: Function returning function with captured environment
  let curry_test =
    #|(begin
    #|  (define curry-add (lambda (x)
    #|    (lambda (y)
    #|      (lambda (z) (+ x (+ y z))))))
    #|  (define add5 (curry-add 5))
    #|  (define add5and3 (add5 3))
    #|  (add5and3 2))
  eval_string(curry_test, content=10)

  // Test 3: Accumulator pattern with closure
  let accumulator =
    #|(begin
    #|  (define make-acc (lambda (init)
    #|    (lambda (val) (+ init val))))
    #|  (define acc1 (make-acc 10))
    #|  (define acc2 (make-acc 20))
    #|  (+ (acc1 5) (acc2 5)))
  eval_string(accumulator, content=40)
}

///|
test "recursive functions with parameter shadowing" {
  // Test 1: Factorial with shadowing
  let factorial_shadow =
    #|(begin
    #|  (define n 100)
    #|  (define factorial (lambda (n)
    #|    (if (<= n 1)
    #|      1
    #|      (* n (factorial (- n 1))))))
    #|  (define result (factorial 5))
    #|  (+ result n))
  eval_string(factorial_shadow, content=220)

  // Test 2: Tree sum with nested recursion
  let tree_sum =
    #|(begin
    #|  (define sum-to (lambda (n acc)
    #|    (if (= n 0)
    #|      acc
    #|      (sum-to (- n 1) (+ acc n)))))
    #|  (sum-to 5 0))
  eval_string(tree_sum, content=15)

  // Test 3: Nested recursive calls
  let nested_recursion =
    #|(begin
    #|  (define ackermann (lambda (m n)
    #|    (if (= m 0)
    #|      (+ n 1)
    #|      (if (= n 0)
    #|        (ackermann (- m 1) 1)
    #|        (ackermann (- m 1) (ackermann m (- n 1)))))))
    #|  (ackermann 2 2))
  eval_string(nested_recursion, content=7)
}

///|
test "edge cases for environment handling" {
  // Test 1: Empty parameter list
  let empty_params =
    #|(begin
    #|  (define no-args (lambda () 42))
    #|  (no-args))
  eval_string(empty_params, content=42)

  // Test 2: Single parameter shadowing global
  let single_param =
    #|(begin
    #|  (define a 50)
    #|  (define f (lambda (a) (* a a)))
    #|  (define result (f 3))
    #|  (+ result a))
  eval_string(single_param, content=59)

  // Test 3: Many parameters
  let many_params =
    #|(begin
    #|  (define f (lambda (a b c d e)
    #|    (+ a (+ b (+ c (+ d e))))))
    #|  (f 1 2 3 4 5))
  eval_string(many_params, content=15)

  // Test 4: Parameter named same as builtin (renamed to avoid conflict)
  let param_shadow =
    #|(begin
    #|  (define test (lambda (a b) (- a b)))
    #|  (test 10 3))
  eval_string(param_shadow, content=7)

  // Test 5: Deeply nested scopes
  let deep_nesting =
    #|(begin
    #|  (define a 1)
    #|  (define f3 (lambda (x b) (+ x b)))
    #|  (define f2 (lambda (b) (f3 10 b)))
    #|  (define f1 (lambda (a) (f2 20)))
    #|  (+ (f1 5) a))
  eval_string(deep_nesting, content=31)
}

///|
test "closure environment capture timing" {
  // Test 1: Closures see updated values (captures environment, not value)
  let capture_test1 =
    #|(begin
    #|  (define x 3)
    #|  (define f (lambda (a) (+ a x)))
    #|  (define x 2)
    #|  (f 10))
  eval_string(capture_test1, content=12) // f sees updated x=2, so 10+2=12
  
  // Test 2: Multiple redefinitions - closure sees latest
  let capture_test2 =
    #|(begin
    #|  (define y 100)
    #|  (define g (lambda () y))
    #|  (define y 200)
    #|  (define y 300)
    #|  (g))
  eval_string(capture_test2, content=300) // g sees latest y=300
  
  // Test 3: Direct closure creation
  let direct_test =
    #|(begin
    #|  (define z 1)
    #|  (define fn1 (lambda () z))
    #|  (define z 2)
    #|  (define fn2 (lambda () z))
    #|  (+ (fn1) (fn2)))
  eval_string(direct_test, content=4) // Both see updated z=2, so 2+2=4
  
  // Test 4: Closure created inside function gets forked environment  
  let nested_closure =
    #|(begin
    #|  (define w 1)
    #|  (define make-fn (lambda () (lambda () w)))
    #|  (define fn1 (make-fn))
    #|  (define w 2)
    #|  (define fn2 (make-fn))
    #|  (+ (fn1) (fn2)))
  eval_string(nested_closure, content=3) // fn1's forked env has w=1, fn2's has w=2, so 1+2=3
}

///|
test "define vs let semantics - NOT a bug, correct Scheme behavior" {
  // These tests demonstrate that our interpreter correctly implements Scheme semantics.
  // The behavior matches Chicken Scheme (csi) exactly.
  
  // Test 1: Closures see updated global values (correct behavior)
  let shared_state =
    #|(begin
    #|  (define x 0)
    #|  (define f1 (lambda () x))
    #|  (define f2 (lambda () x))
    #|  (define x 1)
    #|  (+ (f1) (f2)))
  eval_string(shared_state, content=2) // Both see x=1, so 1+1=2 (matches csi)
  
  // Test 2: Parameter shadows global
  let param_shadow_test =
    #|(begin
    #|  (define x 10)
    #|  (define test-fn 
    #|    (lambda (x)
    #|       ((lambda () x))))
    #|  (test-fn 20))
  eval_string(param_shadow_test, content=20) // Parameter x=20 shadows global x=10
  
  // Test 3: Nested parameter shadowing
  let nested_params =
    #|(begin
    #|  (define x 1)
    #|  ((lambda (x)
    #|     ((lambda (y)
    #|        (+ x y))
    #|      100))
    #|   10))
  eval_string(nested_params, content=110) // Inner lambda sees outer's x=10, y=100
  
  // Test 4: Closures capture environment correctly
  let mutation_problem =
    #|(begin
    #|  (define x 1)
    #|  (define get-x (lambda () x))
    #|  ((lambda (x)
    #|     (+ (get-x) x))
    #|   10))
  eval_string(mutation_problem, content=11) // get-x sees global x=1, parameter x=10
  
  // Test 5: define inside lambda mutates (Scheme standard behavior!)
  // Verified with csi: returns 100, NOT 50
  let define_mutation =
    #|(begin
    #|  (define y 5)
    #|  ((lambda (y)
    #|     (begin
    #|       (define f (lambda () y))
    #|       (begin
    #|         (define y 100)
    #|         (f))))
    #|   50))
  eval_string(define_mutation, content=100) // Correct: define mutates the binding (matches csi)
}

///|
test "let vs define - different semantics (not a bug)" {
  // This test demonstrates that `let` and `define` have fundamentally different semantics.
  // Our interpreter correctly implements define semantics (verified with csi).
  // To implement proper `let`, we'd need a separate construct.
  
  // Proper let behavior using nested lambdas (creates new bindings)
  let let_via_lambda =
    #|(begin
    #|  ((lambda (x)
    #|     ((lambda (f)
    #|        ((lambda (x)
    #|           (f))
    #|         20))
    #|      (lambda () x)))
    #|   10))
  eval_string(let_via_lambda, content=10) // Inner x=20 is a new binding, doesn't affect closure
  
  // define inside lambda (mutates existing binding - correct Scheme behavior)
  let define_inside_lambda =
    #|(begin
    #|  ((lambda (x)
    #|     (begin
    #|       (define f (lambda () x))
    #|       (begin
    #|         (define x 20)
    #|         (f))))
    #|   10))
  eval_string(define_inside_lambda, content=20) // Correct: define mutates (verified with csi)
  
  // This shows why we need a separate `let` construct if we want proper lexical scoping
  // The current behavior is correct for `define`, but `let` would need different implementation
}

///|
test "let creates new scope without mutation" {
  // Basic let
  eval_string("(let ((x 10)) x)", content=10)
  
  // Outer x unchanged after let
  eval_string(
    #|(begin
    #|  (define x 5)
    #|  (begin
    #|    (let ((x 10))
    #|      x)
    #|    x)), content=5))
  
  // Closure captures let binding correctly
  eval_string(
    #|(let ((x 10))
    #|  (let ((f (lambda () x)))
    #|    (let ((x 20))
    #|      (f)))), content=10)
  )
  
  // Multiple bindings
  eval_string(
    #|(let ((x 10)
    #|       (y 20)
    #|       (z 30))
    #|   (+ x (+ y z))), content=60)
}

///|
test "let evaluates bindings in parallel" {
  // Bindings see outer scope, not each other
  eval_string(
    #|(begin
    #|  (define x 5)
    #|  (let ((x 10)
    #|        (y x))  ; y gets outer x (5), not let's x (10)
    #|    (+ x y))), content=15)  // 10 + 5 = 15
  )
  
  // Nested let with parallel evaluation
  eval_string(
    #|(let ((x 1))
    #|  (let ((x 2) (y x))  ; y gets outer x (1)
    #|    (let ((x 3) (z x))  ; z gets middle x (2)
    #|      (+ x (+ y z))))), content=6  // 3 + 1 + 2 = 6
}

///|
test "let* evaluates bindings sequentially" {
  // Basic sequential binding
  eval_string(
    #|(let* ((x 10)
    #|        (y x))  ; y gets x from this let*
    #|   (+ x y)), content=20  // 10 + 10 = 20
  )
  
  // Multiple sequential dependencies
  eval_string(
    #|(let* ((x 10)
    #|        (y x)
    #|        (z (+ x y)))
    #|   (+ x (+ y z))), content=40  // 10 + 10 + 20 = 40
  )
  
  // let* shadowing in sequence
  eval_string(
    #|(begin
    #|  (define x 1)
    #|  (let* ((x 10)
    #|         (y x))  ; y gets the new x (10)
    #|    (+ x y))), content=20)
}

///|
test "letrec allows mutual recursion" {
  // Even/odd mutual recursion
  eval_string(
    #|(letrec ((even? (lambda (n)
    #|                   (if (= n 0)
    #|                     true
    #|                     (odd? (- n 1)))))
    #|          (odd? (lambda (n)
    #|                  (if (= n 0)
    #|                    false
    #|                    (even? (- n 1))))))
    #|   (if (even? 6) 1 0)), content=1)
  )
  
  eval_string(
    #|(letrec ((even? (lambda (n)
    #|                   (if (= n 0)
    #|                     true
    #|                     (odd? (- n 1)))))
    #|          (odd? (lambda (n)
    #|                  (if (= n 0)
    #|                    false
    #|                    (even? (- n 1))))))
    #|   (if (odd? 5) 1 0)), content=1)
  )
  
  // Self-recursive function in letrec
  eval_string(
    #|(letrec ((fact (lambda (n)
    #|                  (if (= n 0)
    #|                    1
    #|                    (* n (fact (- n 1)))))))
    #|   (fact 5)), content=120)
}

///|
test "let vs define semantics comparison" {
  // let doesn't mutate - creates new binding
  eval_string(
    #|(let ((x 10))
    #|  (let ((f (lambda () x)))
    #|    (let ((x 20))
    #|      (f)))), content=10)  // Closure sees original x=10
  )
  
  // define mutates - same test with define shows different behavior
  eval_string(
    #|((lambda (x)
    #|   (begin
    #|     (define f (lambda () x))
    #|     (begin
    #|       (define x 20)
    #|       (f))))
    #| 10), content=20  // Closure sees mutated x=20
  )
  
  // Demonstrating the key difference
  eval_string(
    #|(begin
    #|  (define result1 
    #|    (let ((x 10))
    #|      (let ((get-x (lambda () x)))
    #|        (let ((x 20))
    #|          (get-x)))))
    #|  (define result2
    #|    ((lambda (x)
    #|       (define get-x (lambda () x))
    #|       (define x 20)
    #|       (get-x))
    #|     10))
    #|  (+ result1 result2)), content=30  // 10 + 20 = 30
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
  eval_string(fibonacci, content=8)

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
