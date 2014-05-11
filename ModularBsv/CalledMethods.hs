module CalledMethods where

import DataTypes
import Data.Map as Map

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

getInstCaller :: Module -> CalledMethod -> [InstName]
getInstCaller mod c =
  Prelude.filter (\i -> elem c (instArgs (insts ! i))) instNames
  where
    insts = instances mod
    instNames = keys insts

getBindingCaller :: Module -> CalledMethod -> BindName -> ThisName -> String ->
                    [(ThisName, String, [ArgName])]
getBindingCaller mod c b n cond =
  if member b (bindings mod)
    then
      case op of
        MethCall c' ->
          if c == c'
            then [(n, cond, args)]
            else foldAll args
        otherwise -> foldAll args
    else []
  where
    Expr op args = bindExpr $ bindings mod ! b
    foldAll args = concatMap (\x -> getBindingCaller mod c x n cond) args

getBindingCall :: Module -> CalledMethod -> String -> ThisName -> [Calleds] ->
                 [(RuleName, String, [ArgName])]
getBindingCall mod c guard rlName calleds =
  getBindingCaller mod c guard rlName "1\'b1" ++ (concat $ do
    Calleds cond meth args <- calleds
    if meth == c
      then return [(rlName, cond, args)]
      else do
        arg <- args
        return $ getBindingCaller mod c arg rlName cond)


getRulesCaller :: Module -> CalledMethod -> [(RuleName, String, [ArgName])]
getRulesCaller mod c = concat $ do
  (rlName, Rule guard calleds) <- toList $ rules mod
  return $ getBindingCall mod c guard rlName calleds

getMethodsCaller :: Module -> CalledMethod -> [(DefinedMethod, String, [ArgName])]
getMethodsCaller mod c = concat $ do
  (rlName, Method _ _ calleds) <- toList $ methods mod
  return $ getBindingCall mod c ("RDY_" ++ rlName) rlName calleds

getBothCaller :: Module -> CalledMethod -> [(ThisName, String, [ArgName])]
getBothCaller mod c = getRulesCaller mod c ++ getMethodsCaller mod c

getCalledMethods :: ModuleIfcs -> Module -> Map CalledMethod (Bool, [ArgName])
getCalledMethods modIfcs Module{instances = ins, fps = fs} = fromList $ instMeths ++ fops
  where
    instMeths = do
      (x, y) <- toList ins
      (name, (isV0, args, _)) <- toList $ fpsForMethodInModule (modIfcs ! instModule y)
      return ((x, name), (isV0, args))
    fops = do
      (name, Fp typ xs) <- toList fs
      return (("fp", name), (case typ of Value _ ->  xs == []
                                         otherwise -> False,
                             [x | (x, y) <- xs]))
