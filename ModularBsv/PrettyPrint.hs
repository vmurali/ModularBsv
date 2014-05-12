import DataTypes
import Data.Map as Map
import Data.List as List

prettyPrint (mName,
		mapBinds,
		_,
		_,
		_,
		_,
		_,
		schedulerInf) =
	List.foldl (\acc (n,bind) -> acc ++ prettyPrintBind (n,bind))   
		[]
		$ Map.toList mapBinds 
	++
	List.foldl (\acc (n,l) -> acc ++ prettyPrintSched n l) 
		[]
		$ Map.toList schedulerInf 



prettyPrintBind (bn, Binding ba bz bexpr) =
  "wire " ++ bn ++ "[" ++ ba ++ "-1:0][" ++ bz ++ "-1:0]\nassign " ++ bn ++ " = " ++
  prettyPrintExp bexpr ++ "\n"


prettyPrintExp (Expr op listArgs) = case op of 
   None -> intercalate " " listArgs  
   Unary s -> s ++ intercalate " " listArgs 
   Binary s -> intercalate (" " ++ s ++ " ") listArgs
   Word s -> intercalate (" " ++ s ++ " ") listArgs
   MethCall c-> undefined

prettyPrintSched (x,y) l =
	"assign EN_" ++ y ++ " = " ++
	intercalate
		" && "
		(List.map (\(a,b) -> "! (" ++ printTerm (a,b) ++ ")" ) l)	
	++ "\n"
	where
		printTerm (a,b) = if a == "fp" || a == "this" 
				then "EN_"++b else "EN_" ++ a ++ "_" ++ b 


