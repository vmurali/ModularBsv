module Parser where

import Control.Monad
import Control.Exception (assert)
import Control.Applicative hiding ((<|>), many)
import Data.Char
import Data.List
import qualified Data.String as S

import Text.Parsec hiding (token)
import Text.Parsec.String

import qualified Text.ParserCombinators.Parsec.Token as P

--
-- DataTypes : It's the output of the parser


--AST of ATS

data Expression =
--	| Litt String   
	| And String String
	| Or String String
	| Not String
	| Mux String String String
	| Extract String Integer Integer 
	| MCall MExpression --The same
	| Equal String String
	| Concat [String] --Concat wires
	| Plus String String
	| Minus String String

data Module = Module { name :: String
	, instances :: [ Instance ]
	, bindings :: [ Binding ]
	, rules :: [ Rule ]
	, methods :: [ Method ]
	, fps :: [ Fp ]
	, conflictMatrix :: Map (String, String) Conflict 
	, priorityList :: [ [ String ] ]
} 

data Conflict =  C | CF | SB | SA

data Instance = Instance {instName :: String
	, moduleName :: String
	, args :: [ String ]
}

data Binding = Binding {bindName :: String
	, size :: Integer 
	, expression :: Expression
}

data Rule = Rule {ruleName :: String
	, ruleGuard :: String 
	, ruleBody :: [ MExpression ]
}


data Method = Method {methodName :: String
	, methodGuard :: String 
	, methodType :: TypeOfMethod  
	, methodArgs :: [(String, Integer)]
	, methodBody :: [ MExpression ]
}

data Fp = Fp {fpName :: String
	, fpType :: TypeOfMethod
	, fpArgs :: [ (String,Integer) ]
}

-- Unit operations in the body of a method.
data MExpression = MExpression {cond :: Maybe String 
	, moduleName :: String
	, calledMethod :: String 
	, argsM :: [ String ]
}


--The integers are the size of the result
data TypeOfMethod = Value Integer  
	| Value0 Integer
	| Action
	| ActionValue Integer 

--
--Lexer and Parsers of the ATS language 
--

lexer = P.makeTokenParser defn

defn = P.LanguageDef {
  P.commentStart = "/*",
  P.commentEnd = "*/",
  P.commentLine = "--",
  P.nestedComments = False,
  P.opStart = undefined,
  P.opLetter = undefined,
  P.reservedOpNames = undefined,
  P.identStart      = letter,
  P.identLetter     = alphaNum <|> char '_',
  P.reservedNames   = [ 
                      , "rule"
                      ],
  P.caseSensitive   = True
}

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
emptyArea  = many $ wSpace <|> char '\n'

trash = undefined 



nameParser :: Parser String
nameParser = do
	string "APackage"
	wSpace
	name <- identifier
	wSpace
	return $ name  		  

--
-- Parser for Module
-- TODO

