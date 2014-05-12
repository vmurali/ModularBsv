import DataTypes
import Data.Map as Map
import Data.List as List

prettyPrint (mName,
		mapBinds,
		mapInsts,
		_,
		_,
		_,
		_,
		schedulerInf) =
	concat . map 
		(\(n,bind) -> prettyPrintBindW (n,bind))   
		(Map.assocs mapBinds) 
	++
	concat . map --HANDLE THE RULES 
		(undefined)
		undefined
	++
	concat . map 
		(\(n,inst) -> prettyPrintInst (n,inst))   
		(Map.assocs mapInsts ) 
	++
	concat . map 
		(\(n,bind) -> prettyPrintBindA (n,bind))   
		(Map.assocs mapBinds) 
	++
	concat . map 
		(\(n,l) -> prettyPrintSched n l) 
		(Map.assocs schedulerInf) 




prettyPrintInst (name,inst) =
	show name ++
	" " ++
	(show $ instModule inst) ++
	case (instWidth inst,instInit inst, instSize inst) of
		(Expr None _ ,Expr None _ ,Expr None _ ) -> "\n" 
		otherwise -> "#(" ++ undefined ++")\n" 
	++ "("
	++ intercalate
		","
		map 
			(\(x,y)-> x++"_"++y)
			instArgs
	++ ")"




prettyPrintBindW (bn, Binding ba bz bexpr) = --TODO : MAYBE INTEGER  
  "wire " ++ bn ++ case ba of 
			Nothing -> ""
			Just 0 -> "" 
			otherwise -> "[" ++ show ba ++ "-1:0]"
  ++ case bz of
	0 -> ""
	otherwise -> "[" ++ show bz ++ "-1:0]\n"


prettyPrintBindA (bn, Binding ba bz bexpr) = --TODO : MAYBE INTEGER  
	"assign " ++ bn ++ " = " ++
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
				then "EN_" ++ b else "EN_" ++ a ++ "_" ++ b 


