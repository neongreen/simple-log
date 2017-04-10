{-# LANGUAGE OverloadedStrings, FlexibleInstances, UndecidableInstances, MultiParamTypeClasses, GeneralizedNewtypeDeriving, ConstraintKinds, FlexibleContexts #-}

module System.Log.Simple.Monad (
	-- | Monad log
	MonadLog, LogT(..),
	noLog, withLog, runLog,

	-- | Getters
	askLog, askComponent, askScope,

	-- | Log functions
	log, sendLog,
	component,
	scope_, scope, scopeM, scoper, scoperM,
	trace,
	) where

import Prelude hiding (log)
import Prelude.Unicode

import Control.Exception (SomeException)
import Control.Monad.IO.Class
import Control.Monad.Reader
import Control.Monad.Except
import Control.Monad.Catch
import Data.String
import Data.Text (Text)
import qualified Data.Text as T
import GHC.Stack
import System.Log.Simple.Base

type MonadLog m = (MonadIO m, MonadMask m, MonadReader Log m)

newtype LogT m a = LogT { runLogT ∷ ReaderT Log m a }
	deriving (Functor, Applicative, Monad, MonadIO, MonadReader Log, MonadThrow, MonadCatch, MonadMask)

instance MonadTrans LogT where
	lift = LogT ∘ lift

-- | Run with no logging
noLog ∷ (MonadIO m, MonadMask m) ⇒ LogT m a → m a
noLog = runLog defCfg []

-- | Run @LogT@ monad with @Log@
withLog ∷ Log → LogT m a → m a
withLog l act = runReaderT (runLogT act) l

-- | Run @LogT@ monad with log config and handlers
runLog ∷ (MonadIO m, MonadMask m) ⇒ LogConfig → [LogHandler] → LogT m a → m a
runLog cfg handlers = bracket (liftIO $ newLog cfg handlers) (liftIO ∘ stopLog) ∘ flip withLog

-- | Ask log
askLog ∷ MonadLog m ⇒ m Log
askLog = ask

-- | Ask current component
askComponent ∷ MonadLog m ⇒ m Component
askComponent = asks logComponent

-- | Ask current scope
askScope ∷ MonadLog m ⇒ m Scope
askScope = asks logScope

-- | Log message
log ∷ MonadLog m ⇒ Level → Text → m ()
log lev msg = do
	l ← ask
	writeLog l lev msg

-- | Log message, same as @log@
sendLog ∷ MonadLog m ⇒ Level → Text → m ()
sendLog = log

-- | Log component, also sets root scope
component ∷ MonadLog m ⇒ Text → m a → m a
component c = local (getLog (read ∘ T.unpack $ c) mempty)

-- | Create local scope
scope_ ∷ MonadLog m ⇒ Text → m a → m a
scope_ s = local (subLog mempty (read ∘ T.unpack $ s))

-- | Scope with log all exceptions
scope ∷ MonadLog m ⇒ Text → m a → m a
scope s act = scope_ s $ catch act onError where
	onError ∷ (MonadLog m, HasCallStack) ⇒ SomeException → m a
	onError e = do
		log Error $ T.unlines [
			T.concat ["Scope leaves with exception: ", fromString ∘ show $ e],
			fromString $ prettyCallStack callStack]
		throwM e

-- | Scope with log exception from @MonadError@
scopeM ∷ (MonadLog m, MonadError e m, Show e) ⇒ Text → m a → m a
scopeM s act = scope_ s $ catchError act onError where
	onError ∷ (MonadLog m, MonadError e m, Show e, HasCallStack) ⇒ e → m a
	onError e = do
		log Error $ T.unlines [
			T.concat ["Scope leaves with exception: ", fromString ∘ show $ e],
			fromString $ prettyCallStack callStack]
		throwError e

-- | Scope with tracing result
scoper ∷ (MonadLog m, Show a) ⇒ Text → m a → m a
scoper s act = do
	r ← scope s act
	log Trace $ T.concat ["Scope ", s, " leaves with result: ", fromString . show $ r]
	return r

scoperM ∷ (MonadLog m, MonadError e m, Show e, Show a) ⇒ Text → m a → m a
scoperM s act = do
	r ← scopeM s act
	log Trace $ T.concat ["Scope", s, " leaves with result: ", fromString . show $ r]
	return r

-- | Trace value
trace ∷ (MonadLog m, Show a) ⇒ Text → m a → m a
trace name act = do
	v ← act
	log Trace $ T.concat [name, " = ", fromString . show $ v]
	return v
