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
			let
				modIfcs = buildModuleIfc acc m
				mName = moduleName m
				mapBinds = bindings m
				mapInsts = instances m
				mapMeths = methods m
				listFps = fps m
				listRules = Map.keys $ rules m
				schedulerInf = scheduler modIfcs m 
				netlist = prettyPrint (modIfcs, mName,mapBinds,mapInsts,listRules,mapMeths,listFps,schedulerInf) 
				in ( modIfcs ,str ++ netlist))
					(initialIfcs,"")
					mods)

initialIfcs = fromList [("mkEHR", ehrIfc), ("mkRegFile", regFileIfc)]

wireSize int = if int > 1
	then "[" ++ show (int - 1) ++ ":0] "
	else ""

data WhichMeth = FP | DEF

getMethNames which name typ args =
	(case which of {FP -> "input "; DEF -> "output "}, "", "RDY_" ++ name):
	(case typ of
		Value 0 -> []
		otherwise -> [(case which of {FP -> "output "; DEF -> "input "}, "", "EN_" ++ name)] ) ++
	(case typ of
		Value size -> [(case which of {FP -> "input "; DEF -> "output "}, wireSize size, name)]
		otherwise -> [] ) ++
	[(case which of {FP -> "output "; DEF -> "input "}, wireSize y, x) | (x, y) <- args]

getModuleFpDefNames fs ds = concat $
	[getMethNames FP name typ args | Fp name typ args <- fs] ++
		[getMethNames DEF name typ args | (name, Method typ args _) <- Map.toList ds]

prettyPrint (modIfcs,
	mName,
	mapBinds,
	mapInsts,
	listRules,
	mapMeths,
	listFps,
	schedulerInf) =
	if mName == "mkEHR" || mName == "mkRegFile"  
		then "" 
		else
			"module " ++ mName ++"(CLK, RST_N" ++ concat [", " ++ z | (_, _, z) <- fpDefNames] ++");\n" ++
			"\tinput CLK;\n\tinput RST_N;\n" ++
			concat [ "\t" ++ x ++ y ++ z ++ ";\n"| (x, y, z) <- fpDefNames] ++
			concat (List.map 
				(\(n,bind) -> prettyPrintBindW (n,bind))   
				$ Map.toList mapBinds)
			++
			concat (List.map 
				(\n-> "\twire "++ "RDY_"++n++";\n"
					++ "\twire "++ "EN_"++n++";\n")
				$ listRules)
			++
			concat (List.map 
				(\(n,inst) -> prettyPrintInst modIfcs (n,inst))
				$ Map.toList mapInsts )
			++
			concat (List.map 
				(\(n,bind) -> prettyPrintBindA mapBinds (n,bind))   
				$ Map.toList mapBinds)
			++
			concat (List.map 
				(\(n,l) -> prettyPrintSched n l) 
				$ Map.toList schedulerInf)
			++ "endmodule\n"
	where
		fpDefNames = getModuleFpDefNames listFps mapMeths

prettyPrintFp (n,size,args) =
	prettyPrintMethod ("fp1_" ++ n, size, [("fp1_" ++ x,y) | (x,y) <- args]) ++
	prettyPrintMethod ("fp2_" ++ n, size, [("fp2_" ++ x,y) | (x,y) <- args])

prettyPrintMethod (n,size,args)=
	(if size /= -1 then "\tinput " ++ wireSize size ++ n ++ " ;\n" else "") ++ 
	"\tinput " ++ "RDY_" ++ n ++ " ;\n" ++ 
	"\toutput " ++ "EN_" ++ n ++ " ;\n" ++
	concatMap
		(\(arg,s) -> "\toutput " ++ wireSize s ++ arg ++ ";\n" )
		args	

prettyPrintInst modIfcs (name,inst) =
	fpDefInstsW ++
	"\t" ++ name ++
	" " ++
	(instModule inst) ++
	case (instWidth inst,instInit inst, instSize inst) of
		(Expr None _ ,Expr None _ ,Expr None _ ) -> "\n" 
		otherwise -> "#(" ++ (intercalate "," . Maybe.catMaybes $ [showExp . instWidth, showExp . instInit , showExp . instSize] <*> [inst] ) ++");\n" 
	++ "(.CLK(CLK), .RST_N(RST_N)"
	++ fpDefInstsAll
	++ ");\n"
	where
		fpDefInsts = getModuleFpDefNames (fpsInModule mod) (methodsInModule mod)
			where mod = modIfcs Map.! instModule inst
		fpDefInstsW = concat [ "\t wire " ++ y ++ name ++ "$" ++ z ++ ";\n" | (_, y, z) <- fpDefInsts]
		fpDefInstsAll = concat [ ", ." ++ z ++ "(" ++ name ++ "$" ++ z ++ ")" | (_, _, z) <- fpDefInsts]
		showExp (Expr None l) = Nothing
		showExp (Expr _ l) = Just $ case l of
			[] -> undefined
			[a] -> a 	 
			otherwise -> "{"++intercalate "," l  ++ "}" 	

prettyPrintBindW (bn, Binding ba bz bexpr) = 
  "\twire " ++ case ba of 
			Nothing -> ""
			Just val -> wireSize val
  ++ wireSize bz
  ++ bn ++ " ;\n"


prettyPrintBindA mapBinds (bn, Binding ba bz bexpr) = 
	"\tassign " ++ bn ++ " = " ++
	prettyPrintExp mapBinds bexpr ++ ";\n"


prettyPrintExp mapBinds (Expr op listArgs) = case op of 
	None -> intercalate " " listArgs  
	Unary s -> s ++ intercalate " " listArgs 
	Binary s 
		| s !! 0 /= '.' -> intercalate (" " ++ s ++ " ") listArgs
		| otherwise -> "$signed("++listArgs !! 0 ++ ")" ++ tail s ++ "$signed(" ++ listArgs !! 1 ++ ")" 
	Word s 
		| s == "concat" -> "{ " ++ intercalate (", ") listArgs ++ " }"
		| s == "extract" -> head listArgs ++ "[ " ++ listArgs !! 1 ++ " : " ++ listArgs !! 2 ++ " ]" 
		| s == "_if_" -> head listArgs ++ " ? " ++ listArgs !! 1 ++ " : " ++ listArgs !! 2
		| s == "PrimBuildArray" -> ""
		| s == "PrimArrayDynSelect" -> "" -- List.foldl (\(count, acc) x -> (count+1, acc ++ " : (" ++ x ++ " == " ++ show count ++ " ? " ++ ))
		| otherwise -> s  ++ "(" ++ (intercalate ", " listArgs) ++ ")"
	MethCall (x,y) -> x ++ "$" ++ y
	Rdy (x, y) -> x ++ "$RDY_" ++ y
	where
		Expr _ arr = bindExpr $ mapBinds Map.! head listArgs
		sel = listArgs !! 1

prettyPrintSched (x,y) l =
	"\tassign EN_" ++ y ++ " = 1'b1" ++ concatMap (\(a,b) -> " && ! " ++ printTerm (a,b)  ) l ++ ";\n"
	where
		printTerm (a,b) = if a == "fp" || a == "this" 
				then "EN_" ++ b else "EN_" ++ a ++ "_" ++ b 


