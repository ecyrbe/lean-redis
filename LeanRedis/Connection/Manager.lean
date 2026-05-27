import LeanRedis.Config
import LeanRedis.Engine.Session
import LeanRedis.Protocol.Hello
import LeanRedis.Transport.Types
import LeanRedis.Transport.Tcp

namespace LeanRedis.Connection

open LeanRedis
open LeanRedis.Engine
open LeanRedis.Transport
open Std.Internal.IO.Async


structure Manager (τ : Type) where
  config : Config
  transport? : Option τ := none
  session : Session := {}

def Manager.new (config : Config) : Manager τ :=
  {
    config
    transport? := none
    session := {}
  }

def Manager.isConnected (manager : Manager τ) : Bool :=
  manager.transport?.isSome && manager.session.isReady

def Manager.connect [Transport τ] (manager : Manager τ) : Async (Manager τ) := do
  let transport <- Transport.connect manager.config.endpoint
  let session := manager.session.beginBootstrap
  pure { manager with transport? := some transport, session }

def Manager.disconnect [Transport τ] (manager : Manager τ) : Async (Manager τ) := do
  match manager.transport? with
  | some transport =>
      Transport.close transport
      pure { manager with transport? := none, session := manager.session.markDisconnected }
  | none =>
      pure { manager with session := manager.session.markDisconnected }

end LeanRedis.Connection
