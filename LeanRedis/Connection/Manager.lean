import LeanRedis.Config
import LeanRedis.Engine.Session
import LeanRedis.Protocol.Hello
import LeanRedis.Transport.Types
import LeanRedis.Transport.Tcp

namespace LeanRedis.Connection

open LeanRedis
open LeanRedis.Engine
open LeanRedis.Transport

structure Manager where
  config : Config
  transportFactory : Transport.Factory
  transport? : Option Transport.Transport := none
  session : Session := {}

def Manager.new (config : Config) (transportFactory : Transport.Factory := Transport.Tcp.factory) : Manager :=
  {
    config
    transportFactory
    transport? := none
    session := {}
  }

def Manager.isConnected (manager : Manager) : Bool :=
  manager.transport?.isSome && manager.session.isReady

def Manager.connect (manager : Manager) : IO Manager := do
  let transport <- manager.transportFactory manager.config.endpoint
  let session := (manager.session.beginBootstrap).markReady <| Protocol.preferredVersion manager.config.protocolPreference
  pure { manager with transport? := some transport, session }

def Manager.disconnect (manager : Manager) : IO Manager := do
  match manager.transport? with
  | some transport =>
      transport.close
      pure { manager with transport? := none, session := manager.session.markDisconnected }
  | none =>
      pure { manager with session := manager.session.markDisconnected }

end LeanRedis.Connection
