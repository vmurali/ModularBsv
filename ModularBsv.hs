import Netlist
import PrettyPrint
import Text.Parsec
import Text.Parsec.String
import ModuleParser

main :: IO ()
main = do
	filenameinput <- getLine
	parsed <- parseFromFile modulesParser filenameinput
	case parsed of
 	--	Left _ -> putStrLn "Parse error: You think I will provide you useful information to help you debug your code: Not at all"
		Left error -> putStrLn $ show error
		Right mods -> do
		--putStrLn ( show mods)
		putStrLn . snd $ (foldl (\(acc,str) m -> 
			let
				modIfcs = buildModuleIfc acc m
				netlist = prettyPrint modIfcs m
				in ( modIfcs ,str ++ netlist))
					(initialIfcs,"")
					mods)

