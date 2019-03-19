/**
 * Provides predicates for associating new/malloc calls with delete/free.
 */
import cpp
import semmle.code.cpp.controlflow.SSA

/**
 * Holds if `alloc` is a use of `malloc` or `new`.  `kind` is
 * a string describing the type of the allocation.
 */
predicate allocExpr(Expr alloc, string kind) {
  isAllocationExpr(alloc) and
  (
    (
      alloc instanceof FunctionCall and
      kind = "malloc"
    ) or (
      alloc instanceof NewExpr and
      kind = "new" and

      // exclude placement new and custom overloads as they
      // may not conform to assumptions
      not alloc.(NewExpr).getAllocatorCall().getTarget().getNumberOfParameters() > 1
    ) or (
      alloc instanceof NewArrayExpr and
      kind = "new[]" and

      // exclude placement new and custom overloads as they
      // may not conform to assumptions
      not alloc.(NewArrayExpr).getAllocatorCall().getTarget().getNumberOfParameters() > 1
    )
  )
}

/**
 * Holds if `alloc` is a use of `malloc` or `new`, or a function
 * wrapping one of those.  `kind` is a string describing the type
 * of the allocation.
 */
predicate allocExprOrIndirect(Expr alloc, string kind) {
  // direct alloc
  allocExpr(alloc, kind) or

  exists(ReturnStmt rtn |
    // indirect alloc via function call
    alloc.(FunctionCall).getTarget() = rtn.getEnclosingFunction() and
    (
      allocExprOrIndirect(rtn.getExpr(), kind) or
      exists(SsaDefinition def, LocalScopeVariable v |
        // alloc via SSA
        allocExprOrIndirect(def.getAnUltimateDefiningValue(v), kind) and
        rtn.getExpr() = def.getAUse(v)
      )
    )
  )
}

/**
 * Holds if `v` is a non-local variable which is assigned with allocations of
 * type `kind`.
 */
private pragma[nomagic] predicate allocReachesVariable(Variable v, Expr alloc, string kind) {
  exists(Expr mid |
    not v instanceof LocalScopeVariable and
    v.getAnAssignedValue() = mid and
    allocReaches0(mid, alloc, kind)
  )
}

/**
 * Holds if `e` is an expression which may evaluate to the
 * result of a previous memory allocation `alloc`.  `kind` is a
 * string describing the type of that allocation.
 */
private predicate allocReaches0(Expr e, Expr alloc, string kind) {
  (
    // alloc
    allocExprOrIndirect(alloc, kind) and
    e = alloc
  ) or exists(SsaDefinition def, LocalScopeVariable v |
    // alloc via SSA
    allocReaches0(def.getAnUltimateDefiningValue(v), alloc, kind) and
    e = def.getAUse(v)
  ) or exists(Variable v |
    // alloc via a global
    allocReachesVariable(v, alloc, kind) and
    strictcount(VariableAccess va | va.getTarget() = v) <= 50 and // avoid very expensive cases 
    e.(VariableAccess).getTarget() = v
  )
}

/**
 * Holds if `e` is an expression which may evaluate to the
 * result of previous memory allocations `alloc` only of type
 * `kind`.
 */
predicate allocReaches(Expr e, Expr alloc, string kind) {
  allocReaches0(e, alloc, kind) and
  not exists(string k2 |
    allocReaches0(e, _, k2)  and
    kind != k2
  )
}

/**
 * Holds if `free` is a use of free or delete.  `freed` is the
 * expression that is freed / deleted and `kind` is a string
 * describing the type of that free or delete.
 */
predicate freeExpr(Expr free, Expr freed, string kind) {
  (
    freeCall(free, freed) and
    kind = "free"
  ) or (
    free.(DeleteExpr).getExpr() = freed and
    kind = "delete"
  ) or (
    free.(DeleteArrayExpr).getExpr() = freed and
    kind = "delete[]"
  )
}

/**
 * Holds if `free` is a use of free or delete, or a function
 * wrapping one of those.  `freed` is the expression that is
 * freed / deleted and `kind` is a string describing the type
 * of that free or delete.
 */
predicate freeExprOrIndirect(Expr free, Expr freed, string kind) {
  // direct free
  freeExpr(free, freed, kind) or

  // indirect free via function call
  exists(Expr internalFree, Expr internalFreed, int arg |
    freeExprOrIndirect(internalFree, internalFreed, kind) and
    free.(FunctionCall).getTarget().getParameter(arg) = internalFreed.(VariableAccess).getTarget() and
    free.(FunctionCall).getArgument(arg) = freed
  )
}
