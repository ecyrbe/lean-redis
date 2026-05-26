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
  | .simpleString value => s!"LeanRedis.Protocol.Resp.Value.simpleString {repr value}"
  | .blobString value => s!"LeanRedis.Protocol.Resp.Value.blobString {repr value.toList}"
  | .simpleError message => s!"LeanRedis.Protocol.Resp.Value.simpleError {repr message}"
  | .number value => s!"LeanRedis.Protocol.Resp.Value.number {repr value}"
  | .null => "LeanRedis.Protocol.Resp.Value.null"
  | .array items => s!"LeanRedis.Protocol.Resp.Value.array {repr (items.toList.map render)}"
  | .map entries =>
      let rendered := entries.toList.map fun (key, value) => (render key, render value)
      s!"LeanRedis.Protocol.Resp.Value.map {repr rendered}"
  | .set items => s!"LeanRedis.Protocol.Resp.Value.set {repr (items.toList.map render)}"
  | .bool value => s!"LeanRedis.Protocol.Resp.Value.bool {repr value}"
  | .double value => s!"LeanRedis.Protocol.Resp.Value.double {repr value}"
  | .bigNumber value => s!"LeanRedis.Protocol.Resp.Value.bigNumber {repr value}"
  | .verbatimString format value =>
      s!"LeanRedis.Protocol.Resp.Value.verbatimString {repr format} {repr value}"
  | .push items => s!"LeanRedis.Protocol.Resp.Value.push {repr (items.toList.map render)}"

instance : Repr Value where
  reprPrec value _ := Std.Format.text (render value)

end LeanRedis.Protocol.Resp
