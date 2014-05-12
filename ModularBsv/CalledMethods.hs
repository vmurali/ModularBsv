module CalledMethods where

import DataTypes
import Data.Map as Map
import Debug.Trace

getCalled :: Module -> ThisName -> [CalledMethod]
getCalled mod name =
  if member name (bindings mod)
    then
      let Binding _ _ (Expr op strs) = bindings mod ! name in
        (case op of
           MethCall c1 -> [c1]
           otherwise -> []
        ) ++
        concatMap (getCalled mod) strs
    else if member name (rules mod)
      then
        let Rule guard calleds = rules mod ! name in
          getCalled mod guard ++ (
          concat $ do
            Calleds cond c1 args <- calleds
            x <- cond : args
            return $ c1 : getCalled mod x)
      else if member name (methods mod)
        then
          let Method _ _ calleds = methods mod ! name in
          getCalled mod ("RDY_" ++ name) ++ (
          concat $ do
            Calleds cond c1 args <- calleds
            x <- cond : args
            return $ c1: getCalled mod x)
        else []

{-
getInstCaller :: Module -> CalledMethod -> [(InstName, DefinedMethod)]
getInstCaller mod c =
  Prelude.filter (\i -> elem c (instArgs (insts ! i))) instNames
  where
    insts = instances mod
    instNames = keys insts
-}

getBindingCaller ::
  Module -- Module to search in
  -> CalledMethod -- Method we want to search the bindings for
  -> BindName -- The top-level binding name we are starting from for the search
  -> ThisName -- The rule or method which calls the called method
  -> String -- The condition under which the called method is called in the above rule or method
  -> [(ThisName, String, [ArgName])]
getBindingCaller mod c b n cond = --trace ("final " ++ moduleName mod ++ "." ++ n ++ " " ++ show c ++ show b) $
  if member b (bindings mod)
    then
     --trace ("EIFNE" ++ show b ++ show args) $
      case op of
        MethCall c' ->
          if c == c'
            then [(n, cond, args)] -- : foldAll
            else foldAll
        otherwise -> foldAll
    else []
  where
    Expr op args = bindExpr $ bindings mod ! b
    foldAll = concat [getBindingCaller mod c x n cond | x <- args]

-- TODO : Search method return value bindings also
getBindingCall ::
  Module -- Module to search in
  -> CalledMethod -- Method we want to search the bindings for
  -> String -- The guard for the rule or method which calls the called method
  -> ThisName -- The rule or method which calls the called method
  -> [Calleds] -- The list of [if pred bindName] which is body of the calling method or rule
  -> [(ThisName, String, [ArgName])]
getBindingCall mod c guard rlName calleds = --trace ("stuff " ++ moduleName mod ++ "." ++ rlName ++ " " ++ show c) $
  getBindingCaller mod c guard rlName "1\'b1" ++
  getBindingCaller mod c (rlName) rlName "1\'b1" ++
  (concat $
    [if meth == c
       then [(rlName, cond, args)] -- : concat [getBindingCaller mod c arg rlName cond | arg <- args]
       else concat [getBindingCaller mod c arg rlName cond | arg <- args]
     | Calleds cond meth args <- calleds])

getRulesCaller :: Module -> CalledMethod -> [(RuleName, String, [ArgName])]
getRulesCaller mod c = --trace ("Rule" ++ show (length (toList $ rules mod))) $
  concat
    [getBindingCall mod c guard rlName calleds | (rlName, Rule guard calleds) <- toList $ rules mod]

getMethodsCaller :: Module -> CalledMethod -> [(DefinedMethod, String, [ArgName])]
getMethodsCaller mod c = --traceId $ --trace ("Method" ++ show (length (toList $ rules mod))) $
  concat
    [getBindingCall mod c ("RDY_" ++ rlName) rlName calleds
     | (rlName, Method _ _ calleds) <- toList $ methods mod]

getBothCaller :: Module -> CalledMethod -> [(ThisName, String, [ArgName])]
getBothCaller mod c = getRulesCaller mod c ++ getMethodsCaller mod c

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
