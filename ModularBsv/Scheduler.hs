module Scheduler where

import DataTypes
import Conflict
import qualified Data.Set.Monad as Set
import qualified Data.Map as Map
import Debug.Trace

listPos a ls =
  case ls of
    x : xs -> if elem a x
                then 0
                else (listPos a xs) + 1

schedulerBase ::
  ModuleIfcs
  -> Module
  -> PriorityElem
  -> [PriorityElem]
schedulerBase modIfcs mod a =
  foldl (\expr x -> --trace (show a ++ show x ++ show (process x) ++ show (process a) ++ show (conflict x a)) $ 
                    if (listPos a newplist > listPos x newplist && notOrder x a) ||
                       (isDefMeth x && listPos a newplist < listPos x newplist && notOrder a x)
                      then x:expr
                      else expr)
                 [] (concat $ newplist )
  where
    plist = priorityList mod
    flatList = Set.fromList $ concat plist
    newrules = filter (\x -> not $ Set.member ("this", x) flatList) (Map.keys $ rules mod)
    newmethods = filter (\x -> not $ Set.member ("this", x) flatList) (Map.keys $ methods mod)
    newcalledmethods = [map (\y-> (x,y)) $ newcalledmethod x | x <- Map.keys $ instances mod ]  
    newcalledmethod n  = filter (\x -> not $ Set.member (n, x) flatList) ( fpsInModule $ modIfcs Map.!  (instModule $ instances mod Map.! n) ) 
    newplist = plist ++ map (\x-> [("this",x)]) newrules ++ (filter ((/=)[]) $ [map (\x-> ("this",x)) newmethods] ++ newcalledmethods)  
    isDefMeth (m, h) = m == "this" && (Map.member h $ methods mod)
    isRule (m, h) = m == "this" && (Map.member h $ rules mod)
    conflict x y = fullCm modIfcs mod (process x) (process y)
    process (m, h) = if not (isDefMeth (m, h)) && not (isRule (m, h))
                       then  ( (Map.fromList
                                 (zip (fpsInModule $ modIfcs Map.! (instModule $instances mod Map.! m))
                                   (instArgs $ instances mod Map.! m))) Map.! h)
                       else  (m, h)
    notOrder a b = conflict a b /= SB && conflict a b /= CF

scheduler ::
  ModuleIfcs
  -> Module
  -> Map.Map PriorityElem [PriorityElem]
scheduler modIfcs mod =
  foldl (\acc x -> Map.insert x (schedulerBase modIfcs mod x) acc)
                Map.empty (map (\x -> ("this",x)) . Map.keys $ rules mod)
