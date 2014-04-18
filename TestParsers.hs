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
import Text.Parsec.Prim

import qualified Text.ParserCombinators.Parsec.Token as P

--
-- DataTypes : It's the output of the parser


--AST of ATS

data Expression = Renaming String
	| And String String
	| Or String String
	| Not String
	| Mux String String String
	| RShift String String 
	| LShift String String
	| Extract String String String 
	| MCall MExpression --The same
	| Equal String String
	| Concat [String] --Concat wires
	| Plus String String
	| Sext String
	| BNot String
	| Times String String
	| Divide String String
	| Modulus String String
	| Lt String String
	| Gt String String 
	| LtEq String String
	| GtEq String String 
	| ULt String String
	| UGt String String
	| PrimArrayDynSelect String String 
	| ULtEq String String
	| UGtEq String String 
	| BAnd String String
	| BOr String String 
	| BXor String String
	| NotEqual String String
	| Minus String String
	| R3Shift String String
	| L3Shift String String
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
	, instModule :: String
	, instArgs :: [ String ]
} deriving(Show,Eq)--Done

data Binding = Binding {bindName :: String
	, bindSize :: Integer 
	, bindExpr :: Expression
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
data MExpression = MExpression {calledCond :: Maybe String 
	, calledModule :: String
	, calledMethod :: String 
	, calledArgs :: [ String ]
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
  P.commentLine = "**",
  P.nestedComments = False,
  P.opStart =  trace "l103" $ undefined,
  P.opLetter = trace "l104" $ undefined,
  P.reservedOpNames = trace "l105" $ undefined,
  P.identStart      = alphaNum <|> oneOf "_$\'",
  P.identLetter     = alphaNum <|> oneOf "_$\'",
  P.reservedNames   = [ 
                      ],
  P.caseSensitive   = True
}

--operator   = choice $ map string ["++","||","&&","+","-"]  --Operators supported 
whiteSpace = P.whiteSpace lexer  --comments are judged as whitespaces
brackets   = P.brackets lexer
braces     = P.braces lexer
semi       = P.semi lexer
dot 	   = P.dot lexer
comma      = P.comma lexer
colon      = P.colon lexer
quotedString = between (symbol "\"") (symbol "\"") (many $ noneOf "\"")
identifier = try typedIdentifier <|> try quotedString <|> P.identifier lexer
typedIdentifier = parens (symbol "_" *> option "_" (brackets $  P.identifier lexer) <* symbol "::" <* symbol "Bit" <* integer)  --To avoid useless recursivity 
lexeme     = P.lexeme lexer
reserved   = P.reserved lexer    
reservedOp = P.reservedOp lexer
symbol	   = P.symbol lexer
integer    = P.integer lexer
parens     = P.parens lexer
emptyArea  = many $ char ' ' <|> char '\t' <|> char '\n'

--
-- Parser of arguments / guards. 
-- It's a more general Parser than the identifier
-- e.g "8d'5464" is parsed  by guardParser.
-- 
--

opParser = emptyArea *> (many1 $ noneOf ['\n',' ','\t',';']) <* emptyArea   



---
--- Main Parser : Parser for modules.
---


modulesParser :: Parser [Module]
modulesParser = do
	many . try $ do{manyTill anyChar (try $ symbol "=== ATS:");moduleParser}
	
-- My idea : one file for each module.

moduleParser :: Parser Module
moduleParser = do
	manyTill anyChar (try $ reserved "APackage") 
	nameModule <- identifier
	listInstancesAndFormalParameters <-  instancesParser
	manyTill anyChar . try $ symbol "-- AP local definitions"	
	listBindings <- lookAhead . many . try $ do{manyTill anyChar (lookAhead.try $ bindingParser);bindingParser}
	manyTill anyChar . try $ symbol "-- AP rules"	
	listRules<- many . try $ ruleParser
	manyTill anyChar . try $ symbol "-- AP scheduling pragmas"	
	listMethods <- many . try $ do{manyTill anyChar ((lookAhead $ symbol "-----") *> return undefined <|> (try . lookAhead $ methodParser)); methodParser}  --Little bit Hacky TODO...
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
	  where process [] l fp = []
		process (t:q) l fp = case t of
					Left a -> (Left a{instArgs = (extr l $instName a)}):(process q l fp)
					Right (a,b) ->(Right(a, map words . instArgs . head $ fp, b)):(process q l fp)
					--If hd fails it's that there is no priority list in the sourcecode	
		extr [] n= []
		extr (t:q) n = if n == instName t then instArgs t else extr q  n

instanceParser :: Parser (Either Instance ([Fp], Map.Map (String,String) Conflict))
instanceParser = do
	toTrash <- manyTill anyChar ((try . lookAhead $ do{test<- identifier
						; symbol "::" <* symbol "ABSTRACT"}))
	nameInst <- identifier
	symbol "::"
	symbol "ABSTRACT:"
	notImportant <- identifier `sepBy` dot
	--Well, not important but we store, never know
	symbol "=" 
	nameModule <- identifier 
        return $ Left Instance {instName = nameInst 
			, instModule = nameModule 
			, instArgs = [] }


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
	symbol "::" <* symbol "Bit"
	size <- integer <* semi              
--We parse the second line with the same name
	symbol name <* symbol "="
	expression <- expressionParser	
	return $ Binding{bindName = name
			, bindSize = size    --Check that 
			, bindExpr = expression}

expressionParser :: Parser Expression
expressionParser = (try renamingParser <|> try listParser  <|> try unaryParser <|> try callMethodParser<|> try binaryParser) 

renamingParser :: Parser Expression
renamingParser = do
	name <- identifier <* semi
	return $ Renaming name  

listParser :: Parser Expression
listParser = do
	first <- identifier
	symbol "++"   
	list  <- (try identifier) `sepBy1` symbol "++"  
	semi
	return . Concat $ first:list  --Check this code -> It was false in my opinion

callMethodParser :: Parser Expression
callMethodParser = do
	nameList <- identifier `sepBy1` dot   --TODO check that the list is always composed of 2 elements
	args <- many $ identifier
	semi
	return . MCall $ MExpression{calledCond = Nothing
				, calledModule = nameList !! 0
				, calledMethod = nameList !! 1
				, calledArgs = args } 	


binaryParser :: Parser Expression 
binaryParser = do
	name1 <- identifier
	op <-  opParser --I can use operator parser
	name2 <- identifier
	semi	
	return $  k op name1 name2
	where 	k op name1 name2 = case (lookup op l) of
					Just a -> a name1 name2
					Nothing -> undefined --HACKY Fraction of BSV
		l = [("==", \x y -> Equal x y),   --Set of supported operators
			("!=", \x y -> NotEqual x y ),
			("&&", \x y -> And x y ),
			("||", \x y -> Or x y ),
			(">>", \x y -> RShift x y ),
			("<<", \x y -> LShift x y ),
			("<<<", \x y -> L3Shift x y),
			(">>>", \x y -> R3Shift x y),
			
			("<", \x y -> Lt x y ),
			(">", \x y -> Gt x y ),
			("<=", \x y -> LtEq x y ),
			(">=", \x y -> GtEq x y ),
			(".<=", \x y -> ULtEq x y ),
			(".>=", \x y -> UGtEq x y ),

			(".<", \x y -> ULt x y ),
			(".>", \x y -> UGt x y ),
			
			("&", \x y -> BAnd x y ),
			("^", \x y -> BXor x y ),
			("|", \x y -> BOr x y ),
			
			("+", \x y -> Plus x y ),
			("*", \x y -> Times x y ),
			("/", \x y -> Divide x y ),
			("%", \x y -> Modulus x y ),
			("-", \x y -> Minus x y )]

unaryParser :: Parser Expression   
unaryParser =
	choice [ k "_if_" $ do{first <- identifier
				; second <- identifier
				; third <- identifier
				; return $ Mux first second third }
              , k "extract" $ do{first <- identifier
				  ; second <- identifier 
				  ; third <- identifier 
				  ; return $ Extract first second third} -- TODO DEFINE THIS THING 
              , k "!" $ do{first <- identifier ; return  $ Not first} 
	      , k "~" $ do{first<- identifier ; return $ BNot first}
	      , k "sext" $ do{first <- identifier; return $ Sext first}
	      , k "PrimArrayDynSelect" $ do{first<- identifier; second <- identifier
					; return $ PrimArrayDynSelect first second} ] <* semi         --WHAT IS IT? TODO
  where
    k x p = (symbol x) *> p   


--
-- Parsers for rules 
-- Typical format :
-- rule RL_start "start":
--  when proc_RDY_hostToCpu_AND_NOT_state___d4
--   ==> { proc.hostToCpu 32'h1000; state.write 1'd1; }

ruleParser :: Parser Rule 
ruleParser = do
	trash <- manyTill anyChar ( (lookAhead $ symbol "-- AP scheduling pragmas") <|> (try $ symbol "rule"))
	notFollowedBy $ symbol "-- AP scheduling pragmas"
	processedName <- identifier 
	realName <- identifier <* colon               --CHECK THAT	
	guard <- symbol "when" *> identifier <* symbol "==>"
 	listExpr <- braces $ (many $ (try ifMethodCallParser) <|> (try methodCallParser)) 	 		
	return $ Rule{ruleName = processedName 
			, ruleGuard = guard
			, ruleBody = toMExpr listExpr}
	where toMExpr = map (\(t,x,y,z) -> MExpression{calledCond = t, calledModule = x, calledMethod = y, calledArgs = z})	


		
-- Parser for bodies of methods/rules

ifMethodCallParser = do
	nameCond  <- symbol "if" *> identifier <* symbol "then"
	(cond,moduleName,methodName,args) <- methodCallParser
	return $ (Just nameCond, moduleName, methodName, args)    	

methodCallParser = do 
	moduleName <- identifier <* symbol "."
	methodName <- identifier
        args <- (many $ identifier) <* semi 
	return $ (Nothing, moduleName, methodName, args)


--
-- Parsers for methods
--
--
-- /!\			 /!\
-- /!\TODO: Need clean up/!\
-- /!\			 /!\

data ResultOrArg = Result | Arg deriving(Show,Eq)

typeMethodParser :: Parser Bool
typeMethodParser = 
	 (try (symbol "AIDef") *> return True) <|>
	 (try (symbol "AIAction") *> return False) <|>
	 (try (symbol "AIActionValue") *> return False) <|>
	 ((symbol "AIValue") *> return True)


methodParser :: Parser Method
methodParser = do  --USE THE COMMENTS
	isValue <- symbol "--" *> typeMethodParser
	nameM <- identifier
	listArgs <- many $  (try resultParser) <|> try argMethodParser
	let (lResult, lArgs) = List.partition (\(x,y,z) -> x == Result) listArgs
	method <- (brackets $ try methodBodyParser) <|> withoutBodyMethodParser
	if isValue 
		then let (_, _, size) = head lResult  
			in return method{methodName = nameM
					, methodGuard = "RDY_" ++ nameM
					, methodType = process3 lArgs size
					, methodArgs = process1 lArgs}
		else return method{methodArgs = process1 lArgs, methodType = process2 lResult}
	  where	process1 = map (\(x,y,z)->(y,z)) 
		process2 res = case res of
			[] -> Action  
			[(_,_,b)] -> ActionValue b
			_ -> trace "l386" $ undefined --TODO Correct?  ActionValue	  
		process3 l n = case l of 
			[] -> Value0 n
			_ -> Value n


argMethodParser :: Parser (ResultOrArg,String,Integer)
argMethodParser = do
	name <- identifier 
	symbol "::" *> symbol "Bit"
	size <- integer <* semi                --Many digit	
	return (Arg, name, size)
		
resultParser :: Parser (ResultOrArg,String,Integer)
resultParser = do
	name <- identifier <* symbol "::" <* symbol "Bit"
	size <- integer <* semi
	--Second line : assignment
	symbol name <* symbol "="
	expression <- expressionParser	
	return $ (Result, name, size)


withoutBodyMethodParser :: Parser Method
withoutBodyMethodParser = do
	notFollowedBy . brackets $ symbol "rule" *> noneOf "]"
	brackets . symbol $ ""
      	return $ Method{methodName = undefined
				, methodGuard = undefined
				, methodType = undefined
				, methodArgs = undefined
				, methodBody = []} 
		

--TODO factorize : we can use ruleBodyParser here.
methodBodyParser :: Parser Method 
methodBodyParser = do
	symbol "rule"
	processedName <- identifier
	realName <- identifier <* colon <* symbol "when" <* identifier  <* symbol "==>"
 	listExpr <- braces $ (many $ (try ifMethodCallParser) <|> methodCallParser) 	 		
	many $ noneOf [']']    --We have to eat all the useless stuff, until the ] appears. 
	return $  Method{methodName = processedName 
			, methodGuard = "RDY_" ++ processedName  --TODO check if we need bindings
			, methodType = trace "methodType" $ undefined
			, methodArgs = trace "methodArgs" $ undefined
			, methodBody = toMExpr listExpr}
	where toMExpr = map (\(t,x,y,z) -> MExpression{calledCond = t, calledModule = x, calledMethod = y, calledArgs = z})	




