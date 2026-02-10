#!/usr/bin/env ruby
# frozen_string_literal: true

require_relative "../scripts/brivlo_emit"

RSpec.describe BrivloEmit do
  describe ".load_config" do
    let(:config_path) { File.join(Dir.pwd, ".brivlo.yml") }

    after do
      ENV.delete("BRIVLO_ENDPOINT")
      ENV.delete("BRIVLO_TOKEN")
      File.delete(config_path) if File.exist?(config_path)
    end

    it "loads .brivlo.yml values into ENV" do
      File.write(config_path, YAML.dump(
        "BRIVLO_ENDPOINT" => "http://localhost:3000",
        "BRIVLO_TOKEN"    => "cfg-token"
      ))

      described_class.load_config

      expect(ENV["BRIVLO_ENDPOINT"]).to eq("http://localhost:3000")
      expect(ENV["BRIVLO_TOKEN"]).to eq("cfg-token")
    end

    it "does not overwrite existing ENV values" do
      ENV["BRIVLO_ENDPOINT"] = "existing-value"

      File.write(config_path, YAML.dump(
        "BRIVLO_ENDPOINT" => "http://localhost:3000"
      ))

      described_class.load_config

      expect(ENV["BRIVLO_ENDPOINT"]).to eq("existing-value")
    end

    it "no-ops when no config file exists" do
      expect { described_class.load_config }.not_to raise_error
    end
  end
end
