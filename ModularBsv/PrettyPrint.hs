import DataTypes

prettyPrintBind (bn, Binding ba bz bexpr) =
  "wire " ++ bn ++ "[" ++ ba ++ "-1:0][" ++ bz ++ "-1:0]\nassign " ++ bn ++ " = " ++
  prettyPrintExp bexpr


prettyPrintExp (Expr op listArgs) = case op of 
   None -> intercalate listArgs ' '  
   Unary s -> s ++ intercalate listArgs " "
   Binary s -> intercalate listArgs $ " " ++ s ++ " "
   Word s -> intercalate listArgs $ " " ++ s ++ " "
   MethCall CalledMethod -> undefined

prettyPrintSched (x,y) l =
	"assign EN_" ++ y ++ " = "
	intercalate
		(map (\(a,b) -> "! (" ++ print (a,b) ++ ")" ) l)	
		" && "
	where
		printe (a,b) = if a == "fp" || a == "this" 
				then "EN_"++b else "EN_" ++ a ++ "_" ++ b 
