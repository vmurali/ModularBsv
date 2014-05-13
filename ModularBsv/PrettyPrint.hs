module PrettyPrint where
import DataTypes
import Netlist
import ModuleParser
import System.IO
import Text.Parsec
import Text.Parsec.String
import Data.Map as Map
import Data.Maybe as Maybe
import Data.List as List
import Control.Applicative


main :: IO ()
main = do
	filenameinput <- getLine
	filenameoutput <- getLine
	parsed <- parseFromFile modulesParser filenameinput
	case parsed of
    		Left _ -> putStrLn "Parse error: You think I will provide you usefull information to help you to debug your code: Not at all"
    		Right mods -> appendFile filenameoutput 
				. snd $ (List.foldl (\(acc,str) m -> 
      					let modIfcs = buildModuleIfc acc m
					    mName = moduleName m
					    mapBinds = bindings m
					    mapInsts = instances m
					    mapMeths = methods m
					    listFps = fps m
					    listRules = Map.keys $ rules m
					    schedulerInf = undefined
					    netlist = prettyPrint (mName,mapBinds,mapInsts,listRules,mapMeths,listFps,schedulerInf) 
					    in  ( modIfcs ,str ++ netlist))
						   (Map.empty,"")
						   mods)



prettyPrint (mName,
		mapBinds,
		mapInsts,
		listRules,
		mapMeths,
		listFps,
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
		(\(n,meth) -> prettyPrintDefinedMethod (n, extractSize $ methodType meth ,methodArgs meth))   
		$ Map.assocs mapMeths)
	++
	concat (List.map 
		(\(fp) -> prettyPrintDefinedMethod (fpName fp, extractSize $ fpType fp ,fpArgs fp))   
		$ listFps)
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
	++ "endmodule\n"

	where
		extractSize t = case t of
					Value i -> i
					Action -> -1  -- Microhack to simulate the absence of size
					ActionValue i -> i  


prettyPrintFp (n,size,args) =
	(if size /= -1 then "output " ++ (if size /= 0 then "[" ++ show size ++ "-1:0] " else "") ++ "fp1_"++ n ++ " ;\n" else "") ++ 
	(if size /= -1 then "output " ++ (if size /= 0 then "[" ++ show size ++ "-1:0] " else "") ++ "fp2_"++ n ++ " ;\n" else "")  ++
	"output " ++ "RDY_fp1_" ++ n ++ " ;\n" ++ 
	"output " ++ "RDY_fp2_" ++ n ++ " ;\n" ++ 
	"input " ++ "EN_fp1_" ++ n ++ " ;\n" ++
	"input " ++ "EN_fp2_" ++ n ++ " ;\n" ++
	concat (List.map
			(\(arg,s) -> "input " ++ show s ++ "-1:0] " ++ "fp_1" ++ arg ++ ";\n" ++
					"input " ++ show s ++ "-1:0] " ++ "fp_2" ++ arg ++ ";\n" )
			args)	

prettyPrintDefinedMethod (n,size,args)=
	(if size /= -1 then "input " ++ (if size /= 0 then "[" ++ show size ++ "-1:0] " else "") ++ "fp1_"++ n ++ " ;\n" else "") ++ 
	(if size /= -1 then "input " ++ (if size /= 0 then "[" ++ show size ++ "-1:0] " else "") ++ "fp2_"++ n ++ " ;\n" else "") ++
	"input " ++ "RDY_fp1_" ++ n ++ " ;\n" ++ 
	"input " ++ "RDY_fp2_" ++ n ++ " ;\n" ++ 
	"output " ++ "EN_fp1_" ++ n ++ " ;\n" ++
	"output " ++ "EN_fp2_" ++ n ++ " ;\n" ++
	concat (List.map
			(\(arg,s) -> "output " ++ show s ++ "-1:0] " ++ "fp_1" ++ arg ++ ";\n" ++
					"output " ++ show s ++ "-1:0] " ++ "fp_2" ++ arg ++ ";\n" )
			args)	



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
	++ ");\n"
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


