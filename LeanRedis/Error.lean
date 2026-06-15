namespace LeanRedis

inductive Error where
  | transport (message : String)
  | protocol (message : String)
  | server (message : String)
  | decode (message : String)
  | bootstrap (message : String)
  | unavailable (message : String)
  deriving BEq, Inhabited, Repr

def Error.isTransport : Error → Bool
  | .transport _ => true
  | _ => false

def Error.message : Error -> String
  | .transport message => s!"transport error: {message}"
  | .protocol message => s!"protocol error: {message}"
  | .server message => s!"server error: {message}"
  | .decode message => s!"decode error: {message}"
  | .bootstrap message => s!"bootstrap error: {message}"
  | .unavailable message => s!"unavailable: {message}"

instance : MonadLift (Except Error) IO where
  monadLift x :=
    match x with
    | .ok a => pure a
    | .error e => throw <| IO.userError e.message

def Error.raise {α : Type} (err : Error) : IO α :=
  throw <| IO.userError err.message

def Error.isTransportIOError (err : IO.Error) : Bool :=
  match err with
  | .userError msg => msg.startsWith "transport error:"
  | _ => false

end LeanRedis
