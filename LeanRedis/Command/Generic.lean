import LeanRedis.Command.Base

namespace LeanRedis

/-! Generic commands

This module contains implementations of commands that don't fit into a more specific category. For example, the `PING` command is implemented here since it doesn't belong to a specific data type category like strings or hashes.

- COPY
- DEL
- DUMP
- EXISTS
- EXPIRE
- EXPIREAT
- EXPIRETIME
- KEYS
- MIGRATE
- MOVE
- OBJECT ENCODING
- OBJECT FREQ
- OBJECT IDLETIME
- OBJECT REFCOUNT
- PERSIST
- PEXPIRE
- PEXPIREAT
- PTTL
- RANDOMKEY
- RENAME
- RENAMENX
- RESTORE
- SCAN
- SORT
- SORT_RO
- TOUCH
- TTL
- TYPE
- UNLINK
-/
structure CopyOptions where
  db? : Option UInt32 := none
  replace : Bool := false
  deriving BEq, Inhabited, Repr

/--
COPY source destination [DB db] [REPLACE]
-/
def CommandRequest.copy (source destination : String) (options : CopyOptions := {}) : CommandRequest :=
  {
    name := "COPY"
    args := CommandRequest.utf8Args <| #[source, destination]
      ++ (match options.db? with
        | some db => #["DB", toString db]
        | none => #[])
      ++ (if options.replace then #["REPLACE"] else #[])
  }

/--
DEL key [key ...]
-/
def CommandRequest.del (keys : Array String) : CommandRequest :=
  {
    name := "DEL"
    args := CommandRequest.utf8Args keys
  }

/--
DUMP key
-/
def CommandRequest.dump (key : String) : CommandRequest :=
  {
    name := "DUMP"
    args := CommandRequest.utf8Args #[key]
  }

/--
TTL key
-/
def CommandRequest.ttl (key : String) : CommandRequest :=
  {
    name := "TTL"
    args := CommandRequest.utf8Args #[key]
  }

/--
EXISTS key [key ...]
-/
def CommandRequest.exists (keys : Array String) : CommandRequest :=
  {
    name := "EXISTS"
    args := CommandRequest.utf8Args keys
  }

inductive ExpireOption where
  | NX
  | XX
  | GT
  | LT
  deriving BEq, Inhabited, Repr

instance : ToString ExpireOption where
  toString
    | ExpireOption.NX => "NX"
    | ExpireOption.XX => "XX"
    | ExpireOption.GT => "GT"
    | ExpireOption.LT => "LT"

/--
EXPIRE key seconds [NX | XX | GT | LT]
-/
def CommandRequest.expire (key : String) (seconds : UInt64) (option : Option ExpireOption := none) : CommandRequest :=
  {
    name := "EXPIRE"
    args := CommandRequest.utf8Args <| #[key, toString seconds]
      ++ match option with
         | some opt => #[toString opt]
         | none => #[]
  }

/--
EXPIREAT key unix-time-seconds [NX | XX | GT | LT]
-/
def CommandRequest.expireAt (key : String) (timestamp : Std.Time.Timestamp) (option : Option ExpireOption := none): CommandRequest :=
  {
    name := "EXPIREAT"
    args := CommandRequest.utf8Args <| #[key, toString timestamp]
      ++ match option with
         | some opt => #[toString opt]
         | none => #[]
  }

/--
EXPIRETIME key
-/
def CommandRequest.expireTime (key : String) : CommandRequest :=
  {
    name := "EXPIRETIME"
    args := CommandRequest.utf8Args #[key]
  }

/--
KEYS pattern
-/
def CommandRequest.keys (pattern : String) : CommandRequest :=
  {
    name := "KEYS"
    args := CommandRequest.utf8Args #[pattern]
  }

structure MigrateOptions where
  copy : Bool := false
  replace : Bool := false
  auth: Option AuthConfig := none

/--
MIGRATE host port key|"" destination-db timeout [COPY] [REPLACE] [AUTH password] [AUTH2 username password] [KEYS key [key ...]]
-/
def CommandRequest.migrate (host : String) (port : UInt16) (keys : Array String)
    (destinationDb : UInt32 := 0) (timeout : UInt64 := 5000) (options : MigrateOptions := {}) : CommandRequest :=
  {
    name := "MIGRATE"
    args := CommandRequest.utf8Args <| #[host, toString port]
      ++ (if h: keys.size = 1 then #[keys[0]] else #[""])
      ++ #[toString destinationDb, toString timeout]
      ++ (if options.copy then #["COPY"] else #[])
      ++ (if options.replace then #["REPLACE"] else #[])
      ++ (match options.auth with
        | some { username? := none, password } => #["AUTH", password.value]
        | some { username?:= some username , password } => #["AUTH2", username, password.value]
        | none => #[])
      ++ (if h: keys.size > 1 then #["KEYS"] ++ keys else #[])
  }

/--
MOVE key db
-/
def CommandRequest.move (key : String) (destinationDb : UInt32) : CommandRequest :=
  {
    name := "MOVE"
    args := CommandRequest.utf8Args #[key, toString destinationDb]
  }

/--
OBJECT ENCODING key
-/
def CommandRequest.objectEncoding (key : String) : CommandRequest :=
  {
    name := "OBJECT ENCODING"
    args := CommandRequest.utf8Args #[key]
  }

/--
OBJECT FREQ key
-/
def CommandRequest.objectFreq (key : String) : CommandRequest :=
  {
    name := "OBJECT FREQ"
    args := CommandRequest.utf8Args #[key]
  }

/--
OBJECT IDLETIME key
-/
def CommandRequest.objectIdleTime (key : String) : CommandRequest :=
  {
    name := "OBJECT IDLETIME"
    args := CommandRequest.utf8Args #[key]
  }

/--
OBJECT REFCOUNT key
-/
def CommandRequest.objectRefCount (key : String) : CommandRequest :=
  {
    name := "OBJECT REFCOUNT"
    args := CommandRequest.utf8Args #[key]
  }

/--
PERSIST key
-/
def CommandRequest.persist (key : String) : CommandRequest :=
  {
    name := "PERSIST"
    args := CommandRequest.utf8Args #[key]
  }

/--
PEXPIRE key milliseconds [NX | XX | GT | LT]
-/
def CommandRequest.pexpire (key : String) (milliseconds : UInt64) (option : Option ExpireOption := none) : CommandRequest :=
  {
    name := "PEXPIRE"
    args := CommandRequest.utf8Args <| #[key, toString milliseconds]
      ++ match option with
         | some opt => #[toString opt]
         | none => #[]
  }

/--
PEXPIREAT key unix-time-milliseconds [NX | XX | GT | LT]
-/
def CommandRequest.pexpireAt (key : String) (timestamp : Std.Time.Timestamp) (option : Option ExpireOption := none) : CommandRequest :=
  {
    name := "PEXPIREAT"
    args := CommandRequest.utf8Args <| #[key, toString timestamp]
      ++ match option with
         | some opt => #[toString opt]
         | none => #[]
  }

/--
PTTL key
-/
def CommandRequest.pttl (key : String) : CommandRequest :=
  {
    name := "PTTL"
    args := CommandRequest.utf8Args #[key]
  }

/--
RANDOMKEY
-/
def CommandRequest.randomKey : CommandRequest :=
  {
    name := "RANDOMKEY"
    args := #[]
  }

/--
RENAME key newkey
-/
def CommandRequest.rename (key newKey : String) : CommandRequest :=
  {
    name := "RENAME"
    args := CommandRequest.utf8Args #[key, newKey]
  }

/--
RENAMENX key newkey
-/
def CommandRequest.renameNx (key newKey : String) : CommandRequest :=
  {
    name := "RENAMENX"
    args := CommandRequest.utf8Args #[key, newKey]
  }

structure RestoreOptions where
  replace : Bool := false
  absTTL : Bool := false
  idleTime? : Option UInt64 := none
  frequency? : Option UInt64 := none

/--
RESTORE key ttl serialized-value [REPLACE] [ABSTTL] [IDLETIME time] [FREQ freq]
-/
def CommandRequest.restore (key : String) (ttl : UInt64) (serializedValue : String) (options : RestoreOptions := {}) : CommandRequest :=
  {
    name := "RESTORE"
    args := CommandRequest.utf8Args <| #[key, toString ttl, serializedValue]
      ++ (if options.replace then #["REPLACE"] else #[])
      ++ (if options.absTTL then #["ABSTTL"] else #[])
      ++ (match options.idleTime? with
        | some idleTime => #["IDLETIME", toString idleTime]
        | none => #[])
      ++ (match options.frequency? with
        | some frequency => #["FREQ", toString frequency]
        | none => #[])
  }

structure ScanOptions where
  match? : Option String := none
  count? : Option UInt64 := none
  type? : Option String := none

structure ScanResult where
  cursor : UInt64
  keys : Array String
  deriving BEq, Inhabited, Repr

/--
SCAN cursor [MATCH pattern] [COUNT count] [TYPE type]
-/
def CommandRequest.scan (cursor : UInt64) (options : ScanOptions := {}) : CommandRequest :=
  {
    name := "SCAN"
    args := CommandRequest.utf8Args <| #[toString cursor]
      ++ (match options.match? with
        | some pattern => #["MATCH", pattern]
        | none => #[])
      ++ (match options.count? with
        | some count => #["COUNT", toString count]
        | none => #[])
      ++ (match options.type? with
        | some typeName => #["TYPE", typeName]
        | none => #[])
  }

structure SortOptions where
  «by?» : Option String := none
  limit? : Option (UInt64 × UInt64) := none
  getPatterns : Array String := #[]
  asc? : Option Bool := none
  alpha : Bool := false
  store? : Option String := none

/--
SORT key [BY pattern] [LIMIT offset count] [GET pattern [GET pattern ...]] [ASC | DESC] [ALPHA] [STORE destination]
-/
def CommandRequest.sort (key : String) (options : SortOptions := {}) : CommandRequest :=
  {
    name := "SORT"
    args := CommandRequest.utf8Args <| #[key]
      ++ (match options.«by?» with
        | some pattern => #["BY", pattern]
        | none => #[])
      ++ (match options.limit? with
        | some (offset, count) => #["LIMIT", toString offset, toString count]
        | none => #[])
      ++ options.getPatterns.foldl (fun acc pattern => acc ++ #["GET", pattern]) #[]
      ++ (match options.asc? with
        | some true => #["ASC"]
        | some false => #["DESC"]
        | none => #[])
      ++ (if options.alpha then #["ALPHA"] else #[])
      ++ (match options.store? with
        | some dest => #["STORE", dest]
        | none => #[])
  }

structure SortRoOptions where
  «by?» : Option String := none
  limit? : Option (UInt64 × UInt64) := none
  getPatterns : Array String := #[]
  asc? : Option Bool := none
  alpha : Bool := false

/--
SORT_RO key [BY pattern] [LIMIT offset count] [GET pattern [GET pattern ...]] [ASC | DESC] [ALPHA]
-/
def CommandRequest.sortRo (key : String) (options : SortRoOptions := {}) : CommandRequest :=
  {
    name := "SORT_RO"
    args := CommandRequest.utf8Args <| #[key]
      ++ (match options.«by?» with
        | some pattern => #["BY", pattern]
        | none => #[])
      ++ (match options.limit? with
        | some (offset, count) => #["LIMIT", toString offset, toString count]
        | none => #[])
      ++ options.getPatterns.foldl (fun acc pattern => acc ++ #["GET", pattern]) #[]
      ++ (match options.asc? with
        | some true => #["ASC"]
        | some false => #["DESC"]
        | none => #[])
      ++ (if options.alpha then #["ALPHA"] else #[])
  }

/--
TOUCH key [key ...]
-/
def CommandRequest.touch (keys : Array String) : CommandRequest :=
  {
    name := "TOUCH"
    args := CommandRequest.utf8Args keys
  }

/--
TTL key
-/
def CommandRequest.TTL (key : String) : CommandRequest :=
  {
    name := "TTL"
    args := CommandRequest.utf8Args #[key]
  }

/--
TYPE key
-/
def CommandRequest.type (key : String) : CommandRequest :=
  {
    name := "TYPE"
    args := CommandRequest.utf8Args #[key]
  }

/--
UNLINK key [key ...]
-/
def CommandRequest.unlink (keys : Array String) : CommandRequest :=
  {
    name := "UNLINK"
    args := CommandRequest.utf8Args keys
  }

end LeanRedis
