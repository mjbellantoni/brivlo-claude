#!/usr/bin/env ruby
# frozen_string_literal: true

require_relative "../scripts/brivlo_emit"

RSpec.describe BrivloEmit do
  describe ".detect_instance" do
    it "returns BRIVLO_INSTANCE env var when set" do
      ENV["BRIVLO_INSTANCE"] = "env-instance"
      expect(described_class.detect_instance).to eq("env-instance")
    ensure
      ENV.delete("BRIVLO_INSTANCE")
    end

    it "falls back to unknown when nothing matches" do
      ENV.delete("BRIVLO_INSTANCE")
      Dir.chdir("/tmp") do
        expect(described_class.detect_instance).to eq("unknown")
      end
    end
  end
end
