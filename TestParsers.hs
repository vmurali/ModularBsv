module TestParsers where

import Control.Monad
import Control.Exception (assert)
import Control.Applicative hiding ((<|>), many)
import Data.Char
import qualified Data.List as List
import qualified Data.Maybe as Maybe
import qualified Data.Map as Map
import qualified Data.String.Utils as S
import qualified Data.Either as E

import Debug.Trace
import Text.Parsec hiding (token)
import Text.Parsec.String

import qualified Text.ParserCombinators.Parsec.Token as P

--
-- DataTypes : It's the output of the parser


--AST of ATS

data Expression = And String String
	| Or String String
	| Not String
	| Mux String String String
	| Extract String Integer Integer 
	| MCall MExpression --The same
	| Equal String String
	| Concat [String] --Concat wires
	| Plus String String
	| Minus String String
	deriving(Show,Eq)

data Module = Module { name :: String
	, instances :: [ Instance ]
	, bindings :: [ Binding ]
	, rules :: [ Rule ]
	, methods :: [ Method ]
	, fps :: [ Fp ]
	, conflictMatrix :: Map.Map (String, String) Conflict 
	, priorityList :: [ [ String ] ]
} deriving(Show,Eq)--Done

data Conflict =  C | CF | SB | SA deriving(Show,Eq)

data Instance = Instance {instName :: String
	, moduleName :: String
	, args :: [ String ]
} deriving(Show,Eq)--Done

data Binding = Binding {bindName :: String
	, size :: Integer 
	, expression :: Expression
} deriving(Show,Eq)--Done

data Rule = Rule {ruleName :: String
	, ruleGuard :: String 
	, ruleBody :: [ MExpression ]
} deriving(Show,Eq)--Done


data Method = Method {methodName :: String
	, methodGuard :: String 
	, methodType :: TypeOfMethod  
	, methodArgs :: [(String, Integer)]
	, methodBody :: [ MExpression ]
} deriving(Show,Eq) --Done

data Fp = Fp {fpName :: String
	, fpType :: TypeOfMethod
	, fpArgs :: [ (String,Integer) ]
} deriving(Show,Eq)

-- Unit operations in the body of a method.
data MExpression = MExpression {cond :: Maybe String 
	, moduleCalledName :: String
	, calledMethod :: String 
	, argsMethod :: [ String ]
} deriving(Show,Eq)--Done 


--The integers are the size of the result
data TypeOfMethod = Value Integer  
	| Value0 Integer
	| Action
	| ActionValue Integer
	deriving(Show,Eq)
--
--Lexer and Parsers of the ATS language 
--

lexer = P.makeTokenParser defn

defn = P.LanguageDef {
  P.commentStart = "/*",
  P.commentEnd = "*/",
  P.commentLine = "--",
  P.nestedComments = False,
  P.opStart =  undefined,
  P.opLetter = undefined,
  P.reservedOpNames = undefined,
  P.identStart      = letter,
  P.identLetter     = alphaNum <|> char '_',
  P.reservedNames   = [ 
                      ],
  P.caseSensitive   = True
}

--operator   = choice $ map string ["++","||","&&","+","-"]  --Operators supported 
whiteSpace = P.whiteSpace lexer  --comments are judged as whitespaces
brackets   = P.brackets lexer
braces     = P.braces lexer
semi       = P.semi lexer
comma      = P.comma lexer
colon      = P.colon lexer
identifier = P.identifier lexer
lexeme     = P.lexeme lexer
reserved   = P.reserved lexer    
reservedOp = P.reservedOp lexer
parens     = P.parens lexer
wSpace     = many $ char ' ' <|> char '\t'
emptyArea  = many $ char ' ' <|> char '\t' <|> char '\n'

--
-- Parser of arguments / guards. 
-- It's a more general Parser than the identifier
-- e.g "8d'5464" is parsed  by guardParser.
-- 
-- TODO : Maybe we can always replace [identifier] by [guardParser]
--

guardParser = emptyArea *> (many1 $ noneOf ['\n',' ','\t',';',':','(',')',',','=']) <* emptyArea   



---
--- Main Parser : Parser for modules.
---


modulesParser :: Parser [Module]
modulesParser = do
	many . try $ do{manyTill anyChar (try $ string"=== ATS:");moduleParser}
	


