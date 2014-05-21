--module PrettyPrint where
import DataTypes
import Netlist
import Conflict
import ModuleParser
import Scheduler
import CalledMethods
import System.IO
import Text.Parsec
import Text.Parsec.String
import Data.Map as Map
import Data.Maybe as Maybe
import Data.List as List
import Control.Applicative
import Text.Read as Read


main :: IO ()
main = do
	filenameinput <- getLine
	parsed <- parseFromFile modulesParser filenameinput
	case parsed of
 	--	Left _ -> putStrLn "Parse error: You think I will provide you useful information to help you debug your code: Not at all"
		Left error -> putStrLn $ show error
		Right mods -> do
		--putStrLn ( show mods)
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
				netlist = prettyPrint modIfcs m mName mapBinds mapInsts listRules mapMeths listFps schedulerInf 
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
		Value size 	| args == [] -> []
								| otherwise -> [(case which of {FP -> "output "; DEF -> "input "}, "", "EN_" ++ name)] 
		otherwise -> [(case which of {FP -> "output "; DEF -> "input "}, "", "EN_" ++ name)] ) ++
	(case typ of
		Action -> []
		Value size -> [(case which of {FP -> "input "; DEF -> "output "}, wireSize size, name)]
		ActionValue size -> [(case which of {FP -> "input "; DEF -> "output "}, wireSize size, name)] ) ++
	[(case which of {FP -> "output "; DEF -> "input "}, wireSize y, x) | (x, y) <- args]

getModuleFpDefNames fs ds = concat $
	[getMethNames FP name typ args | Fp name typ args <- fs] ++
		[getMethNames DEF name typ args | (name, Method typ args _) <- Map.toList ds]

-- TODO method calls including instances
-- Dealing with formal parameters
prettyPrint modIfcs mod mName mapBinds mapInsts listRules mapMeths listFps schedulerInf =
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
				(\(n,inst) -> prettyPrintInst mod modIfcs (n,inst))
				$ Map.toList mapInsts )
			++
			prettyPrintCalledMethods mod modIfcs (getBothCaller mod)
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

{-
				case (instWidth inst,instInit inst, instSize inst) of
					(Expr None _ ,Expr None _ ,Expr None _ ) -> "\n" 
					otherwise -> "#(" ++ (intercalate "," . Maybe.catMaybes $ [showExp . instWidth, showExp . instInit , showExp . instSize] <*> [inst] ) ++");\n" 
-}

