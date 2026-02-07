#!/usr/bin/env ruby
# frozen_string_literal: true

# Brivlo event emitter — called by Claude Code hooks.
# Always exits 0 (fail-open).

require "json"
require "socket"

module BrivloEmit
  module_function

  def detect_instance
    return ENV["BRIVLO_INSTANCE"] if ENV["BRIVLO_INSTANCE"] && !ENV["BRIVLO_INSTANCE"].empty?

    basename = File.basename(Dir.pwd)
    return basename if basename.match?(/\Awt-/)

    brivlo_json = File.join(Dir.pwd, ".brivlo.json")
    if File.exist?(brivlo_json)
      data = JSON.parse(File.read(brivlo_json))
      return data["instance"] if data["instance"] && !data["instance"].empty?
    end

    "unknown"
  rescue
    "unknown"
  end

  def hostname
    Socket.gethostname
  end

  def timestamp
    Time.now.utc.strftime("%Y-%m-%dT%H:%M:%SZ")
  end
end

exit 0 if __FILE__ == $0
