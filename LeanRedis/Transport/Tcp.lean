import Std.Internal.Async
import LeanRedis.Error
import LeanRedis.Transport.Types


namespace LeanRedis.Transport

abbrev TCP := Std.Internal.IO.Async.TCP.Socket.Client

namespace TCP

open LeanRedis.Transport
open Std.Internal.IO.Async
open Std.Net


private def resolveEndpoint (endpoint : Endpoint) : Async SocketAddress := do
  let addresses <- DNS.getAddrInfo endpoint.host (toString endpoint.port)
  let some addr := addresses[0]? | Error.raise <| .transport s!"failed to resolve {endpoint.host}:{endpoint.port}"
  pure <|
    match addr with
    | .v4 ip => SocketAddress.v4 { addr := ip, port := endpoint.port }
    | .v6 ip => SocketAddress.v6 { addr := ip, port := endpoint.port }

instance instTransportTCP : Transport TCP where
  connect endpoint := do
    let socket <- TCP.Socket.Client.mk
    let address <- resolveEndpoint endpoint
    try
      do
        TCP.Socket.Client.connect socket address
        socket.noDelay
        pure socket
    catch err =>
      Error.raise <| .transport s!"tcp connect failed for {endpoint.host}:{endpoint.port}: {err}"

  recv socket size := do
    try
      match ← socket.recv? size with
      | some bytes => pure { bytes }
      | none => pure { bytes := ByteArray.empty, disconnect? := some .closedByPeer }
    catch err =>
      Error.raise <| .transport s!"tcp read failed: {err}"

  send socket bytes := do
    try
      socket.send bytes
    catch err =>
      Error.raise <| .transport s!"tcp write failed: {err}"

  close socket := do
    try
      socket.shutdown
    catch err =>
      Error.raise <| .transport s!"tcp close failed: {err}"

def connect (endpoint : Endpoint) : Async TCP :=
  Transport.connect endpoint

end LeanRedis.Transport.TCP