--
-- Parser for instance
--
-- Instances: 
-- [{
--    instName: proc
--    moduleName: mkProc
--    args : [names] // doc for instance (keyword :AP inst 
-- We check the formal parameters with _fp at the end of the module name


instancesParser :: Parser [Instance]
instancesParser = do
	listInstances <- many $ instanceParser
	listFp <- apInstanceDocParser
	return $ process listInstances listFp		
	  where (onlyFpInstances,_) = partition (\x -> S.endswith "_fp" (moduleName x)) listInstances
		process (t:q) ((_,r):s) =(t{args=r} :(process q s))
		process [] [] = []

 
instanceParser :: Parser Instance
instanceParser = do
	toTrash <-many $ anyChar <* notFollowedBy (identifier <* string " :: ABSTRACT")
	nameInst <- identifier
	emptyArea *> string ":: ABSTRACT:" <* emptyArea
	notImportant <- guardParser        --Well, not important but we store, never know
	emptyArea *> string "=" <* emptyArea 
	nameModule <- identifier <* emptyArea
	return $ Instance {instName = nameInst 
			; moduleName = nameModule 
			; args = undefined }


 
--
--Parsers for bindings
--

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
	string name
	string " ="
	expression <- expressionParser	
	return $ Binding{bindName = name
			; size = numberValue 10 size 
			; expression = expression}

expressionParser :: Parser Expression
expressionParser = ((try binaryParser) <|> (try listParser) <|> (try unaryParser)) <* string ";\n" 

listParser :: Parser Expression
listParser = do
	list <- (emptyArea *> guardParser <* emptyArea)  `sepBy` string "++" 
	return $ Concat list

binaryParser :: Parser Expression 
binaryParser = do
	name1 <- (emptyArea *> guardParser <* emptyArea)	
	op <- operator
	name2 <- (emptyArea *> guardParser <* emptyArea)					
	return $ k op name1 name2
	where 	k op name1 name2 = (lookup op l) name1 name2
		l = [("&&", \x y -> And x y );
		("||", \x y -> Or x y );
		("+", \x y -> Plus x y );
		("-", \x y -> Minus x y )]

unaryParser :: Parser Expression   
unaryParser =
	choice [ k "_if_" $ do{first <- emptyArea *> guardParser
				; second <- emptyArea *> guardParser
				; third <- emptyArea *> guardParser
				; emptyArea
				; return $ Mux first second third }
              , k "extract" $ undefined  
              , k "!" $ undefined ]
  where
    k x p = (emptyArea >* string x) *> p


--
-- Parsers for rules 
-- Typical format :
-- rule RL_start "start":
--  when proc_RDY_hostToCpu_AND_NOT_state___d4
--   ==> { proc.hostToCpu 32'h1000; state.write 1'd1; }

ruleParser :: Parser Rule 
ruleParser = do
	string "rule"
	processedName <- wSpace *> identifier <* wSpace  
	realName <- char '"' *> identifier  <* char '"' <* char ":" 			
	guard <- emptyArea *> string "when" *> guardParser <* emptyArea 
	string "==>"
	wSpace
 	listExpr <- braces $ (many $ (try ifMethodCallParser) <|> methodCallParser) 	 		
	return $ Rule{ruleName = processedName 
			; ruleGuard = guard
			; ruleBody = toMExpr listExpr}
	where toMExpr = map (\(t,x,y,z) -> MExpression{cond = x; moduleName = t; calledMethod = y; argsM = z})	


--
-- Parser of arguments / guards and whatever 
-- 

guardParser = emptyArea *> (many $ noneOf ['\n';' ';'\t'])    
		
-- Parser for bodies of methods/rules

ifMethodCallParser =do
	emptyArea *> string "if" <* emptyArea 
	nameCond  <- guardParser 
	emptyArea *> string "then"
	(cond,moduleName,methodName,args) <- methodCallParser
	return $ (Just nameCond, moduleName, methodName, args)    	

methodCallParser = 
	moduleName <- emptyArea *> identifier <* char '.'	
	methodName <- identifier <* emptyArea 
        args <- many $ guardParser <* emptyArea 
	char ';'
	emptyArea
	return $ (Nothing, moduleName, methodName, args)



--
-- Parsers for methods
--

methodParser :: Parser Method
methodParser = do
	listArgs <- many $  (try resultParser) <|> argsMethodParser  	
	method <- brackets $ methodBodyParser 
	return method{methodArgs = process1 lArgs; methodType = process2 lArgs lResult}
	  where (lResult, lArgs) = partition (\(x,y,z) -> x == Result) listArgs --Check the order of partition
		process1 = map (\(x,y,z) ->(y,z)) 
		process2 args res = case res of
			[] -> Action  
			[(_,b)] -> case args of
				[] -> Value0 b 
				_  -> Value b
			_ -> assert False --Correct?	  


--
--TODO Need clean up
--

data ResultOrArg = Result | Arg

argMethodParser :: Parser (ResultOrArg,String,Integer)
argMethodParser = do
	name <- identifier 
	wSpace
	string ":: Bit "
	size <- many digit 		
	wSpace
	char ';'
	emptyArea
	return (Arg, name, numberValue 10 size)
		
resultParser :: Parser (ResultOrArg,String,Integer)
resultParser = do wSpace
	--We parse the first line
	name <- identifier 
	wSpace
	string ":: Bit "
	size <- many digit 		
	wSpace
	char ';'
	emptyArea
--We parse the second line with the same name
	string name
	string " ="
	expression <- expressionParser	
	return $ (Result, name, numberValue 10 size)
		

--TODO factorize : we can use ruleBodyParser here.
methodBodyParser :: Parser Method 
methodBodyParser = do
	string "rule"
	processedName <- wSpace *> identifier <* wSpace  
	realName <- char '"' *> identifier  <* char '"' <* char ":" 			
	notImportant <- emptyArea *> string "when" *> guardParser <* emptyArea 
	string "==>"
	wSpace
 	listExpr <- braces $ (many $ (try ifMethodCallParser) <|> methodCallParser) 	 		
	return $ Method{methodName = processedName 
			; methodGuard = "RDY_" ++ processedName  --TODO check if we need bindings
			; methodType = undefined
			; methodArgs = undefined
			; methodBody = toMExpr listExpr}
	where toMExpr = map (\(t,x,y,z) -> MExpression{cond = x; moduleName = t; calledMethod = y; argsM = z})	





--
-- Parser for conflicts
-- TODO


--	
-- Parsers for types of methods  in instances with formal parameters
-- SOME TODO

bodyInstanceParser :: Parser [([Maybe Integer], Maybe Integer, Maybe Integer)]
bodyInstanceParser = do
	-- Eat until my position is good	
	string "meth types="
	typesMethods <- brackets $ parseTripletTypes `sepBy` comma 	 
	emptyArea	
	return $ typesMethods

parseTripletTypes :: Parser ([Maybe Integer], Maybe Integer, Maybe Integer)
parseTripletTypes = do
	first <- brackets $ maybeParser `sepBy` comma 
	comma 
	second <- maybeParser
	comma
	third <- maybeParser	
	return (first, second, third)


maybeParser :: Parser (Maybe Integer)
maybeParser = (try justP)<|>nothingP 

justP :: Parser (Maybe Integer)
justP = do
	wSpace
	string "Just "
	listOfChar <- (many $ digit ) . string "Bit " $ paren
	return $ Just (numberValue 10 listOfChar) -- Decimal notation



nothingP :: Parser (Maybe Integer)
nothingP :: Parser (Maybe Integer)
	wSpace *> string "Nothing" <* wSpace --TODO : check
	return Nothing

--
-- Formal parameters method
-- TODO



--
-- Formal parameters of instances, using doc pragmas.
--

apInstanceDocParser :: Parser [(String,[String])]
apInstanceDocParser = lookAhead $
	 do{many (try $ do{anyChar;
			; notFollowedBy (string "-- AP instance comments\n")
			})
	; string "-- AP instance comments\n"  
	; formalParametersParser}  


formalParametersParser :: Parser [(String,[String])]
formalParametersParser = many $ formalParameterParser

formalParameterParser :: Parser (String,[String])
formalParameterParser = do
	name <- identifier
	string ":\n"
	parameters <- many $ identifier <* wSpace 
	emptyArea
	return $ (name, parameters)

 
