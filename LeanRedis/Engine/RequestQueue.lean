import LeanRedis.Engine.State

namespace LeanRedis.Engine

abbrev RequestQueue := Array CommandRequest

def RequestQueue.empty : RequestQueue := #[]

def RequestQueue.enqueue (queue : RequestQueue) (request : CommandRequest) : RequestQueue :=
  queue.push request

def RequestQueue.pop? (queue : RequestQueue) : Option (CommandRequest × RequestQueue) :=
  match queue.toList with
  | [] => none
  | request :: rest => some (request, rest.toArray)

end LeanRedis.Engine
