module Scheduler where

import DataTypes
import Conflict
import Data.Map

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
  Prelude.foldl (\expr x ->
                     if isDefMeth x
                       then
                         if (listPos a plist < listPos x plist && notOrder a x) ||
                            (listPos a plist > listPos x plist && notOrder x a)
                           then x:expr
                           else expr
                       else
                         if (listPos a plist > listPos x plist && notOrder x a)
                           then x:expr
                           else expr)
                 [] (concat $ priorityList mod)
  where
    plist = priorityList mod
    isDefMeth (m, h) = m == "this" && (member h $ methods mod)
    isRule (m, h) = m == "this" && (member h $ rules mod)
    conflict x y = cmCalledMethods modIfcs mod (process x) (process y)
    process (m, h) = if not (isDefMeth (m, h)) && not (isRule (m, h))
                       then fromList (zip (fpsInModule (modIfcs ! (instModule (instances mod ! m))))
                                          (instArgs (instances mod ! m))) ! h
                       else (m, h)
    notOrder a b = conflict a b /= SB && conflict a b /= CF

scheduler ::
  ModuleIfcs
  -> Module
  -> Map PriorityElem [PriorityElem]
scheduler modIfcs mod =
  Prelude.foldl (\acc x -> insert x (schedulerBase modIfcs mod x) acc) empty [x | x <- concat $ priorityList mod, not (isDefMeth x)]
  where
    isDefMeth (m, h) = m == "this" && (member h $ methods mod)
