# How to Implement `let` Properly

## Understanding the Difference: `let` vs `define`

### `define` (current behavior - correct)
- **Mutates** existing bindings in the current environment
- Closures see updated values
- Example:
```scheme
((lambda (x)
   (define f (lambda () x))
   (define x 20)  ; Mutates x
   (f))            ; Returns 20
 10)
```

### `let` (needs implementation)
- Creates **new bindings** that shadow outer ones
- Does not mutate existing bindings
- Example:
```scheme
(let ((x 10))
  (let ((f (lambda () x)))
    (let ((x 20))  ; New binding, shadows but doesn't mutate
      (f))))        ; Returns 10
```

## Implementation Strategy

### Option 1: Syntactic Sugar (Recommended)

Transform `let` into immediately-invoked lambda expressions during parsing or evaluation:

```scheme
; Transform this:
(let ((x 10) (y 20))
  (+ x y))

; Into this:
((lambda (x y)
   (+ x y))
 10 20)
```

**Implementation in lisp_interpreter.mbt:**

```moonbit
List([Atom("let"), List(bindings), body]) => {
  // Extract variable names and values
  let vars = []
  let vals = []
  
  for binding in bindings {
    match binding {
      List([Atom(var), val]) => {
        vars.push(Atom(var))
        vals.push(val)
      }
      _ => raise TypeError("let: invalid binding format")
    }
  }
  
  // Create and evaluate: ((lambda vars body) vals...)
  let lambda_expr = List([Atom("lambda"), List(vars), body])
  let application = List([lambda_expr, .. vals])
  
  application.eval(env)
}
```

### Option 2: Direct Environment Management

Create a new environment frame without using lambda:

```moonbit
List([Atom("let"), List(bindings), body]) => {
  // Fork environment for new scope
  let let_env = env.fork()
  
  // Evaluate and bind all values in parallel (standard let)
  let bound_values = []
  for binding in bindings {
    match binding {
      List([Atom(var), val_expr]) => {
        // Evaluate in original env (parallel binding)
        let value = val_expr.eval(env)
        bound_values.push((var, value))
      }
      _ => raise TypeError("let: invalid binding format")
    }
  }
  
  // Add all bindings to the new environment
  for (var, value) in bound_values {
    let_env.set(var, value)
  }
  
  // Evaluate body in new environment
  body.eval(let_env)
}
```

## Variants to Consider

### 1. `let*` (Sequential Binding)
Bindings are evaluated sequentially, each can reference previous ones:

```scheme
(let* ((x 10)
       (y (+ x 5)))  ; y can reference x
  (+ x y))           ; Returns 25
```

Implementation:
```moonbit
List([Atom("let*"), List(bindings), body]) => {
  let let_env = env.fork()
  
  // Sequential evaluation - each binding sees previous ones
  for binding in bindings {
    match binding {
      List([Atom(var), val_expr]) => {
        // Evaluate in the accumulating environment
        let value = val_expr.eval(let_env)
        let_env.set(var, value)
      }
      _ => raise TypeError("let*: invalid binding format")
    }
  }
  
  body.eval(let_env)
}
```

### 2. `letrec` (Recursive Binding)
All bindings are in scope for all value expressions (for mutual recursion):

```scheme
(letrec ((even? (lambda (n) 
                  (if (= n 0) #t (odd? (- n 1)))))
         (odd? (lambda (n)
                 (if (= n 0) #f (even? (- n 1))))))
  (even? 6))  ; Returns #t
```

## Testing Your Implementation

Add these tests to verify correct `let` behavior:

```moonbit
test "let creates new bindings without mutation" {
  eval_string(
    #|(let ((x 10))
    #|  (let ((f (lambda () x)))
    #|    (let ((x 20))
    #|      (f)))),
    content=10  // Inner x doesn't affect closure
  )
}

test "let evaluates bindings in parallel" {
  eval_string(
    #|(begin
    #|  (define x 5)
    #|  (let ((x 10)
    #|        (y x))  ; y gets outer x (5), not let's x (10)
    #|    (+ x y))),
    content=15  // 10 + 5 = 15
  )
}

test "let* evaluates bindings sequentially" {
  eval_string(
    #|(let* ((x 10)
    #|        (y x))  ; y gets let's x (10)
    #|   (+ x y)),
    content=20  // 10 + 10 = 20
  )
}
```

## Key Implementation Points

1. **Parallel vs Sequential**: Standard `let` evaluates all value expressions in the *outer* environment before binding
2. **New Scope**: Always create a new environment scope (fork)
3. **No Mutation**: Never mutate the parent environment
4. **Closure Capture**: Closures created in `let` body should see the `let` bindings

## Recommended Approach

Start with **Option 1 (Syntactic Sugar)** because:
- It's simpler to implement
- Reuses existing lambda machinery
- Automatically gets correct scoping behavior
- Easier to debug and understand

Once that works, you can optimize with Option 2 if needed for performance.
