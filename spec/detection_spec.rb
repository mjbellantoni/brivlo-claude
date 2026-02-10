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

    it "falls back to basename of pwd when env var is unset" do
      ENV.delete("BRIVLO_INSTANCE")
      Dir.chdir("/tmp") do
        expect(described_class.detect_instance).to eq("tmp")
      end
    end
  end

  describe ".detect_host" do
    it "returns BRIVLO_HOST env var when set" do
      ENV["BRIVLO_HOST"] = "my-host"
      expect(described_class.detect_host).to eq("my-host")
    ensure
      ENV.delete("BRIVLO_HOST")
    end

    it "falls back to Socket.gethostname when env var is unset" do
      ENV.delete("BRIVLO_HOST")
      allow(Socket).to receive(:gethostname).and_return("workstation")
      expect(described_class.detect_host).to eq("workstation")
    end
  end

  describe ".default_hostname" do
    it "strips .local suffix to just 'local'" do
      allow(Socket).to receive(:gethostname).and_return("Michaels-MacBook.local")
      expect(described_class.default_hostname).to eq("local")
    end

    it "passes through non-.local hostnames unchanged" do
      allow(Socket).to receive(:gethostname).and_return("prod-server-01")
      expect(described_class.default_hostname).to eq("prod-server-01")
    end
  end
end
