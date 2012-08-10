-- | The main ideas of this log library are:
--
--     * we don't want to see all unnecessary trace messages when there are no errors,
--
--     * but we want to have all possible information about error.
-- 
-- This library is based on scopes. Every scope have a name, and logs traces only if there are some errors. Otherwise it logs only message with 'Info' level.
-- 
-- Let's start by simple example:
--
-- @
-- test :: ReaderT Log IO ()
-- test = scope \"test\" $ do
-- log Trace \"Trace message\"
--     log Info \"Starting test\"
--     s \<- liftIO T.getLine
--     when (T.null s) $ log Error \"Oh no!\"
--     log Trace $ T.concat [\"Your input: \", s]
-- @
--
-- When you input some valid string, it will produce output:
--
-- @
-- 08\/10\/12 22:23:34   INFO    test> Starting test
-- abc
-- @
--
-- wihtout any traces
--
-- But if you input empty strings, you'll get:
--
-- @
-- 08\/10\/12 22:24:20   INFO    test> Starting test
-- 08\/10\/12 22:24:20   TRACE   test> Trace message
-- 08\/10\/12 22:24:21   ERROR   test> Oh no!
-- 08\/10\/12 22:24:21   TRACE   test> Your input: 
-- @
--
-- Note, that first 'Trace' is written after 'Info', that's because logger don't know whether 'Trace' message will be written or not, but he must write 'Info' message immediately. But that's not a big problem.
--
-- There are three scope functions: 'scope_', 'scope' and 'scoper'. 'scope_' is basic function. 'scope' catches all exceptions and logs error with it, then rethrows. 'scoper' is like 'scope', but logs (with 'Trace' level) result of do-block.
--
-- Of course, scopes can be nested:
--
-- @
-- test :: ReaderT Log IO ()
-- test = scope \"test\" $ do
--     log Trace \"test trace\"
--     foo
--     log Info \"some info\"
--     bar
-- 
-- foo :: ReaderT Log IO ()
-- foo = scope \"foo\" $ do
--     log Trace \"foo trace\"
-- 
-- bar :: ReaderT Log IO ()
-- bar = scope \"bar\" $ do
--     log Trace \"bar trace\"
--     log Error \"bar error\"
-- @
--
-- Output:
--
-- @
-- 08\/10\/12 22:32:53   INFO    test> some info
-- 08\/10\/12 22:32:53   TRACE   test/bar> bar trace
-- 08\/10\/12 22:32:53   ERROR   test/bar> bar error
-- @
--
-- Note, no messages for "foo" and no trace messages for "test", because error was in "bar", not in "foo".
--
-- Code to run log:
--
-- @
-- rules :: Rules
-- rules = []
-- 
-- run :: IO ()
-- run = do
--     l <- newLog defaultPolitics rules [logger text console]
--     withLog l test
-- @
--
-- Politics sets 'low' and 'high' levels. By default, 'low' and 'high' are both INFO. Levels below 'low' are "traces" ('Trace' and 'Debug' by default). Levels above 'high' are "errors" ('Warn', 'Error' and 'Fatal' by default).
--
-- If you set 'low' to 'Trace', all messages will be written. If you set 'low' to 'Debug' and 'high' to 'Fatal', "traces" (in this case only 'Trace') will be never written.
--
-- Sometimes we need to trace function, but we don't want to write all traces. We can get this by setting rules. Rules changes politics for specified scope-path (scope-path is list of nested scopes, for example ["test"], ["test", "bar"], ["test", "bar", "baz", "quux"] etc.)
--
-- For example, we want to trace function 'foo':
--
-- @
-- rules = [
--     relative [\"foo\"] $ low Trace]
-- @
--
-- From now all scope-paths, that contains "foo" (all scopes with name "foo") will have politics with 'low' set to Trace.
--
-- We may adjust politics for scope 'foo', that is nested directly in scope 'quux':
--
-- @
-- rules = [
--    relative [\"quux\", \"foo\"] $ low Trace]
-- @
--
-- And, of course, we may specify absolute path:
--
-- @
-- rules = [
--     absolute [\"bar\", \"baz\", \"foo\"] $ low Trace]
-- @
-- 
-- Politics will be changed only for scope "foo", which is nested directly in "baz", which is nested in "bar".
module System.Log (
    module System.Log.Base,
    module System.Log.Monad,
    module System.Log.Text,
    module System.Log.HTML,
    module System.Log.Console,
    module System.Log.File
    ) where

import System.Log.Base hiding (entries, flatten, rules, writeLog, scopeLog_, scopeLog, scoperLog)
import System.Log.Monad
import System.Log.Text
import System.Log.HTML
import System.Log.Console
import System.Log.File