moduleParser :: Parser Module
moduleParser = do
	manyTill anyChar (try $ string "APackage") 
	nameModule <- guardParser 
	listInstancesAndFormalParameters <-  instancesParser
	manyTill anyChar . try $ string "-- AP local definitions"	
	listBindings <- lookAhead . many . try $ do{manyTill anyChar (lookAhead.try $ bindingParser);bindingParser}
	manyTill anyChar . try $ string "-- AP rules"	
	listRules<-many . try $ ruleParser
	manyTill anyChar . try $ string "-- AP scheduling pragmas"	
	listMethods <- many . try $ do{manyTill anyChar (try . lookAhead $ methodParser); methodParser}
	let (inst,l) = E.partitionEithers listInstancesAndFormalParameters 
	return $ Module{name=nameModule  --Test name
			, instances = inst
			, bindings = listBindings
			, rules = listRules
			, methods = listMethods
			, fps = if null l then []  else (\(x,y,z)->x).head $ l
			, conflictMatrix = if null l then Map.empty else (\(x,y,z)->z).head $ l
			, priorityList = if null l then [] else (\(x,y,z)->y).head $ l} 


---
--- Parser for instances
---


instancesParser :: Parser ([Either Instance ([Fp], [[String]], Map.Map (String,String) Conflict)])
instancesParser = do
	--Either FP, either instance
	listInstances <- lookAhead . many $ (try bodyInstanceParser) <|> (try instanceParser)
	listFp <- apInstanceDocParser
	let (listWithoutFp,singleFp) = List.partition (\x -> instName x /= "fp") listFp
	return $ process listInstances listWithoutFp singleFp
	  where process [] [] fp = []
		process (t:q) [] fp = case t of
					Left a -> (Left a):(process q [] fp)
					Right (a,b) ->(Right(a, map words . args . head $ fp, b)):(process q [] fp)
		process (t:q) (r:s) fp = case t of 
					Left a      -> if instName a == instName r then
							(Left(a{args=args r})):(process q s fp)
							else (Left a):(process q (r:s) fp)
					Right (a,b) ->(Right(a, map words . args . head $ fp, b)):(process q s fp)
					--If hd fails it's that there is no priority list in the sourcecode	


instanceParser :: Parser (Either Instance ([Fp], Map.Map (String,String) Conflict))
instanceParser = do
	toTrash <- manyTill anyChar ((try . lookAhead $ do{test<- guardParser
						; string ":: ABSTRACT"
						; return test}))
	nameInst <- guardParser
	string ":: ABSTRACT:"
	notImportant <- guardParser
	--Well, not important but we store, never know
	string "=" 
	nameModule <- guardParser 
        return $ Left Instance {instName = nameInst 
			, moduleName = nameModule 
			, args = [] }


apInstanceDocParser :: Parser [Instance]
apInstanceDocParser = lookAhead $
	 do{manyTill anyChar $ (try $ string "-- AP instance comments\n")			
	; formalParametersParser}  



-- 
-- Parser for bindings 
--

--Need checking
bindingParser :: Parser Binding 
bindingParser = do
--We parse the first line
	name <- identifier 
	wSpace
	string ":: Bit "
	size <- many digit 		
	wSpace
	char ';'
	emptyArea
--We parse the second line with the same name
	string name <* emptyArea
	string "="
	expression <- expressionParser	
	return $ Binding{bindName = name
			, size = numberValue 10 size 
			, expression = expression}

expressionParser :: Parser Expression
expressionParser = (try listParser <|> try binaryParser <|> try unaryParser) <* string ";" 

listParser :: Parser Expression
listParser = do
	--Dirty hack. TODO sepBy2 
	first <- guardParser
	string "++"    
	list  <- guardParser `sepBy1` string "++" 
	return $ Concat $ first:list

binaryParser :: Parser Expression 
binaryParser = do
	name1 <- guardParser
	op <-  guardParser --I can use operator parser
	name2 <- guardParser	
	return $  k op name1 name2
	where 	k op name1 name2 = case (lookup op l) of
					Just a -> a name1 name2
					Nothing -> undefined --Fraction of BSV
		l = [("==", \x y -> Equal x y),   --Set of supported operators
			("&&", \x y -> And x y ),
			("||", \x y -> Or x y ),
			("+", \x y -> Plus x y ),
			("-", \x y -> Minus x y )]

unaryParser :: Parser Expression   
unaryParser =
	choice [ k "_if_" $ do{first <- guardParser
				; second <- guardParser
				; third <- guardParser
				; return $ Mux first second third }
              , k "extract" $ undefined  
              , k "!" $ undefined ]
  where
    k x p = (emptyArea *> string x) *> p


--
-- Parsers for rules 
-- Typical format :
-- rule RL_start "start":
--  when proc_RDY_hostToCpu_AND_NOT_state___d4
--   ==> { proc.hostToCpu 32'h1000; state.write 1'd1; }

ruleParser :: Parser Rule 
ruleParser = do
	manyTill anyChar . try $ string "rule"
	processedName <- guardParser         --TESTING TODO
	realName <- string "\"" *> identifier <* string "\":"	
	guard <- emptyArea *> string "when" *> guardParser 
	string "==>" <* emptyArea
 	listExpr <- braces $ (many $ (try ifMethodCallParser) <|> (try methodCallParser)) 	 		
	return $ Rule{ruleName = processedName 
			, ruleGuard = guard
			, ruleBody = toMExpr listExpr}
	where toMExpr = map (\(t,x,y,z) -> MExpression{cond = t, moduleCalledName = x, calledMethod = y, argsMethod = z})	


		
