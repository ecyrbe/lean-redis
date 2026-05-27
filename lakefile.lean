import Lake
open Lake DSL

package "lean-redis" where
  version := v!"0.1.0"

lean_lib LeanRedis

lean_lib LeanRedisTest where
  globs := #[.submodules `Test]

@[default_target]
lean_exe "lean-redis" where
  root := `Main
