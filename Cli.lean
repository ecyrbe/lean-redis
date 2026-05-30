import LeanRedis
import Std.Time.Format

open Std.Internal.IO.Async

namespace LeanRedis.CLI

  def formatMetadata (m : Client.EventMetadata) : String :=
    let ts := s!"[{m.timestamp}]"
    let err := match m.error? with | some e => s!" [error: {e.message}]" | none => ""
    let attempt := match m.attempt? with | some n => s!" [attempt: {n}]" | none => ""
    ts ++ err ++ attempt

  def eventHandler (event : Client.Event) : Async Unit := do
    match event with
    | .initialConnectFailed m =>
      IO.println s!"[event]{formatMetadata m} initial connect failed"
    | .remoteDisconnected reason m =>
      IO.println s!"[event]{formatMetadata m} remote disconnected: {repr reason}"
    | .reconnectAttemptStarted m =>
      IO.println s!"[event]{formatMetadata m} reconnect attempt started"
    | .reconnectAttemptFailed m =>
      IO.println s!"[event]{formatMetadata m} reconnect attempt failed"
    | .reconnectScheduled delayMs m =>
      IO.println s!"[event]{formatMetadata m} reconnect scheduled in {delayMs}ms"
    | .reconnected m =>
      IO.println s!"[event]{formatMetadata m} reconnected"
    | .reconnectStopped m =>
      IO.println s!"[event]{formatMetadata m} reconnect stopped"
    | .explicitlyDisconnected m =>
      IO.println s!"[event]{formatMetadata m} explicitly disconnected"

  def handleGet (client : Client Transport.TCP) (key : String) : IO Unit := do
    try
      let value ← client.get key |>.block
      match value with
      | some v => IO.println v
      | none => IO.println "(nil)"
    catch err =>
      IO.println s!"error: {err}"

  def handleSet (client : Client Transport.TCP) (key value : String) : IO Unit := do
    try
      let ok ← client.set key value |>.block
      IO.println (if ok then "OK" else "(not stored)")
    catch err =>
      IO.println s!"error: {err}"

  partial def repl (client : Client Transport.TCP) : IO Unit := do
    IO.print "> "
    let line ← (← IO.getStdin).getLine
    let parts := line.split Char.isWhitespace |>.toList |>.filter (·.isEmpty |> not) |>.map toString
    match parts with
      | ["get", key] =>
        handleGet client key
        repl client
      | ["set", key, value] =>
        handleSet client key value
        repl client
      | _ =>
        IO.println "Unknown command. Usage: get <key> | set <key> <value>"
        repl client

end LeanRedis.CLI

def main : IO Unit := do
  let config : LeanRedis.Config := {
    endpoint := { host := "127.0.0.1", port := 6379 }
    reconnectStrategy := .exponentialBackoff ({}) (some 10)
  }
  let client : LeanRedis.Client LeanRedis.Transport.TCP ← LeanRedis.Client.newDefault config
  _ ← client.onEvent LeanRedis.CLI.eventHandler
  try
    client.connect |>.block
  catch err =>
    IO.println s!"connect failed: {err}"
    return
  IO.println "LeanRedis CLI — type get <key> or set <key> <value>. Ctrl+C to exit."
  LeanRedis.CLI.repl client
