
data NestedIdentifier a = Node [NestedIdentifier a]
	| Lead a
	deriving(Show,Eq)

nestedIdentifiers :: Parser a -> Parser (NestedIdentifier a)
nestedIdentifiers parserOfIdentifier = do
	nextNesting <- paren . many $ try (nestedIdentifiers parserOfIdentifier) <|> do{id <- parserOfIdentifier;
											return $ Leaf id}
	return $ Node nextNesting	 
