module Core.Parser where

import Common

import Control.Exception.Safe
import Core.Expr
import Core.Type (Type(..))
import qualified Data.Foldable as F
-- import Data.String (unwords)
import SExpr.Internal

expectSym :: MonadThrow m => SExpr -> m String
expectSym (SESym x) = return x
expectSym se = throwString $ "symbol is expected, but not:" ++ show se

parseExpr :: MonadThrow m => SExpr -> m Expr
parseExpr (SESym x) = return $ EVar x
parseExpr (SETag t) = return $ ETag t
parseExpr (SEList content) = case content of
  [SESym "fn", SEBList ses, se] -> do
    e <- parseExpr se
    xs <- mapM expectSym ses
    return $ F.foldr' EAbs e xs
  se : ses -> do
    e <- parseExpr se
    es <- mapM parseExpr ses
    return $ F.foldl' EApp e es
  _ -> throwString "parse failed."
parseExpr se = throwString $ "not implemented. " ++ show se

parseBinds :: MonadThrow m => [SExpr] -> m [(Var, Expr)]
parseBinds = mapM parseBind
  where
    parseBind :: MonadThrow m => SExpr -> m (Var, Expr)
    parseBind (SEList [SESym x, se]) = (x,) <$> parseExpr se
    parseBind _ = throwString "fail parseBind"

parsePat :: MonadThrow m => SExpr -> m Pat
parsePat (SESym "_") = return PWildcard
parsePat _ = throwString "fail parsePat"

parseCase :: MonadThrow m => SExpr -> m (Pat,Expr)
parseCase (SEList [p, e]) = (,) <$> parsePat p <*> parseExpr e
parseCase _ = throwString "fail parseCase"
