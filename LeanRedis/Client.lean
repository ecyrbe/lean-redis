import LeanRedis.Connection.Manager
import LeanRedis.Error

namespace LeanRedis

structure Client where
  managerRef : IO.Ref Connection.Manager

def Client.connect (config : Config) : IO Client := do
  let managerRef <- IO.mkRef <| Connection.Manager.new config
  pure { managerRef }

def Client.connectNow (config : Config) : IO Client := do
  let manager <- (Connection.Manager.new config).connect
  let managerRef <- IO.mkRef manager
  pure { managerRef }

def Client.disconnect (client : Client) : IO Unit := do
  let manager <- client.managerRef.get
  let manager <- manager.disconnect
  client.managerRef.set manager

def Client.isConnected (client : Client) : IO Bool := do
  return (← client.managerRef.get).isConnected

def Client.requireConnected (client : Client) : IO Unit := do
  unless (← client.isConnected) do
    Error.raise <| .unavailable "client is not connected"

end LeanRedis
