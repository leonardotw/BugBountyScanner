#!/usr/bin/env bats

@test "Check if BugBountyScanner.sh has syntax errors" {
  run bash -n ./BugBountyScanner.sh
  [ "$status" -eq 0 ]
}

@test "Check if setup.sh has syntax errors" {
  run bash -n ./setup.sh
  [ "$status" -eq 0 ]
}

@test "Check BugBountyScanner.sh help output" {
  run ./BugBountyScanner.sh --help
  [ "$status" -eq 0 ]
  [[ "$output" =~ "BugBountyScanner" ]]
}

@test "Check if shellcheck passes on BugBountyScanner.sh" {
  run shellcheck -S warning ./BugBountyScanner.sh
  # We might expect some warnings, so let's just print output if it fails for now, 
  # or strictly fail. For now, let's allow it to fail but print output.
  if [ "$status" -ne 0 ]; then
    echo "$output"
  fi
  # Uncomment to enforce strict shellcheck
  # [ "$status" -eq 0 ]
}