--
-- Parser for fp with FPs, BVI. 


bodyInstanceParser :: Parser (Either Instance ([Fp], Map.Map (String,String) Conflict))
bodyInstanceParser = do
	toTrash <-  manyTill anyChar . try . lookAhead $ identifier <* symbol "::" <* symbol "ABSTRACT"
	symbol "fp" <* symbol "::" <* symbol "ABSTRACT:" <* (identifier `sepBy` dot) 
	symbol "="
	nameModule <-  identifier 
	-- Eat until my position is good	
	manyTill anyChar . try . lookAhead $ (symbol "[method")
	symbol "["
	methNames <- (try parserMethName) `sepBy` comma  
	(manyTill anyChar . try $ symbol "SchedInfo")
	scheduleInfos <- brackets $ (try parserSchedule) `sepBy`  comma
	let mapScheduling = foldl (\map (x,y,z) -> Map.insert (x,y) z map) Map.empty $ concat scheduleInfos   

	
        manyTill anyChar . try $ symbol "meth" <* symbol "types" <* symbol "="
	typesMethods <- brackets $ (try.parens $ parseTripletTypes) `sepBy` comma  
	let finalList = process typesMethods (snd . unzip $ methNames) (fst . unzip $ methNames)
	return $ (Right (finalList, mapScheduling))
	where 	process l1 l2 t= f t $ List.zip l1 l2
	      	f t [] = []	      
		f (t:e) (((lArgsT,trigger,result),(mName,lArg)):q) = Fp{fpName = mName --TODO we forgot the trigger here.
				, fpType = sayMeMyType lArgsT result t
				, fpArgs = zip lArg lArgsT }:(f e q)
		sayMeMyType args res bl = case res of              --TODO : hardly defined before ... factorization
					Nothing -> Action  
					Just b  -> case args of
						[] -> if bl then Value0 b else ActionValue b
						_  -> if bl then Value b else ActionValue b --TODO : need a hack for actions value

