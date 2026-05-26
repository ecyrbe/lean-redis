import LeanRedis.Config
import LeanRedis.Command
import LeanRedis.Protocol.Version
import LeanRedis.Protocol.Resp.Encode
import LeanRedis.Protocol.Resp.Value

namespace LeanRedis.Protocol

open LeanRedis

inductive HelloOutcome where
  | negotiated (version : Version)
  | fallbackToResp2
  deriving BEq, Inhabited, Repr

def preferredVersion (preference : ProtocolPreference) : Version :=
  match preference with
  | .resp2 => .resp2
  | .resp3 => .resp3
  | .auto => .resp3

def helloCommand : CommandRequest :=
  {
    name := "HELLO"
    args := #["3".toUTF8]
    allowRetry := true
  }

def authCommand (auth : AuthConfig) : CommandRequest :=
  match auth.username? with
  | some username =>
      {
        name := "AUTH"
        args := #[username.toUTF8, auth.password.toUTF8]
        allowRetry := true
      }
  | none =>
      {
        name := "AUTH"
        args := #[auth.password.toUTF8]
        allowRetry := true
      }

def selectCommand (database : UInt32) : CommandRequest :=
  {
    name := "SELECT"
    args := #[toString database |>.toUTF8]
    allowRetry := true
  }

def bootstrapRequests (config : Config) : Array CommandRequest :=
  let withAuth := match config.auth? with
    | some auth => #[authCommand auth]
    | none => #[]
  let withHello := withAuth.push helloCommand
  match config.database? with
  | some database => withHello.push (selectCommand database)
  | none => withHello

def decideHelloOutcome (reply : Resp.Value) : Option HelloOutcome :=
  match reply with
  | .map entries =>
      if entries.any fun (key, value) => key == .simpleString "proto" && value == .number 3 then
        some (.negotiated .resp3)
      else
        some (.negotiated .resp2)
  | .simpleError _ => some .fallbackToResp2
  | .blobString bytes =>
      match String.fromUTF8? bytes with
      | some "OK" => some (.negotiated .resp2)
      | _ => none
  | .simpleString "OK" => some (.negotiated .resp2)
  | _ => none

def encodeBootstrap (config : Config) : Array ByteArray :=
  bootstrapRequests config |>.map Resp.Encode.encodeCommand

end LeanRedis.Protocol
