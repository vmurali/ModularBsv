data NestedIdentifier a = Node [NestedIdentifier a]
	| Leaf a
	deriving(Show,Eq)


ignoreNestedBrackets :: Parser ()     --THIS FUNCTION IS (B) FUNCTION
ignoreNestedBrackets =  do
	nestedIdentifiers $ noneOf "[]"
	return ()

concatParser :: Parser [String]          --THIS FUNCTION IS (A) FUNCTION
concatParser = do
	treeOfIdentifiers <- concatParserParametrized identifierInsideConcat
	return $ process treeOfIdentifiers
	where process (Leaf a) = [a]
	      process (Node l) =  foldl (\acc x -> acc ++ process x )
					[]
					l  


nestedIdentifiers :: Parser a -> Parser (NestedIdentifier a)
nestedIdentifiers parserOfIdentifier = do
	nextNesting <- brackets . many $ try (nestedIdentifiers parserOfIdentifier) <|> fmap Leaf parserOfIdentifier
	return $ Node nextNesting	

identifierInsideConcat :: Parser String
identifierInsideConcat = (try . parens $ identifier <* symbol "::" <* symbol "Bit" <* integer) <|> identifier  	

concatParserParametrized :: (Parser a) -> Parser (NestedIdentifier a)
concatParserParametrized parserOfIdentifier = do
	(try $ concatParserParametrizedMain  parserOfIdentifier ) <|> fmap Node (sepBy (try (concatParserParametrizedMain parserOfIdentifier) <|> fmap Leaf parserOfIdentifier)
	           						           	$ symbol "++" ) 	  

concatParserParametrizedMain :: Parser a -> Parser (NestedIdentifier a)
concatParserParametrizedMain parserOfIdentifier = do
	nextNesting <- parens . sepBy (try (concatParserParametrizedMain parserOfIdentifier) <|> fmap Leaf parserOfIdentifier)
				      $ symbol "++" 
	return $ Node nextNesting	


