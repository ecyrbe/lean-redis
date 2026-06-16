import LeanRedis.Config

namespace LeanRedis

private def pow2Nat (n : Nat) : Nat :=
  Nat.shiftLeft 1 n

private def clampNatToUInt32 (value : Nat) : UInt32 :=
  UInt32.ofNat value

private def randomBelow (limit : UInt32) : IO UInt32 := do
  if limit == 0 then
    return 0
  else
    return UInt32.ofNat <| (← IO.rand 0 (limit.toNat - 1))

def ReconnectStrategy.shouldAttempt (strategy : ReconnectStrategy) (attempt : Nat) : Bool :=
  match strategy with
  | .disabled => false
  | .fixedInterval _ none => true
  | .fixedInterval _ (some maxAttempts) => attempt < maxAttempts
  | .exponentialBackoff _ none => true
  | .exponentialBackoff _ (some maxAttempts) => attempt < maxAttempts

def ReconnectStrategy.delayMs (strategy : ReconnectStrategy) (attempt : Nat) : IO (Option UInt32) := do
  if !strategy.shouldAttempt attempt then
    return none
  else
    match strategy with
    | .disabled => return none
    | .fixedInterval delayMs _ => return some delayMs
    | .exponentialBackoff config _ =>
        let factor := pow2Nat attempt
        let raw := clampNatToUInt32 (config.baseDelayMs.toNat * factor)
        let capped := if raw > config.maxDelayMs then config.maxDelayMs else raw
        if config.jitter then
          return some (← randomBelow (capped + 1))
        else
          return some capped

end LeanRedis
