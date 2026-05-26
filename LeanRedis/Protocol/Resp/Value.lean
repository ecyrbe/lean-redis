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

end LeanRedis.Protocol.Resp