-- method (cpuToHost, [])cpuToHost enable ((EN_cpuToHost,
-- [])) clocked_by (default_clock) reset_by (default_reset);,

parserMethName :: Parser (Bool,(String,[String]))
parserMethName = do
	symbol "method"
	option "" . parens . try . many $ noneOf [')']
	nameMeth <- identifier 
	args <- option [] . parens $ (try . parens $ do{name<-identifier <* comma
					; brackets . many $ noneOf [']']
					; return name}) `sepBy` comma
	--Throw it away!
	
	isNotActionValue <- option "___ISNOTANACTIONVALUE" $ symbol "enable"   --DIRTYTRICK TODO
	option "" . parens . parens . try . many $ noneOf [')']
	symbol "clocked_by" 
	option "" . parens . try . many $ noneOf [')']
	symbol "reset_by"
	option "" . parens . try . many $ noneOf [')']
 	semi 
	return (isNotActionValue == "___ISNOTANACTIONVALUE", (nameMeth, args))	 	    
	

-- Disgusting hacks here. ** Need refactoring **
-- /!\/!\/!\/!\/!\/!\/!\/!\/!\/!\/!\/!\/!\/!\/!\
-- /!\ Lot of undefined behaviour are critic./!\
-- /!\/!\/!\/!\/!\/!\/!\/!\/!\/!\/!\/!\/!\/!\/!\