-- Parser for bodies of methods/rules

ifMethodCallParser = do
	emptyArea *> string "if" 
	nameCond  <- guardParser <* string "then" <* emptyArea
	(cond,moduleName,methodName,args) <- methodCallParser
	return $ (Just nameCond, moduleName, methodName, args)    	

methodCallParser = do 
	moduleName <- identifier <* char '.'   --TESTING TODO	
	methodName <- guardParser
        args <- many $ guardParser
	char ';' <* emptyArea
	return $ (Nothing, moduleName, methodName, args)


--
-- Parsers for methods
--
--
-- /!\			 /!\
-- /!\TODO: Need clean up/!\
-- /!\			 /!\

data ResultOrArg = Result | Arg deriving(Show,Eq)

methodParser :: Parser Method
methodParser = do
	listArgs <- many $  (try resultParser) <|> try argMethodParser
	let (lResult, lArgs) = List.partition (\(x,y,z) -> x == Result) listArgs  --TODO : check partition  
	method <- brackets $ methodBodyParser 
	return method{methodArgs = process1 lArgs, methodType = process2 lArgs lResult}
	  where	process1 = map (\(x,y,z)->(y,z)) 
		process2 args res = case res of
			[] -> Action  
			[(_,_,b)] -> case args of
				[] -> Value0 b
				_  -> Value b
			_ -> undefined --TODO Correct?  ActionValue	  


--TODO prettyfication
argMethodParser :: Parser (ResultOrArg,String,Integer)
argMethodParser = do
	name <- identifier 
	emptyArea *> string ":: Bit "
	size <- many digit 		
	emptyArea *> char ';' <* emptyArea
	return (Arg, name, numberValue 10 size)
		
resultParser :: Parser (ResultOrArg,String,Integer)
resultParser = do
	wSpace
	name <- guardParser <* string ":: Bit "  --TODO testing
	size <- many digit <* emptyArea <* char ';'
	--Second line : assignment
	emptyArea *> string name <* string " ="
	expression <- expressionParser	
	return $ (Result, name, numberValue 10 size)
		

--TODO factorize : we can use ruleBodyParser here.
methodBodyParser :: Parser Method 
methodBodyParser = do
	string "rule"
	processedName <- guardParser  --Rely on Whitespace TODO check if I can erase the "  
	realName <- string "\"" *> identifier  <* string "\":" 			
	notImportant <- emptyArea *> string "when" *> guardParser  
	string "==>" <* emptyArea
 	listExpr <- braces $ (many $ (try ifMethodCallParser) <|> methodCallParser) 	 		
	trash <- many $ noneOf [']']    --We have to eat all the useless stuff, until the ] appears. 
	return $ Method{methodName = processedName 
			, methodGuard = "RDY_" ++ processedName  --TODO check if we need bindings
			, methodType = undefined
			, methodArgs = undefined
			, methodBody = toMExpr listExpr}
	where toMExpr = map (\(t,x,y,z) -> MExpression{cond = t, moduleCalledName = x, calledMethod = y, argsMethod = z})	




--
-- Parser for fp with FPs, BVI. 
-- /!\ TODO cleanup
-- TODO : Priority INFOS BETTER 


bodyInstanceParser :: Parser (Either Instance ([Fp], Map.Map (String,String) Conflict))
bodyInstanceParser = do
	toTrash <-  manyTill anyChar ((try . lookAhead $ do{test<- guardParser <* emptyArea
						; string ":: ABSTRACT"
						; return test}))
	emptyArea *> string "fp :: ABSTRACT:"
	notImportant <- guardParser
	string "="
	nameModule <-  guardParser 
	-- Eat until my position is good	
	manyTill anyChar $ (try . lookAhead $ (string "[method"))
	char '['
	methNames <- (try parserMethName) `sepBy` (emptyArea *> comma <* emptyArea)  --TODO Testing
	(manyTill anyChar $ (try $ string "SchedInfo")) <* emptyArea    --EMPTY AREA NEEDED
	scheduleInfos <- brackets $ (try parserSchedule) `sepBy` (emptyArea *> comma <* emptyArea) --TODO Testing
	let mapScheduling = foldl (\map (x,y,z) -> Map.insert (x,y) z map) Map.empty $ concat scheduleInfos   

	
        manyTill anyChar $ try (string "meth types=")
	typesMethods <- brackets $ (try.parens $ parseTripletTypes) `sepBy` (emptyArea *> comma <* emptyArea ) 
	let finalList = process typesMethods methNames
   		
	return $ (Right (finalList, mapScheduling))
	where 	process l1 l2 = f $ List.zip l1 l2
	      	f [] = []	      
		f (((lArgsT,trigger,result),(mName,lArg)):q) = Fp{fpName = mName --TODO we forgot the trigger here.
				, fpType = sayMeMyType lArgsT result
				, fpArgs = zip lArg lArgsT }:(f q)
		sayMeMyType args res = case res of              --TODO : hardly defined before ... factorization
					Nothing -> Action  
					Just b  -> case args of
						[] -> Value0 b 
						_  -> Value b  --TODO : need a hack for actions value

