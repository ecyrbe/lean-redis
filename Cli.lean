import LeanRedis
import Std.Time.Format

open Std.Internal.IO.Async

namespace LeanRedis.CLI

  -- ── event helpers ────────────────────────────────────────

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

  -- ── runner utilities ─────────────────────────────────────

  def execAsync (action : Async α) (print : α → IO Unit) : IO Unit := do
    try
      let v ← action.block
      print v
    catch
      | .interrupted .. => return ()
      | err => IO.println s!"error: {err}"

  def runUnit (action : Async Unit) : IO Unit :=
    execAsync action fun _ => IO.println "OK"

  def runBool (action : Async Bool) : IO Unit :=
    execAsync action fun v => IO.println (if v then "1" else "0")

  def runInt (action : Async Int) : IO Unit :=
    execAsync action fun v => IO.println (toString v)

  def runString (action : Async String) : IO Unit :=
    execAsync action IO.println

  def runOptString (action : Async (Option String)) : IO Unit :=
    execAsync action fun
      | some s => IO.println s
      | none => IO.println "(nil)"

  def runStringArray (action : Async (Array String)) : IO Unit :=
    execAsync action fun items => items.forM IO.println

  def runOptStringArray (action : Async (Array (Option String))) : IO Unit :=
    execAsync action fun items =>
      items.forM fun
        | some s => IO.println s
        | none => IO.println "(nil)"

  -- ── command dispatch ─────────────────────────────────────

  structure CmdDesc where
    name : String
    minArgs : Nat
    maxArgs : Nat
    help : String
    run : Client Transport.TCP → Array String → IO Unit

  def cmd (name : String) (minArgs maxArgs : Nat) (help : String)
      (run : Client Transport.TCP → Array String → IO Unit) : CmdDesc :=
    { name, minArgs, maxArgs, help, run }

  def pairs (args : Array String) : Array (String × String) :=
    let rec go (i : Nat) (acc : Array (String × String)) :=
      if i + 1 < args.size then
        go (i + 2) (acc.push (args[i]!, args[i+1]!))
      else
        acc
    go 0 #[]

  -- ── connection commands ──────────────────────────────────

  def connectionCommands : List CmdDesc :=
    [
      cmd "ping"   0 1 "[<message>] — Ping the server"          fun client args =>
        runOptString (client.ping (args[0]?)),
      cmd "select" 1 1 "<db> — Select database"                  fun client args =>
        runUnit (client.select (args[0]!.toNat? |>.map (·.toUInt32) |>.getD 0)),
      cmd "auth"   1 2 "[<username>] <password> — Authenticate"  fun client args =>
        if args.size = 1 then
          runUnit (client.auth { password := args[0]!, username? := none })
        else
          runUnit (client.auth { password := args[1]!, username? := some args[0]! })
    ]

  -- ── string commands ──────────────────────────────────────

  def stringCommands : List CmdDesc :=
    [
      cmd "get"       1 1 "<key> — Get a string value"               fun client args => runOptString (client.get args[0]!),
      cmd "set"       2 2 "<key> <value> — Set a string value"       fun client args => runBool (client.set args[0]! args[1]!),
      cmd "getdel"    1 1 "<key> — Get and delete"                   fun client args => runOptString (client.getDel args[0]!),
      cmd "getset"    2 2 "<key> <value> — Get and set"              fun client args => runOptString (client.getSet args[0]! args[1]!),
      cmd "strlen"    1 1 "<key> — String length"                    fun client args => runInt (client.strLen args[0]!),
      cmd "append"    2 2 "<key> <value> — Append to string"         fun client args => runInt (client.append args[0]! args[1]!),
      cmd "incr"      1 1 "<key> — Increment by 1"                   fun client args => runInt (client.incr args[0]!),
      cmd "incrby"    2 2 "<key> <amount> — Increment by int"        fun client args =>
        runInt (client.incrBy args[0]! (args[1]!.toInt? |>.getD 0)),
      cmd "decr"      1 1 "<key> — Decrement by 1"                   fun client args => runInt (client.decr args[0]!),
      cmd "decrby"    2 2 "<key> <amount> — Decrement by int"        fun client args =>
        runInt (client.decrBy args[0]! (args[1]!.toInt? |>.getD 0)),
      cmd "setnx"     2 2 "<key> <value> — Set if not exists"        fun client args => runBool (client.setNx args[0]! args[1]!),
      cmd "setex"     3 3 "<key> <seconds> <value> — Set with TTL"   fun client args =>
        runUnit (client.setEx args[0]! (args[1]!.toNat? |>.map (·.toUInt64) |>.getD 0) args[2]!),
      cmd "psetex"    3 3 "<key> <ms> <value> — Set with TTL ms"     fun client args =>
        runUnit (client.pSetEx args[0]! (args[1]!.toNat? |>.map (·.toUInt64) |>.getD 0) args[2]!),
      cmd "getrange"  3 3 "<key> <start> <end> — Get substring"      fun client args =>
        runString (client.getRange args[0]! (args[1]!.toInt? |>.getD 0) (args[2]!.toInt? |>.getD 0)),
      cmd "setrange"  3 3 "<key> <offset> <value> — Overwrite part"  fun client args =>
        runInt (client.setRange args[0]! (args[1]!.toNat? |>.map (·.toUInt64) |>.getD 0) args[2]!),
      cmd "mget"      1 999 "<key>... — Get multiple keys"           fun client args => runOptStringArray (client.mGet args),
      cmd "mset"      2 998 "<key> <value>... — Set multiple"        fun client args => runUnit (client.mSet (pairs args)),
    ]

  -- ── generic commands ─────────────────────────────────────

  def genericCommands : List CmdDesc :=
    [
      cmd "del"       1 999 "<key>... — Delete keys"                 fun client args => runInt (client.del args),
      cmd "exists"    1 999 "<key>... — Check existence"             fun client args => runInt (client.exists args),
      cmd "expire"    2 2 "<key> <seconds> — Set TTL"                fun client args =>
        runBool (client.expire args[0]! (args[1]!.toNat? |>.map (·.toUInt64) |>.getD 0)),
      cmd "ttl"       1 1 "<key> — Get TTL (seconds)"                fun client args => runInt (client.ttl args[0]!),
      cmd "pttl"      1 1 "<key> — Get TTL (ms)"                     fun client args => runInt (client.pttl args[0]!),
      cmd "pexpire"   2 2 "<key> <ms> — Set TTL in ms"               fun client args =>
        runBool (client.pexpire args[0]! (args[1]!.toNat? |>.map (·.toUInt64) |>.getD 0)),
      cmd "persist"   1 1 "<key> — Remove expiration"                fun client args => runBool (client.persist args[0]!),
      cmd "keys"      1 1 "<pattern> — Find keys matching pattern"   fun client args => runStringArray (client.keys args[0]!),
      cmd "type"      1 1 "<key> — Get key type"                     fun client args => runString (client.type args[0]!),
      cmd "rename"    2 2 "<key> <newkey> — Rename key"               fun client args => runUnit (client.rename args[0]! args[1]!),
      cmd "renamenx"  2 2 "<key> <newkey> — Rename if not exists"    fun client args => runBool (client.renameNx args[0]! args[1]!),
      cmd "unlink"    1 999 "<key>... — Unlink keys"                 fun client args => runInt (client.unlink args),
      cmd "touch"     1 999 "<key>... — Touch keys"                  fun client args => runInt (client.touch args),
      cmd "move"      2 2 "<key> <db> — Move key to DB"              fun client args =>
        runBool (client.move args[0]! (args[1]!.toNat? |>.map (·.toUInt32) |>.getD 0)),
      cmd "randomkey" 0 0 " — Get a random key"                      fun client _ => runOptString (client.randomKey),
    ]

  -- ── all commands ─────────────────────────────────────────

  def allCommands : List CmdDesc :=
    connectionCommands ++ stringCommands ++ genericCommands

  def findCommand (name : String) : Option CmdDesc :=
    allCommands.find? (·.name == name)

  -- ── /raw: send arbitrary command ─────────────────────────

  private partial def printReply (v : Protocol.Resp.Value) : IO Unit := do
    match v with
    | .simpleString s => IO.println s
    | .simpleError e => IO.println s!"(error) {e}"
    | .blobString b =>
      match String.fromUTF8? b with
      | some s => IO.println s!"\"{s}\""
      | none => IO.println s!"(bytes) {repr b.toList}"
    | .number n => IO.println (toString n)
    | .null => IO.println "(nil)"
    | .array items => items.forM printReply
    | .map entries => entries.forM fun (k, v) => do printReply k; IO.print " -> "; printReply v
    | .set items => items.forM printReply
    | .bool b => IO.println (if b then "true" else "false")
    | .double d => IO.println d
    | .bigNumber n => IO.println n
    | .verbatimString _ s => IO.println s
    | .push items => items.forM printReply

  private def handleRaw (client : Client Transport.TCP) (args : Array String) : IO Unit := do
    if args.isEmpty then
      IO.println "Usage: /raw <command> [<arg>...]"
      return
    let cmdName := args[0]!
    let cmdArgs := if args.size > 1 then args.extract 1 args.size else #[]
    let request : CommandRequest := { name := cmdName, args := CommandRequest.utf8Args cmdArgs }
    execAsync (Client.execute client request) printReply

  -- ── /help ────────────────────────────────────────────────

  private def printHelp : IO Unit := do
    IO.println "Available commands:"
    IO.println ""
    IO.println "-- Connection --"
    for cmd in connectionCommands do
      IO.println s!"  {cmd.name} {cmd.help}"
    IO.println ""
    IO.println "-- Strings --"
    for cmd in stringCommands do
      IO.println s!"  {cmd.name} {cmd.help}"
    IO.println ""
    IO.println "-- Generic --"
    for cmd in genericCommands do
      IO.println s!"  {cmd.name} {cmd.help}"
    IO.println ""
    IO.println "Slash commands:"
    IO.println "  /exit — Exit the REPL"
    IO.println "  /help — Show this help"
    IO.println "  /raw <command> [<arg>...] — Send arbitrary Redis command"

  -- ── repl ─────────────────────────────────────────────────

  partial def repl (client : Client Transport.TCP) : IO Unit := do
    while !(← IO.checkCanceled) do
      IO.print "> "
      let stdin ← IO.getStdin
      if (← IO.checkCanceled) then
        IO.println "Interrupted..."
        return
      let line ← stdin.getLine
      let parts := line.split Char.isWhitespace |>.toList |>.filter (·.isEmpty |> not) |>.map toString
      match parts with
      | ["/exit"] => return
      | ["/help"] => printHelp
      | "/raw" :: rawArgs => handleRaw client (rawArgs.toArray)
      | cmdName :: cmdArgs =>
        try
          match findCommand cmdName with
          | some cmd =>
            if cmdArgs.length < cmd.minArgs || cmdArgs.length > cmd.maxArgs then
              IO.println s!"Wrong arguments for '{cmdName}': expected {cmd.minArgs}-{cmd.maxArgs} args"
            else
              cmd.run client (cmdArgs.toArray)
          | none =>
            IO.println s!"Unknown command '{cmdName}'. Type /help for available commands."
        catch
          | .interrupted .. => break
          | err => IO.println s!"error: {err}"
      | [] => pure ()
    IO.println "Interrupted..."

end LeanRedis.CLI

open LeanRedis in
def main : IO Unit := do
  let config : Config := {
    endpoint := { host := "127.0.0.1", port := 6379 }
    protocolPreference := .resp3
    reconnectStrategy := .exponentialBackoff ({ jitter:=false}) (some 10)
  }
  let client ← Client.newDefault config
  let subId ← client.onEvent CLI.eventHandler
  try
    client.connect.wait
  catch err =>
    client.offEvent subId
    IO.println s!"connect failed: {err}"
    return

  IO.println "LeanRedis CLI — /help for available commands. Ctrl+C or /exit to exit."

  let waiter ← Signal.Waiter.mk Signal.sigint true
  let worker ← IO.asTask (CLI.repl client)

  -- On SIGINT, cancel the REPL task
  discard <| IO.asTask do
    let signalWaiter ← waiter.wait
    discard <| IO.wait signalWaiter
    IO.cancel worker

  -- Wait for REPL to complete (via /exit or cancellation)
  try
    discard <| IO.wait worker
  catch _ => pure ()

  IO.println "Exiting..."
  waiter.stop
  try client.offEvent subId catch _ => pure ()
  try client.disconnect |>.block catch _ => pure ()