parserSchedule :: Parser [(String, String, Conflict)]
parserSchedule = do
	r1 <- ((try.brackets.many $ noneOf [']']) <|> try identifier) 
	op <- identifier
	r2 <- ((try.brackets.many $ noneOf [']']) <|> identifier)
	return $ allCombines (inter r1) (inter r2) $ process op
	where 	inter l = S.split [','] $ filter (\x -> x /= ' ' && x /= '\n' ) l --DON'T LOOK AT THIS 
		allCombines [] l e = []
		allCombines (t:q) l e = allCombine t l e ++ allCombines q l e
		allCombine a [] e = []
		allCombine a (t:q) e = (a,t,e) : allCombine a q e	  
		process op = case lookup op l of
				Just a -> a
				Nothing -> trace "l454" $ undefined --Should not happen, ATS provided by BSC compiler
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
	symbol "Bit"
	val <- integer
	return $ val  

maybeParser :: Parser (Maybe Integer)
maybeParser = (try justP)<|>nothingP 

justP :: Parser (Maybe Integer)
justP = do
	symbol "Just"
	extract <- parens $ bitParser
	return $ Just extract


nothingP :: Parser (Maybe Integer)
nothingP = do
	symbol "Nothing"
	return Nothing


--
--Formal parameters parser : use docs of BSV.
--

formalParametersParser :: Parser [Instance]
formalParametersParser = many $ try formalParameterParser

formalParameterParser :: Parser Instance
formalParameterParser = do
	name <- identifier <* colon
	par <- parens . many $  (try.parens.many $ noneOf [')']) <|> identifier  
	return Instance{instName = name
 		, instModule = "hack" --I don't remember why I thought it was smart to return Instance ... 
		, instArgs = par}

--
-- Tools
--

numberValue :: Integer -> String ->  Integer
numberValue n [a] = toInteger . digitToInt $ a 
numberValue n (t:q) =n*(numberValue n q) + (toInteger . digitToInt $  t)




