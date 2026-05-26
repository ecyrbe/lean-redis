import LeanRedis.Transport.Types

namespace LeanRedis.Transport.Tcp

open LeanRedis.Transport

def connect (endpoint : Endpoint) : IO Transport :=
  throw <| IO.userError s!"TCP transport not implemented yet for {endpoint.host}:{endpoint.port}"

def factory : Factory := connect

end LeanRedis.Transport.Tcp
