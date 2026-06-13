import LeanRedis.Pipeline.Basic

namespace LeanRedis.Pipeline

def ping (pipeline: Pipeline α) (message? : Option String := none) :=
  pipeline.hAppend <| fromCommand <| Command.ping message?

def auth (pipeline: Pipeline α) (auth: AuthConfig) :=
  pipeline.hAppend <| fromCommand <| Command.auth auth

def select (pipeline: Pipeline α) (index: UInt32) :=
  pipeline.hAppend <| fromCommand <| Command.select index

end LeanRedis.Pipeline
