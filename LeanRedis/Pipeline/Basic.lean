import LeanRedis.Command
import LeanRedis.Protocol.Resp.Value
import LeanRedis.Error
import LeanRedis.Tools.ExpectResult
import LeanRedis.Data.HList

namespace LeanRedis

open LeanRedis
open Protocol.Resp

structure Pipeline (τs : List Type) where
  requests: Array CommandRequest
  decode: Nat → Array Value → Except Error (HList τs)

namespace Pipeline

def length : {τs: List Type} → Pipeline τs → Nat
 | l, _ => l.length

def empty : Pipeline [] :=
  { requests := #[]
    decode := fun _ _ => .ok []ₕ
  }

instance : Inhabited (Pipeline []) where
  default := empty

def fromCommand (cmd: Command α) : Pipeline [α] :=
  { requests:= #[cmd.request]
    decode:= fun idx rs => do
      match rs[idx]? with
      | some v => return [←cmd.decode v]ₕ
      | none => throw <| Error.protocol s!"Missing Pipeline response: {idx}"
  }

def hAppend (p: Pipeline α) (q: Pipeline β) : Pipeline (α ++ β) :=  {
  requests:= p.requests ++ q.requests,
  decode:= λ idx rs => do
    let a ← p.decode idx rs
    let b ← q.decode (idx + p.requests.size) rs
    return a ++ b
}

instance : HAppend (Pipeline αs) (Pipeline βs) (Pipeline (αs ++ βs)) where
  hAppend := hAppend

def exec (pipeline: Pipeline α) (values: Array Value) := pipeline.decode 0 values

end Pipeline

end LeanRedis
