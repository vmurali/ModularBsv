module CalledMethods where

import DataTypes
import Data.Map as Map
import Debug.Trace

{-
getInstCaller :: Module -> CalledMethod -> [(InstName, DefinedMethod)]
getInstCaller mod c =
  Prelude.filter (\i -> elem c (instArgs (insts ! i))) instNames
  where
    insts = instances mod
    instNames = keys insts
-}

-- Collects the called methods and args in a binding
getBindingCaller ::
  Module -- Module to search in
  -> BindName -- The top-level binding name we are starting from for the search
  -> [(CalledMethod, [ArgName])] -- The list of called methods + args in this call
getBindingCaller mod b =
  if member b (bindings mod)
    then
      case op of
        MethCall c -> (c, args): foldAll
        otherwise -> foldAll
    else []
  where
    Expr op args = bindExpr $ bindings mod ! b
    foldAll = concat [getBindingCaller mod x| x <- args]

-- Creates a map from above function
getBindingMap :: Module -> Map BindName [(CalledMethod, [ArgName])]
getBindingMap mod = mapWithKey (\k _ -> getBindingCaller mod k) (bindings mod)

-- Collects the called-method-map (with predicate and arguments) for a rule/method with guard, and body
getBindingCall ::
  Module -- Module to search in
  -> String -- The guard for the rule or method which calls the called method
  -> ThisName -- The rule or method which calls the called method
  -> [Calleds] -- The list of [if pred bindName] which is body of the calling method or rule
  -> Map CalledMethod [(String, [ArgName])]
getBindingCall mod guard rlName calleds =
  fromListWith (++) $
    [(guardMeth, [("1'b1", guardArgs)]) | member guard $ getBindingMap mod, (guardMeth, guardArgs) <- getBindingMap mod ! guard] ++
    [(bodyMeth, [("1'b1", bodyArgs)]) | member rlName $ getBindingMap mod, (bodyMeth, bodyArgs) <- getBindingMap mod ! rlName] ++
    concat [(meth, [(cond, args)]):[(m1, [(cond, a1)]) | (m1, a1) <- concat $ [getBindingMap mod ! arg | arg <- args, member arg $ getBindingMap mod]] | Calleds cond meth args <- calleds]

-- Creates a map for each rule (the above map)
getBindingRules :: Module -> Map RuleName (Map CalledMethod [(String, [ArgName])])
getBindingRules mod = mapWithKey (\k _ -> getBindingCall mod (ruleGuard $ rules mod ! k) k (ruleBody $ rules mod ! k)) (rules mod)

-- Creates a map for each method (the above map)
getBindingMethods :: Module -> Map DefinedMethod (Map CalledMethod [(String, [ArgName])])
getBindingMethods mod = mapWithKey (\k _ -> getBindingCall mod ("RDY_" ++ k) k (methodBody $ methods mod ! k)) (methods mod)

-- Creates union of the above two maps
getBindingBoth :: Module -> Map ThisName (Map CalledMethod [(String, [ArgName])])
getBindingBoth mod = union (getBindingRules mod) (getBindingMethods mod)

-- Reverses the map from rule/method -> calledmethods  to   calledmethod -> rule/method
getBothCaller :: Module -> Map CalledMethod [(ThisName, String, [ArgName])]
getBothCaller mod =
  fromList
   [(rcm, [(r, rcond, rargs) | (rcond, rargs) <- rrest])
    | (r, rcmall) <- toList $ getBindingBoth mod,
      (rcm, rrest) <- toList rcmall]

getCalled :: Module -> ThisName -> [CalledMethod]
getCalled mod name =
  let fullMap = getBindingBoth mod in
    if member name fullMap
      then keys (fullMap ! name)
      else []

getCalledMethods :: ModuleIfcs -> Module -> Map CalledMethod (Bool, [ArgName])
getCalledMethods modIfcs Module{instances = ins, fps = fs} = fromList $ instMeths ++ fops
  where
    instMeths = [((x, name), (isV0, args)) |
      (x, y) <- toList ins,
        (name, (isV0, args, _)) <- toList $ methodsInModule (modIfcs ! instModule y)]
    fops = [(("fp1", name), (case typ of Value _ -> xs == []
                                         otherwise -> False, [x | (x, y) <- xs])) |
                       (name, Fp typ xs) <- toList fs] ++
           [(("fp2", name), (case typ of Value _ -> xs == []
                                         otherwise -> False, [x | (x, y) <- xs])) |
                       (name, Fp typ xs) <- toList fs]
