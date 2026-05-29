namespace LeanRedis.Connection

structure ReconnectExponentialBackoff where
  baseDelayMs : UInt32 := 100
  maxDelayMs : UInt32 := 30_000
  jitter : Bool := true
  deriving BEq, Inhabited, Repr

inductive ReconnectStrategy where
  | disabled
  | fixedInterval (delayMs : UInt32) (maxAttempts? : Option Nat := none)
  | exponentialBackoff (config : ReconnectExponentialBackoff := {}) (maxAttempts? : Option Nat := none)
  deriving BEq, Inhabited, Repr

def ReconnectStrategy.shouldAttempt (strategy : ReconnectStrategy) (attempt : Nat) : Bool :=
  match strategy with
  | .disabled => false
  | .fixedInterval _ none => true
  | .fixedInterval _ (some maxAttempts) => attempt < maxAttempts
  | .exponentialBackoff _ none => true
  | .exponentialBackoff _ (some maxAttempts) => attempt < maxAttempts

private def pow2Nat (n : Nat) : Nat :=
  Nat.shiftLeft 1 n

private def clampNatToUInt32 (value : Nat) : UInt32 :=
  UInt32.ofNat value

private def randomBelow (limit : UInt32) : IO UInt32 := do
  if limit == 0 then
    pure 0
  else
    pure <| UInt32.ofNat <| (← IO.rand 0 (limit.toNat - 1))

def ReconnectStrategy.delayMs (strategy : ReconnectStrategy) (attempt : Nat) : IO (Option UInt32) := do
  if !strategy.shouldAttempt attempt then
    pure none
  else
    match strategy with
    | .disabled => pure none
    | .fixedInterval delayMs _ => pure <| some delayMs
    | .exponentialBackoff config _ =>
        let factor := pow2Nat attempt
        let raw := clampNatToUInt32 (config.baseDelayMs.toNat * factor)
        let capped := if raw > config.maxDelayMs then config.maxDelayMs else raw
        if config.jitter then
          return some (← randomBelow (capped + 1))
        else
          pure <| some capped

end LeanRedis.Connection
