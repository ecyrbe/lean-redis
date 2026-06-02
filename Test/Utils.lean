import LeanRedis

namespace LeanRedisTest.Utils

initialize reconnectAttemptsRef : IO.Ref Nat ← IO.mkRef 0

def escapeText (text : String) : String :=
  text.toList.foldl (fun acc ch =>
    acc ++
      match ch with
      | '\r' => "\\r"
      | '\n' => "\\n"
      | '\\' => "\\\\"
      | '"' => "\\\""
      | other => String.singleton other) ""

def renderBytes (bytes : ByteArray) : String :=
  match String.fromUTF8? bytes with
  | some text => "\"" ++ escapeText text ++ "\""
  | none => s!"<bytes:{bytes.size}>"

def concatBytes (chunks : Array ByteArray) : ByteArray :=
  chunks.foldl (fun acc chunk => acc.append chunk) ByteArray.empty

def renderChunks (chunks : Array ByteArray) : String :=
  renderBytes (concatBytes chunks)

instance : Repr ByteArray where
  reprPrec value _ := Std.Format.text (renderBytes value)

instance {α : Type} [Repr α] : Repr (Except String α) where
  reprPrec value _ :=
    match value with
    | .ok result => Std.Format.text s!"Except.ok {repr result}"
    | .error message => Std.Format.text s!"Except.error {repr message}"

end LeanRedisTest.Utils
