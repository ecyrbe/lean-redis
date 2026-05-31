import LeanRedis.Command.Base

namespace LeanRedis

/--
PING [message]
-/
def CommandRequest.ping (message? : Option String := none) : CommandRequest :=
  {
    name := "PING"
    args := match message? with
      | some message => #[message.toUTF8]
      | none => #[]
  }

/--
AUTH [username] password
-/
def CommandRequest.auth (auth : AuthConfig) : CommandRequest :=
  match auth.username? with
  | some username =>
      {
        name := "AUTH"
        args := #[username.toUTF8, auth.password.value.toUTF8]
      }
  | none =>
      {
        name := "AUTH"
        args := #[auth.password.value.toUTF8]
      }

/--
SELECT index
-/
def CommandRequest.select (database : UInt32) : CommandRequest :=
  {
    name := "SELECT"
    args := #[(toString database).toUTF8]
  }

def CommandRequest.selectedDb? (request : CommandRequest) : Option UInt32 := do
  guard (request.name == "SELECT")
  let bytes <- request.args[0]?
  let text <- String.fromUTF8? bytes
  let value <- text.toNat?
  pure value.toUInt32

end LeanRedis
