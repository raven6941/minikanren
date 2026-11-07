# Package

version       = "0.1.0"
author        = "raven6941"
description   = "miniKanren for Nim: relational programming over first-order terms"
license       = "MIT"
srcDir        = "src"

# Dependencies

requires "nim >= 2.0.0"

# Tasks

task test, "Run the tests (no external dependencies)":
  exec "nim c -r --hints:off --path:src tests/test_minikanren.nim"
  exec "nim c -r --hints:off --path:src tests/test_examples.nim"

task pbt, "Run the property suite (requires falsify installed)":
  exec "nim c -r --hints:off --path:src tests/pbt_minikanren.nim"