-- method (cpuToHost, [])cpuToHost enable ((EN_cpuToHost,
-- [])) clocked_by (default_clock) reset_by (default_reset);,

parserMethName :: Parser (String,[String])
parserMethName = do
	emptyArea *> string "method" <* emptyArea
	option "" . parens . try . many $ noneOf [')']   --TODO Check if it"s correct
	nameMeth <- guardParser 
	args <- option [] . parens $ (try . parens $ do{name<-guardParser 
					; comma <* emptyArea 
					; brackets . many $ noneOf [']']
					; return name}) `sepBy` (emptyArea *> string "," <* emptyArea )  
	--Throw it away!
	
	option "" $ emptyArea *> string "enable" <* emptyArea 
	option "" . parens . parens . try . many $ noneOf [')']
	emptyArea *> string "clocked_by" <* emptyArea 
	option "" . parens . try . many $ noneOf [')']
	emptyArea *> string "reset_by" <* emptyArea
	option "" . parens . try . many $ noneOf [')']
 	emptyArea *> string ";" <* emptyArea 
	return (nameMeth, args)	 	    
	


-- Disgusting hacks here. ** Need refactoring **
-- /!\/!\/!\/!\/!\/!\/!\/!\/!\/!\/!\/!\/!\/!\/!\
-- /!\ Lot of undefined behaviour are critic./!\
-- /!\/!\/!\/!\/!\/!\/!\/!\/!\/!\/!\/!\/!\/!\/!\

parserSchedule :: Parser [(String, String, Conflict)]
parserSchedule = do
	r1 <- emptyArea *> ((try.brackets.many $ noneOf [']']) <|> try identifier) 
	op <- emptyArea *> identifier <* emptyArea
	r2 <- ((try.brackets.many $ noneOf [']']) <|> identifier) <* emptyArea
	return $ allCombines (inter r1) (inter r2) $ process op
	where 	inter l = S.split [','] $ filter (\x -> x /= ' ' && x /= '\n' ) l --DON'T LOOK AT THIS 
		allCombines [] l e = []
		allCombines (t:q) l e = allCombine t l e ++ allCombines q l e
		allCombine a [] e = []
		allCombine a (t:q) e = (a,t,e) : allCombine a q e	  
		process op = case lookup op l of
				Just a -> a
				Nothing -> undefined --Should not happen, ATS provided by BSC compiler
		l = [("C", C ),
			("CF", CF ),
			("SB", SB ),
			("SA", SA )]




parseTripletTypes :: Parser ([Integer], Maybe Integer, Maybe Integer)
parseTripletTypes = do
	first <- brackets $ (try bitParser) `sepBy` comma 
	comma 
	second <- maybeParser
	comma
	third <- maybeParser	
	return (first, second, third)

bitParser :: Parser Integer
bitParser = do
	emptyArea *> string "Bit" <* emptyArea
	listOfChar <- many $ digit <* emptyArea
	return $ numberValue 10 listOfChar  

maybeParser :: Parser (Maybe Integer)
maybeParser = (try justP)<|>nothingP 

justP :: Parser (Maybe Integer)
justP = do
	emptyArea
	string "Just "
	listOfChar <- parens $ (string "Bit " *> (many $ digit))
	return $ Just (numberValue 10 listOfChar) -- Decimal notation



nothingP :: Parser (Maybe Integer)
nothingP = do
	emptyArea *> string "Nothing" <* emptyArea --TODO : check
	return Nothing


--
--Formal parameters parser : use docs of BSV.
--

formalParametersParser :: Parser [Instance]
formalParametersParser = many $ try formalParameterParser

formalParameterParser :: Parser Instance
formalParameterParser = do
	name <- emptyArea *>identifier <* string ":"
	emptyArea
	par <- parens $ (many $ emptyArea *> ((try.parens.many $ noneOf [')']) <|> identifier) <* emptyArea)  
	return Instance{instName = name
 		, moduleName = "hack" --I don't remember why I thought it was smart to return Instance ... 
		, args = par}

--
-- Tools
--

numberValue :: Integer -> String ->  Integer
numberValue n [a] = toInteger . digitToInt $ a 
numberValue n (t:q) =n*(numberValue n q) + (toInteger . digitToInt $  t)




