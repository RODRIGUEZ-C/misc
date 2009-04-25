-- SExp parser

module SExpParser where

import SExp
import Text.ParserCombinators.Parsec

run :: (Show a) => Parser a -> String -> IO ()
run p input =
	case (parse p "" input) of
		Left err -> do
			putStr "parse error at "
			print err
		Right x -> print x

sexp :: Parser SExp
sexp = intval <|> symbol <|> listParser <|> strval
	<|> quoted <|> quasiquoted <|> unquoted

intval :: Parser SExp
intval = do
	s <- many1 digit
	return $ IntVal $ read s

symbol :: Parser SExp
symbol = do
	s <- many1 symbol_char
	return $ Symbol s

symbol_char :: Parser Char
symbol_char = alphaNum <|> oneOf "!$%&=+-*/<>|@."

listParser :: Parser SExp
listParser = do
	char '('
	many separator
	ls <- sepWith sexp (many1 separator)
	d <- last
	return $ foldr Cons d ls
	where
		last = do
				char ')'
				return Nil
			<|> do
				many separator
				char '.'
				many1 separator
				d <- sexp
				char ')'
				return $ d

strval :: Parser SExp
strval = do
	char '"'
	s <- many strchar
	char '"'
	return $ StrVal s
	where
		strchar = noneOf "\""

quoted :: Parser SExp
quoted = do
	char '\''
	s <- sexp
	return $ Cons (Symbol "quote") $ Cons s Nil

quasiquoted :: Parser SExp
quasiquoted = do
	char '`'
	s <- sexp
	return $ Cons (Symbol "quasiquote") $ Cons s Nil

unquoted :: Parser SExp
unquoted = do
	char ','
	try (do
		char '@'
		s <- sexp
		return $ Cons (Symbol "unquote-splicing") $ Cons s Nil
	 ) <|> do
		s <- sexp
		return $ Cons (Symbol "unquote") $ Cons s Nil

sepWith :: Parser a -> Parser b -> Parser [a]
sepWith content separator = do
		e <- content
		try (do
			s <- separator
			rest <- sepWith content separator
			return $ e : rest
		 ) <|> do
			return $ e : []
	<|>
		return []

separator :: Parser ()
separator = oneOf " \t\n" >> return ()