prettyPrintInst mod modIfcs (name,inst) =
	if instModule inst == "mkEHR" --NO INSTANCE SIZE HERE
		then  	concat [getWireForR i ++ getWireForW i | i <- ehrList ] ++ 
			"\tmkEHR#(" ++ getVal instWidth ++ ", " ++ getInit instInit ++ ") " ++ name ++
			"(.CLK(CLK), .RST_N(RST_N)" ++ 	concat [valueOfEhr i ++   argsOfEhr i ++ enOfEhr i  | i<- ehrList] ++ 
							 ");\n"
		else if instModule inst == "mkRegFile"
			then 	"\twire [" ++ getVal instSize ++ "-1:0] " ++ name ++ "$sub_x;\n" ++
				"\twire [" ++ getVal instWidth ++ "-1:0] " ++ name ++ "$sub;\n" ++
				"\twire " ++ name ++ "$EN_sub;\n" ++
				"\twire " ++ name ++ "$RDY_sub;\n" ++
				"\twire [" ++ getVal instSize ++ "-1:0] " ++ name ++ "$upd_x;\n" ++
				"\twire [" ++ getVal instWidth ++ "-1:0] " ++ name ++ "$upd_y;\n" ++
				"\twire " ++ name ++ "$EN_upd;\n" ++
				"\twire " ++ name ++ "$RDY_upd;\n" ++
				"\tmkRegFile#(" ++ getVal instSize ++ ", " ++ getVal instWidth ++ ", " ++ getVal instInit ++ ") " ++ name ++
				"(.CLK(CLK), .RST_N(RST_N)"	
								++ printArg "sub_x" name 
								++ printArg "sub" name
								++ printArg "EN_sub" name
								++ printArg "RDY_sub" name
								++ printArg "upd_x" name 
								++ printArg "upd_y" name
								++ printArg "EN_upd" name 
								++ printArg "RDY_upd" name ++ ");\n"
			else
				fpDefInstsW ++
				fst callerAllRdy ++ 
				fst callerAllRes ++
				--concat [potentiallyCalledMethod name y  |   y <- Map.keys (methodsInModule $ modIfcs Map.! (instModule inst)) ]  ++
				"\t" ++ (instModule inst) ++
				" " ++
				name ++ --TODO I THINK WE NEED A \n here
				"(.CLK(CLK), .RST_N(RST_N)" ++
				fpDefInstsAll ++
				");\n"
	where
		callerRes i str apInstName apMethName modName = "\tassign "++ name ++ "$" ++ str ++ fpName ((fpsInModule (modIfcs  Map.! modName)) !! i)  
							++ " = " ++ apInstName ++ "$"++ str  ++ apMethName ++ ";\n"
		callerAllRes = List.foldl (\(str,i) (x,y) -> let (typ, _, _) = (methodsInModule (modIfcs Map.! instModule (instances mod Map.! x))) Map.! y
							     in	(str ++ if isNotActionMethod typ  
										then callerRes i "" x y (instModule inst)
										else ""
								,i+1)) ("",0) $ instArgs inst
		callerAllRdy = List.foldl (\(str,i) (x,y) -> (str ++ callerRes i "RDY_" x y (instModule inst),i+1)) ("",0) $ instArgs inst
		getInit ins = let Expr _ args = ins inst in "{"++ intercalate "," args ++ "}"
		printArg n1 n2 = ", ."++n1++"("++n2++"$"++n1++")"
		getWireForR i = "\twire [" ++ getVal instWidth ++ "-1:0] " ++ name ++ "$r"++ show i ++";\n" ++ 
				"\twire " ++ name ++ "$RDY_r"++ show i ++";\n" 
		getWireForW i = "\twire [" ++ getVal instWidth ++ "-1:0] " ++ name ++ "$w"++ show i ++"_x;\n" ++
				"\twire " ++ name ++ "$EN_w"++ show i ++";\n"++ 
				"\twire " ++ name ++ "$RDY_w"++ show i ++";\n" 
		argsOfEhr i = printArg ("w"++show i++"_x") name 
		enOfEhr i =  printArg ("EN_w"++show i) name ++ printArg ("RDY_w" ++ show i) name 
		valueOfEhr i =  printArg ("r"++show i) name ++ printArg ("RDY_r" ++ show i) name 
		getVal f = let Expr _ args = (f inst) in head args
		fpDefInsts = getModuleFpDefNames (fpsInModule mod) (Map.map (\(typ, args, _) -> (Method typ args [])) $ methodsInModule mod)
			where mod = modIfcs Map.! instModule inst
		fpDefInstsW = concat [ "\twire " ++ y ++ name ++ "$" ++ z ++ ";\n" | (_, y, z) <- fpDefInsts]
		fpDefInstsAll = concat [ ", ." ++ z ++ "(" ++ name ++ "$" ++ z ++ ")" | (_, _, z) <- fpDefInsts]
		showExp (Expr None l) = Nothing
		showExp (Expr _ l) = Just $ case l of
			[] -> undefined
			[a] -> a 	 
			otherwise -> "{"++intercalate "," l  ++ "}"
	
isNotActionMethod typ = case typ of {Action -> False ; otherwise -> True}

