namespace LeanRedis.Protocol.Resp

inductive Value where
  | simpleString (value : String)
  | blobString (value : ByteArray)
  | simpleError (message : String)
  | number (value : Int)
  | null
  | array (items : Array Value)
  | map (entries : Array (Value × Value))
  | set (items : Array Value)
  | bool (value : Bool)
  | double (value : String)
  | bigNumber (value : String)
  | verbatimString (format : String) (value : String)
  | push (items : Array Value)
  deriving BEq, Inhabited

private partial def render : Value -> String
  | .simpleString value => s!"simpleString {repr value}"
  | .blobString value => s!"blobString {repr value.toList}"
  | .simpleError message => s!"simpleError {repr message}"
  | .number value => s!"number {repr value}"
  | .null => "null"
  | .array items => s!"array {repr (items.toList.map render)}"
  | .map entries =>
      let rendered := entries.toList.map fun (key, value) => (render key, render value)
      s!"map {repr rendered}"
  | .set items => s!"set {repr (items.toList.map render)}"
  | .bool value => s!"bool {repr value}"
  | .double value => s!"double {repr value}"
  | .bigNumber value => s!"bigNumber {repr value}"
  | .verbatimString format value =>
      s!"verbatimString {repr format} {repr value}"
  | .push items => s!"push {repr (items.toList.map render)}"

instance : Repr Value where
  reprPrec value _ := Std.Format.text (render value)

end LeanRedis.Protocol.Resp
