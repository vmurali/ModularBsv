--module PrettyPrint where
import DataTypes
import Netlist
import Conflict
import ModuleParser
import Scheduler
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
	parsed <- parseFromFile modulesParser filenameinput
	case parsed of
    	--	Left _ -> putStrLn "Parse error: You think I will provide you useful information to help you debug your code: Not at all"
    		Left error -> putStrLn $ show error
    		Right mods -> do
				putStrLn ( show mods)
				putStrLn . snd $ (List.foldl (\(acc,str) m -> 
      					let modIfcs = buildModuleIfc acc m
					    mName = moduleName m
					    mapBinds = bindings m
					    mapInsts = instances m
					    mapMeths = methods m
					    listFps = fps m
					    listRules = Map.keys $ rules m
					    schedulerInf = scheduler modIfcs m 
					    netlist = prettyPrint (mName,mapBinds,mapInsts,listRules,mapMeths,listFps,schedulerInf) 
					    in  ( modIfcs ,str ++ netlist))
						   (initialIfcs,"")
						   mods)

initialIfcs = fromList [("mkEHR", ehrIfc), ("mkRegFile", regFileIfc)]

prettyPrint (mName,
		mapBinds,
		mapInsts,
		listRules,
		mapMeths,
		listFps,
		schedulerInf) =
	if mName == "mkEHR" || mName == "mkRegFile"  
		then "" 
		else
			"module " ++ mName ++"(CLK, RST_N" ++ concat [", " ++ x | x <- lotOfFpMeth, x/= []] ++");\n" ++
			concat (List.map 
				(\(n,bind) -> prettyPrintBindW (n,bind))   
				$ Map.toList mapBinds)
			++
			concat (List.map 
				(\n-> "wire "++ "RDY_"++n++";\n"
					++ "wire "++ "EN_"++n++";\n")
				$ listRules)
			++
			concat (List.map 
				(\(n,meth) -> prettyPrintDefinedMethod (n, extractSize $ methodType meth ,methodArgs meth))   
				$ Map.toList mapMeths)
			++
			concat (List.map 
				(\(fp) -> prettyPrintDefinedMethod (fpName fp, extractSize $ fpType fp ,fpArgs fp))   
				$ listFps)
			++
			concat (List.map 
				(\(n,inst) -> prettyPrintInst (n,inst))   
				$ Map.toList mapInsts )
			++
			concat (List.map 
				(\(n,bind) -> prettyPrintBindA (n,bind))   
				$ Map.toList mapBinds)
			++
			concat (List.map 
				(\(n,l) -> prettyPrintSched n l) 
				$ Map.toList schedulerInf)
			++ "endmodule\n"

	where
		getForOneMethod ty n args = 	["RDY_" ++ n
						, case ty of
							Action -> "" 
							otherwise -> n
						, case (ty,args) of 
							(Value _,[]) -> "" 
							otherwise -> "EN_"++n
						] ++ fmap fst args  
		lotOfFpMeth =  concat $ [getForOneMethod ty n args | Fp n ty args <- listFps]  ++ [getForOneMethod ty n args | (n, Method ty args _) <- Map.toList mapMeths]
		extractSize t = case t of
					Value i -> i
					Action -> -1  -- Microhack to simulate the absence of size
					ActionValue i -> i  


prettyPrintFp (n,size,args) =
	(if size /= -1 then "output " ++ (if size /= 0 then "[" ++ show (size-1) ++ ":0] " else "") ++ "fp1_"++ n ++ " ;\n" else "") ++ 
	(if size /= -1 then "output " ++ (if size /= 0 then "[" ++ show (size-1) ++ ":0] " else "") ++ "fp2_"++ n ++ " ;\n" else "")  ++
	"output " ++ "RDY_fp1_" ++ n ++ " ;\n" ++ 
	"output " ++ "RDY_fp2_" ++ n ++ " ;\n" ++ 
	"input " ++ "EN_fp1_" ++ n ++ " ;\n" ++
	"input " ++ "EN_fp2_" ++ n ++ " ;\n" ++
	concat (List.map
			(\(arg,s) -> "input [" ++ show (s-1) ++ ":0] " ++ "fp1_" ++ arg ++ ";\n" ++
					"input [" ++ show (s-1) ++ ":0] " ++ "fp2_" ++ arg ++ ";\n" )
			args)	

prettyPrintDefinedMethod (n,size,args)=
	(if size /= -1 then "input " ++ (if size /= 0 then "[" ++ show (size-1) ++ ":0] " else "") ++ "fp1_"++ n ++ " ;\n" else "") ++ 
	(if size /= -1 then "input " ++ (if size /= 0 then "[" ++ show (size-1) ++ ":0] " else "") ++ "fp2_"++ n ++ " ;\n" else "") ++
	"input " ++ "RDY_fp1_" ++ n ++ " ;\n" ++ 
	"input " ++ "RDY_fp2_" ++ n ++ " ;\n" ++ 
	"output " ++ "EN_fp1_" ++ n ++ " ;\n" ++
	"output " ++ "EN_fp2_" ++ n ++ " ;\n" ++
	concat (List.map
			(\(arg,s) -> "output [" ++ show (s-1) ++ ":0] " ++ "fp_1" ++ arg ++ ";\n" ++
					"output [" ++ show (s-1) ++ ":0] " ++ "fp_2" ++ arg ++ ";\n" )
			args)	



prettyPrintInst (name,inst) =
	name ++
	" " ++
	(instModule inst) ++
	case (instWidth inst,instInit inst, instSize inst) of
		(Expr None _ ,Expr None _ ,Expr None _ ) -> "\n" 
		otherwise -> "#(" ++ (intercalate "," . Maybe.catMaybes $ [showExp . instWidth, showExp . instInit , showExp . instSize] <*> [inst] ) ++");\n" 
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
			[a] -> a 	 
			otherwise -> "{"++intercalate "," l  ++ "}" 	



prettyPrintBindW (bn, Binding ba bz bexpr) = 
  "wire " ++ case ba of 
			Nothing -> ""
			Just 0 -> "" 
			Just val -> "[" ++ show (val-1) ++ ":0] "
  ++ case bz of
	0 -> ""
	otherwise -> "[" ++ show (bz-1) ++ ":0] "
  ++ bn ++ " ;\n"


prettyPrintBindA (bn, Binding ba bz bexpr) = 
	"assign " ++ bn ++ " = " ++
	prettyPrintExp bexpr ++ ";\n"


prettyPrintExp (Expr op listArgs) = case op of 
   None -> intercalate " " listArgs  
   Unary s -> s ++ intercalate " " listArgs 
   Binary s -> intercalate (" " ++ s ++ " ") listArgs
   Word s -> intercalate (" " ++ s ++ " ") listArgs
     -- | s == "concat" -> "{" ++ intercalate (", ") listArgs ++ "}"
   MethCall c-> "undefined" 
   Rdy n -> "undefined"

prettyPrintSched (x,y) l =
	"assign EN_" ++ y ++ " = " ++
	intercalate
		" && "
		(List.map (\(a,b) -> "! " ++ printTerm (a,b)  ) l)	
	++ ";\n"
	where
		printTerm (a,b) = if a == "fp" || a == "this" 
				then "EN_" ++ b else "EN_" ++ a ++ "_" ++ b 