prettyPrintCalledMethods mod modIfcs bothMod =
	concat [potentiallyCalledMethod x y | (x, y) <- allDefinedMethods ++ allFps]
	where
		nonZeroVMethod typ list = not (case typ of {Value _ -> list == []; otherwise -> False})
		orMethOrRuleCaller listOfCalls = intercalate " || " $ List.map
							(\(rlName,cond,_)-> 	"(EN_" ++
									rlName ++ " == 1'b1 && " ++
									cond ++ " == 1'b1)") 
							listOfCalls
		orInstCaller listInstsArg = intercalate " || " $ List.map (\(x,y,_) -> "("++y++"$EN_"++x++" == 1'b1)") listInstsArg 
		enForCalled methOrRuleList x y = 	let lFp = concat [findTheCalled localInst nI x y| (nI,localInst) <- Map.toList $ instances mod ] in
			"\tassign " ++ x ++ "$EN_" ++ y ++ " = " ++
			intercalate " || " (List.filter (\x->x/="") ["1'b0", orMethOrRuleCaller methOrRuleList, orInstCaller lFp]) ++ ";\n"
		-- Below should return (fpName, instName, fpargs)
		findTheCalled myInst iName x y =
			List.map (\number-> let	targetFp = fpsOfInstModule !! number 
													 in	(fpName targetFp, iName, List.map fst $ fpArgs targetFp ))
				. fst $ List.foldl
									(\(list,numb) arg -> if arg == (x,y) 
																	then ((numb:list),numb+1) 
																	else (list, numb+1)) 
									([],0)
									(instArgs myInst)
			where
				mname = instModule myInst
				fpsOfInstModule = fpsInModule $ modIfcs Map.! mname
		getFp y = List.head $ List.filter (\(Fp x _ _) -> x == y) (fps mod)
		allDefinedMethods = [(x, z)|(x,y) <- Map.toList $ instances mod, z <- Map.keys $ methodsInModule (modIfcs Map.! instModule y)]
		allFps = [("fp1", x)|Fp x _ _ <- fps mod] ++ [("fp2", x)|Fp x _ _ <- fps mod]
		potentiallyCalledMethod x y =
							-- TAKE CARE OF FP IN THE NEXT LINE ALONE, THEN IT'S DONE
								(if nonZeroVMethod typ argsOfCalled 
									then enForCalled callerOfCurrentThing x y 
									else "") ++
									allArgsForCalled 
										x
										y
										callerOfCurrentThing
										(List.map fst (argsOfCalled))
								where
									(typ, argsOfCalled, _) = if fpM x
																						then let Fp _ t args = getFp y in (t, args, [])
																						else (methodsInModule (modIfcs Map.! instModule (instances mod Map.! x))) Map.! y
									callerOfCurrentThing = if not (Map.member (x, y) bothMod)
																					then []
																					else (bothMod Map.! (x, y))
		allArgsForCalled x y callerOfCurrentThing argsNames = concat [ 	"\tassign " ++
							x ++ "$" ++ y ++ "_" ++ (argsNames !! i)  ++ " = " ++
							argsForCalledInAllFp i (argsForCalled i callerOfCurrentThing) x y ++ ";\n" | i <- [0..List.length argsNames-1]] 
		argsForCalledInAllFp i init a b = List.foldl
							(\acc (n,localInst) ->
										let allCallInsideInst = findTheCalled localInst n a b 
										in List.foldl 
											(\acc1 (x,iN,lArgs) -> basicIfThenElse
													(iN++"$EN_"++x++" == 1'b1") --n=iN
													(iN++"$"++ lArgs !! i)
													acc1) 
											acc 
											allCallInsideInst)
							init
							(Map.toList $  instances mod) 
		argsForCalled i lC = List.foldl
					(\acc (n, cond, largs) -> basicIfThenElse
								("(EN_" ++ n ++ " == 1'b1 && " ++ cond ++ " == 1'b1)")
								( largs !! i)
								acc)
					"0" -- TO CHANGE
					lC 

prettyPrintBindW (bn, Binding ba bz bexpr)
	| Nothing <- ba = "\twire " ++ wireSize bz ++ bn ++ " ;\n"
	| otherwise = ""

prettyPrintBindA mapBinds (bn, Binding ba bz bexpr) 
	| Expr (Word x) _ <- bexpr, x=="PrimBuildArray" = "" 
	| otherwise =		"\tassign " ++ bn ++ " = " ++
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
		| s == "PrimArrayDynSelect" -> fst ( List.foldl (\(accstr,num) currentE ->(basicIfThenElse (sel ++ " == " ++ show num ) (arr !! num ) accstr, num-1 ) )
								("",List.length arr-1)
								arr) 
		| otherwise -> s  ++ "(" ++ (intercalate ", " listArgs) ++ ")"
	MethCall (x,y) -> x ++ "$" ++ y
	Rdy (x, y) -> x ++ "$RDY_" ++ y
	where
		Expr _ arr = bindExpr $ mapBinds Map.! head listArgs
		sel = listArgs !! 1



basicIfThenElse i t e
			| e == "" = "( " ++ t ++ " )"
			| otherwise ="( "++ i ++ " ? " ++ t ++ " :" ++ e ++ " )" 

prettyPrintSched (x,y) l =
	"\tassign EN_" ++ y ++ " = 1'b1" ++ concatMap (\(a,b) -> " && ! " ++ printTerm (a,b)  ) l ++ ";\n"
	where
		printTerm (a,b) = if a == "fp" || a == "this" 
				then "EN_" ++ b else "EN_" ++ a ++ "_" ++ b 


