import LeanRedis.Engine.State
import LeanRedis.Protocol.Version

namespace LeanRedis.Engine

structure Session where
  state : State := {}
  deriving BEq, Inhabited

def Session.isReady (session : Session) : Bool :=
  session.state.phase == .ready

def Session.beginBootstrap (session : Session) : Session :=
  { session with state := { session.state with phase := .bootstrapping } }

def Session.markReady (session : Session) (version : Protocol.Version) : Session :=
  {
    session with
    state := {
      session.state with
      phase := .ready
      protocol? := some version
    }
  }

def Session.markDisconnected (session : Session) : Session :=
  { session with state := { session.state with phase := .disconnected } }

end LeanRedis.Engine
