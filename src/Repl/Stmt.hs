{-# LANGUAGE GeneralisedNewtypeDeriving #-}
module Repl.Stmt where

import Common
import Control.Lens
import Core.Calc.Eval
import Core.Calc.Val
import Core.Env
import Core.Expr
import Core.Parser
import Core.Type
import Core.Typing.Infer
import qualified Data.Set as S
import Control.Exception.Safe (MonadThrow, throwString)
import Repl.State

data Stmt =
    StExprDef Var Expr
  | StExpr Expr
  | StTyDef Tag (Set Uniq) [(Tag, [Type])]
  deriving Show

newtype Exec m a = Exec (StateT ReplState m a)
  deriving
    ( Functor
    , Applicative
    , Monad
    , MonadThrow
    , MonadCatch
    , MonadMask
    , MonadIO
    , MonadState ReplState)

evalStmt :: (MonadIO m, MonadCatch m) => Stmt -> Exec m ()
evalStmt (StTyDef t us secs) = mapM_ (evalConDef t us) secs
evalStmt (StExprDef x e) = do
  (vEnv,tEnv,cEnv) <- getEnvs
  sc <- runInfer e tEnv cEnv [x]
  let vEnv' = insertValEnv x (VClo x e vEnv') vEnv
      tEnv' = insertTyEnv x sc tEnv
  setEnvs vEnv' tEnv' cEnv
evalStmt (StExpr e) = do
  vEnv <- getValEnv
  v <- runEval e vEnv
  print v

evalConDef :: Monad m => Tag -> Set Uniq -> (Tag, [Type]) -> Exec m ()
evalConDef name us (t, tys) = do
  let ty = TyCon name [TyVar u | u <- S.toList us]
      sc = Forall us (foldr tyFunc ty tys)
  consEnv %= insertCEnv t sc name

runExec :: MonadIO m => Exec m a -> m a
runExec (Exec m) = evalStateT m initialState