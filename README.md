simple-log
=======

Fast start
--------

Create log config
<pre>
myCfg = logCfg [("", Info), ("app", Trace), ("app.sub", Debug)]
</pre>

Create log and run log monad
<pre>
run ∷ IO ()
run = runLog myCfg [handler text (file "out.log")] $ yourFunction
</pre>

Function with log monad:
<pre>
yourFunction ∷ MonadLog m ⇒ m ()
yourFunction = component "app" $ scope "your" $ do
  sendLog Trace "Hello from your function"
</pre>

Each component can have different level in config, subcomponents are specified with '.'
Components have independent scopes
Scopes can be nested and separated with '/':
<pre>
function2 ∷ MonadLog m ⇒ m ()
function2 = component "app.sub" $ scope "foo" $ do
 scope "bar/baz" $ do
     sendLog Info "Component app.sub and scope foo/bar/baz"
     sendLog Trace "Invisible: app.sub configured with debug level"
 sendLog Info "Same component and scope foo"
 component "module" $ sendLog Info "Component module and root scope"
</pre>

You can update config with `updateLogConfig` function
And change handlers with `updateLogHandlers`

There're also global logger `globalLog`, that can be used with `runGlobalLog`
<pre>
test ∷ IO ()
test = do
 updateLogHandlers globalLog ([handler text (file "test.log")]:)
 runGlobalLog $ sendLog Info "This will go to test.log too"
</pre>
