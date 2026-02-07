#!/usr/bin/env ruby
# frozen_string_literal: true

require_relative "../scripts/brivlo_emit"

# Test 1: ENV takes priority
ENV["BRIVLO_INSTANCE"] = "env-instance"
result = BrivloEmit.detect_instance
raise "Expected env-instance, got #{result}" unless result == "env-instance"
puts "PASS: ENV detection"
ENV.delete("BRIVLO_INSTANCE")

# Test 2: Falls back to unknown when nothing matches
Dir.chdir("/tmp") do
  result = BrivloEmit.detect_instance
  raise "Expected unknown, got #{result}" unless result == "unknown"
end
puts "PASS: fallback to unknown"

puts "All instance detection tests passed."
