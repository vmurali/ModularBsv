module CalledMethods where

import DataTypes
import qualified Data.Map as Map
import Debug.Trace
import qualified Data.Set as Set

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
  -> Map.Map CalledMethod (Set.Set [ArgName])
getBindingCaller mod b =
  if Map.member b (bindings mod)
    then
      case op of
        MethCall c -> Map.insertWith Set.union c (Set.singleton args) foldAll
        otherwise -> foldAll
    else Map.empty
  where
    Expr op args = bindExpr $ bindings mod Map.! b
    foldAll = Prelude.foldl (\acc x -> Map.unionWith Set.union (getBindingCaller mod x) acc) Map.empty args

-- Creates a map from above function
getBindingMap :: Module -> Map.Map BindName (Map.Map CalledMethod (Set.Set [ArgName]))
getBindingMap mod = Map.mapWithKey (\k _ -> getBindingCaller mod k) (bindings mod)


-- TODO : Must check again
-- Collects the called-method-map (with predicate and arguments) for a rule/method with guard, and body
getBindingCall ::
  Module -- Module to search in
  -> String -- The guard for the rule or method which calls the called method
  -> ThisName -- The rule or method which calls the called method
  -> [Calleds] -- The list of [if pred bindName] which is body of the calling method or rule
  -> Map.Map CalledMethod (Set.Set (String, [ArgName]))
getBindingCall mod guard rlName calleds =
  calledStuff
  where
    un = Map.unionWith Set.union
    easyStuff cond name = if Map.member name (getBindingMap mod)
                            then Map.map (\set -> Set.map (\x -> (cond, x)) set) (getBindingMap mod Map.! name)
                            else Map.empty
    calledStuff = foldl (\acc1 (Calleds cond meth args) ->
                          Map.singleton meth (Set.singleton (cond, args)) `un`
                            easyStuff "1'b1" cond `un`
                              foldl (\acc2 x -> easyStuff cond x `un` acc2) acc1 args)
                        (easyStuff "1'b1" guard `un` easyStuff "1'b1" rlName)
                        calleds

-- Creates a map for each rule (the above map)
getBindingRules :: Module -> Map.Map RuleName (Map.Map CalledMethod (Set.Set(String, [ArgName])))
getBindingRules mod = Map.mapWithKey (\k _ -> getBindingCall mod (ruleGuard $ rules mod Map.! k) k (ruleBody $ rules mod Map.! k)) (rules mod)

-- Creates a map for each method (the above map)
getBindingMethods :: Module -> Map.Map DefinedMethod (Map.Map CalledMethod (Set.Set (String, [ArgName])))
getBindingMethods mod = Map.mapWithKey (\k _ -> getBindingCall mod ("RDY_" ++ k) k (methodBody $ methods mod Map.! k)) (methods mod)

-- Creates union of the above two maps
getBindingBoth :: Module -> Map.Map ThisName (Map.Map CalledMethod (Set.Set (String, [ArgName])))
getBindingBoth mod = Map.union (getBindingRules mod) (getBindingMethods mod)

-- Reverses the map from rule/method -> calledmethods  to   calledmethod -> rule/method
getBothCaller :: Module -> Map.Map CalledMethod [(ThisName, String, [ArgName])]
getBothCaller mod =
  Map.fromList
   [(rcm, [(r, rcond, rargs) | (rcond, rargs) <- Set.toList rrest])
    | (r, rcmall) <- Map.toList $ getBindingBoth mod,
      (rcm, rrest) <- Map.toList rcmall]

getCalled :: Module -> ThisName -> [CalledMethod]
getCalled mod name =
  let fullMap = getBindingBoth mod in
    if Map.member name fullMap
      then Map.keys (Map.filterWithKey (\(k, _) _ -> k /= "Prelude") (fullMap Map.! name))
      else []

getCalledMethods :: ModuleIfcs -> Module -> Map.Map CalledMethod (Bool, [ArgName])
getCalledMethods modIfcs Module{instances = ins, fps = fs} = Map.fromList $ instMeths ++ fops
  where
    instMeths = [((x, name), (isV0, args)) |
      (x, y) <- Map.toList ins,
        (name, (isV0, args, _)) <- Map.toList $ methodsInModule (modIfcs Map.! instModule y)]
    fops = [(("fp1", name), (case typ of Value _ -> xs == []
                                         otherwise -> False, [x | (x, y) <- xs])) |
                       (Fp name typ xs) <- fs] ++
           [(("fp2", name), (case typ of Value _ -> xs == []
                                         otherwise -> False, [x | (x, y) <- xs])) |
                       (Fp name typ xs) <- fs]
