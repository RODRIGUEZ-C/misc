-- SExp

module SExp (
	SExp(..),
	car,
	cdr,
	list
) where

data SExp =
	  IntVal Integer
	| Symbol String
	| Cons SExp SExp
	| Nil
	| StrVal String
	deriving (Eq)

instance Show SExp where
	show (IntVal n) = show n
	show (Symbol s) = s
	show (Cons a d) = showCons a d
	show Nil        = "()"
	show (StrVal s) = "\"" ++ escapeString s ++ "\""

showCons a d
	| a == Symbol "quote"            && single d    = "'" ++ show (car d)
	| a == Symbol "quasiquote"       && single d    = "`" ++ show (car d)
	| a == Symbol "unquote"          && single d    = "," ++ show (car d)
	| a == Symbol "unquote-splicing" && single d    = ",@" ++ show (car d)
	| otherwise	= "(" ++ show a ++ showCdr d ++ ")"
	where
		single (Cons a Nil) = True
		single (Cons _ _)   = False
		single _            = False

		showCdr (Cons a d)  = " " ++ show a ++ showCdr d
		showCdr Nil         = ""
		showCdr x           = " . " ++ show x

escapeString :: String -> String
escapeString = concatMap f
	where
		f '"'  = "\\\""
		f '\\' = "\\\\"
		f c    = [c]

car :: SExp -> SExp
car (Cons a _) = a
car _          = error "illegal car"

cdr :: SExp -> SExp
cdr (Cons _ d) = d
cdr _          = error "illegal cdr"

list :: [SExp] -> SExp
list = foldr Cons Nil
