import LeanRedis.Connection.Manager
import LeanRedis.Error
import LeanRedis.Transport.Tcp

namespace LeanRedis

open Std.Internal.IO.Async

private def blockAsync {α : Type} (task : Async α) : IO α :=
  Std.Internal.IO.Async.Async.block task

structure Client (τ : Type) where
  managerRef : IO.Ref (Connection.Manager τ)

def Client.connectWith [Transport.Transport τ] (config : Config) : IO (Client τ) := do
  let managerRef <- IO.mkRef <| (Connection.Manager.new config : Connection.Manager τ)
  pure { managerRef }

def Client.connect (config : Config) : IO (Client Transport.TCP) :=
  Client.connectWith config

def Client.connectNowWith [Transport.Transport τ] (config : Config) : IO (Client τ) := do
  let manager <- blockAsync <| Connection.Manager.connect (Connection.Manager.new config : Connection.Manager τ)
  let managerRef <- IO.mkRef manager
  pure { managerRef }

def Client.connectNow (config : Config) : IO (Client Transport.TCP) := do
  Client.connectNowWith config

def Client.disconnect [Transport.Transport τ] (client : Client τ) : IO Unit := do
  let manager <- client.managerRef.get
  let manager <- blockAsync <| Connection.Manager.disconnect manager
  client.managerRef.set manager

def Client.isConnected (client : Client τ) : IO Bool := do
  return Connection.Manager.isConnected (← client.managerRef.get)

def Client.requireConnected [Transport.Transport τ] (client : Client τ) : IO Unit := do
  unless (← Client.isConnected client) do
    Error.raise <| .unavailable "client is not connected"

end LeanRedis
