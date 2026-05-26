import LeanRedis.Engine.State

namespace LeanRedis.Engine

abbrev RequestQueue := Array PendingRequest

def RequestQueue.empty : RequestQueue := #[]

def RequestQueue.enqueue (queue : RequestQueue) (request : PendingRequest) : RequestQueue :=
  queue.push request

def RequestQueue.pop? (queue : RequestQueue) : Option (PendingRequest × RequestQueue) :=
  match queue.toList with
  | [] => none
  | request :: rest => some (request, rest.toArray)

end LeanRedis.Engine
