import LeanRedis.Connection.Manager
import LeanRedis.Connection.Runtime
import LeanRedis.Pipeline.Basic
import LeanRedis.Pipeline.Runtime

namespace LeanRedis.Pipeline

open LeanRedis
open LeanRedis.Connection
open LeanRedis.Transport
open Std.Internal.IO.Async

/--
Execute a pipeline on the Manager's runtime, returning the raw `ExecuteError`
so callers (e.g. Client) can distinguish remote disconnect from command errors.
-/
def Manager.tryRun
    [Transport τ]
    (pipeline : Pipeline α)
    (manager : Connection.Manager τ)
    : Async (Except ExecuteError (Connection.Manager τ × HList α)) := do
  let some runtime := manager.runtime?
    | return (.error <| .commandError (.unavailable "manager is not connected"))
  let (result, runtime) ← (Runtime.tryExecuteBatch pipeline.requests).run runtime
  match result with
  | .error err => return (.error err)
  | .ok values =>
      match pipeline.exec values with
      | .ok decoded =>
          let lastReply := if h: values.size > 0 then some values[values.size - 1] else none
          let manager := {
            manager with
            runtime? := some runtime
            session := { manager.session with state := { manager.session.state with lastReply? := lastReply } }
          }
          return (.ok (manager, decoded))
      | .error err => return (.error <| .commandError err)

/--
Execute a pipeline on the Manager's runtime, raising on any error.
-/
def Manager.run
    [Transport τ]
    (pipeline : Pipeline α)
    (manager : Connection.Manager τ)
    : Async (Connection.Manager τ × HList α) := do
  match ← Manager.tryRun pipeline manager with
  | .ok result => pure result
  | .error (.commandError err) => Error.raise err
  | .error (.remoteDisconnect _ err) => Error.raise err

end LeanRedis.Pipeline
