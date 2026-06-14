import LeanRedis.Transport.Types

namespace LeanRedis.Transport

open Std.Internal.IO.Async

/-- A `Middleware` wraps each `Transport` operation with pre/post processing.
    Each field receives the operation arguments plus a `next` callback
    that invokes the inner layer. Middlewares compose by calling `next`
    (possibly with modified arguments) and can add pre/post processing. -/
structure Middleware (τ : Type) where
  onConnect : Endpoint → (Endpoint → Async τ) → Async τ
  onRecv : τ → UInt64 → (τ → UInt64 → Async ByteArray) → Async ByteArray
  onSend : τ → ByteArray → (τ → ByteArray → Async Unit) → Async Unit
  onSendAll : τ → Array ByteArray → (τ → Array ByteArray → Async Unit) → Async Unit
  onClose : τ → (τ → Async Unit) → Async Unit

namespace Middleware

/-- A middleware that passes all operations through unchanged. -/
def identity (τ : Type) : Middleware τ := {
  onConnect := λ ep next => next ep
  onRecv := λ t size next => next t size
  onSend := λ t bytes next => next t bytes
  onSendAll := λ t arr next => next t arr
  onClose := λ t next => next t
}

end Middleware

/-- A `MiddlewareTransport` wraps a transport handle `τ` with a chain
    of `Middleware τ` hooks, implementing `Transport` by composing them.
    Middlewares are applied outermost-first (index 0 → n-1). -/
structure MiddlewareTransport (τ : Type) where
  inner : τ
  middlewares : Array (Middleware τ)

namespace MiddlewareTransport

/-- Wrap an already-connected transport handle with a middleware chain. -/
def wrap [Transport τ] (inner : τ) (middlewares : Array (Middleware τ)) : MiddlewareTransport τ :=
  { inner, middlewares }

/-- Connect to an endpoint through a middleware chain.
    Each middleware's `onConnect` wraps `Transport.connect` from outermost to innermost. -/
def connect [Transport τ] (endpoint : Endpoint) (middlewares : Array (Middleware τ)) : Async (MiddlewareTransport τ) := do
  let chain := middlewares.foldr
    (fun mw next => λ ep => mw.onConnect ep next)
    Transport.connect
  let inner ← chain endpoint
  pure { inner, middlewares }

instance [Transport τ] : Transport (MiddlewareTransport τ) where
  connect endpoint := do
    let inner ← Transport.connect endpoint
    pure { inner, middlewares := #[] }

  recv mw size := do
    let chain := mw.middlewares.foldr
      (fun mw next => λ t s => mw.onRecv t s next)
      Transport.recv
    chain mw.inner size

  send mw bytes := do
    let chain := mw.middlewares.foldr
      (fun mw next => λ t b => mw.onSend t b next)
      Transport.send
    chain mw.inner bytes

  sendAll mw arr := do
    let chain := mw.middlewares.foldr
      (fun mw next => λ t a => mw.onSendAll t a next)
      Transport.sendAll
    chain mw.inner arr

  close mw := do
    let chain := mw.middlewares.foldr
      (fun mw next => λ t => mw.onClose t next)
      Transport.close
    chain mw.inner

end MiddlewareTransport
end LeanRedis.Transport
