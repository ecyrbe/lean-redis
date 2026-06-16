import LeanRedis.Command.Base
import LeanRedis.Tools.ExpectResult

namespace LeanRedis

/--
PING [message]
-/
abbrev CommandRequest.ping (message? : Option String := none) : CommandRequest :=
  {
    name := "PING"
    args := match message? with
      | some message => #[message.toUTF8]
      | none => #[]
  }

abbrev Command.ping (message?: Option String := none): Command (Option String) := ⟨ CommandRequest.ping message?, expectPong ⟩

/--
AUTH [username] password
-/
abbrev CommandRequest.auth (auth : AuthConfig) : CommandRequest :=
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

abbrev Command.auth (auth : AuthConfig) : Command Unit := ⟨ CommandRequest.auth auth, expectOk ⟩

/--
SELECT index
-/
abbrev CommandRequest.select (database : UInt32) : CommandRequest :=
  {
    name := "SELECT"
    args := #[(toString database).toUTF8]
  }

abbrev Command.select (database : UInt32) : Command Unit := ⟨ CommandRequest.select database, expectOk ⟩

def CommandRequest.selectedDb? (request : CommandRequest) : Option UInt32 := do
  guard (request.name == "SELECT")
  let bytes ← request.args[0]?
  let text ← String.fromUTF8? bytes
  let value ← text.toNat?
  return value.toUInt32

end LeanRedis
