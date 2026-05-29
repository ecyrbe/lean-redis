import LeanRedis.Client

structure Cache (τ : Type) where
  redis: LeanRedis.Client τ


namespace Cache
  open LeanRedis
  open Std.Internal.IO.Async

  @[inline, specialize]
  private def background [Monad m] [MonadAsync t m] (action : m α) (prio := Task.Priority.default) : m Unit :=
    discard (async (t := t) (prio := prio) action)

  @[inline, specialize]
  private def cacheCallback [Transport.Transport τ]
      (cache : Cache τ)
      (key : String)
      (cb : Unit → Async String)
      (options: SetOptions := {})
      : Async String := do
    let value ←  cb ()
    background (cache.redis.set key value options)
    return value

  def new [Transport.Transport τ] (config: Config) : Async (Cache τ) := do
    let client: Client τ <- Client.new config
    client.connect
    return { redis := client }

  def newDefault (config: Config) : Async (Cache Transport.TCP) := new config

  @[inline, specialize]
  def get [Transport.Transport τ] (cache : Cache τ) (key : String) (cb : Unit → (Async String)) (options: SetOptions := {}) : Async String := do
    try
      let value <- cache.redis.get key
      match value with
      | some v => return v
      | none => cache.cacheCallback key cb options
    catch err =>
      IO.println s!"Error fetching key {key} from Redis: {err}"
      cache.cacheCallback key cb options
