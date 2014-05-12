import DataTypes
import Data.Map as Map
import Data.Maybe as Maybe
import Data.List as List
import Control.Applicative

prettyPrint (mName,
		mapBinds,
		mapInsts,
		listRules,
		schedulerInf) =
	"module" ++ mName ++ ";\n" ++	
	concat (List.map 
		(\(n,bind) -> prettyPrintBindW (n,bind))   
		$ Map.assocs mapBinds)
	++
	concat (List.map 
		(\n-> "wire "++ "RDY_"++n++";\n"
			++ "wire "++ "EN_"++n++";\n")
		$ listRules)
	++
	concat (List.map 
		(\(n,inst) -> prettyPrintInst (n,inst))   
		$ Map.assocs mapInsts )
	++
	concat (List.map 
		(\(n,bind) -> prettyPrintBindA (n,bind))   
		$ Map.assocs mapBinds)
	++
	concat (List.map 
		(\(n,l) -> prettyPrintSched n l) 
		$ Map.assocs schedulerInf)
	++"endmodule" 



prettyPrintInst (name,inst) =
	show name ++
	" " ++
	(show $ instModule inst) ++
	case (instWidth inst,instInit inst, instSize inst) of
		(Expr None _ ,Expr None _ ,Expr None _ ) -> "\n" 
		otherwise -> "#(" ++ (intercalate "," . Maybe.catMaybes $ [showExp . instWidth, showExp . instInit , showExp . instSize] <*> [inst] ) ++")\n" 
	++ "("
	++ intercalate
		","
		(List.map 
			(\(x,y)-> x++"_"++y)
			$ instArgs inst)
	++ ")\n"
	where
		showExp (Expr None l) = Nothing
		showExp (Expr _ l) = Just $ case l of
			[] -> undefined
			[a] -> show a 	 
			otherwise -> "{"++intercalate "," l  ++ "}" 	



prettyPrintBindW (bn, Binding ba bz bexpr) = 
  "wire " ++ bn ++ case ba of 
			Nothing -> ""
			Just 0 -> "" 
			otherwise -> "[" ++ show ba ++ "-1:0]"
  ++ case bz of
	0 -> ""
	otherwise -> "[" ++ show bz ++ "-1:0]"
  ++ ";\n"


prettyPrintBindA (bn, Binding ba bz bexpr) = 
	"assign " ++ bn ++ " = " ++
	prettyPrintExp bexpr ++ ";\n"


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
	++ ";\n"
	where
		printTerm (a,b) = if a == "fp" || a == "this" 
				then "EN_" ++ b else "EN_" ++ a ++ "_" ++ b 


