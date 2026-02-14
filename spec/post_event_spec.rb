#!/usr/bin/env ruby
# frozen_string_literal: true

require_relative "../scripts/brivlo_emit"
require "webmock/rspec"

RSpec.describe BrivloEmit do
  describe ".post_event" do
    let(:endpoint) { "http://127.0.0.1:9292" }

    before do
      ENV["BRIVLO_ENDPOINT"] = endpoint
      ENV["BRIVLO_TOKEN"]    = "test-token"
    end

    after do
      ENV.delete("BRIVLO_ENDPOINT")
      ENV.delete("BRIVLO_TOKEN")
    end

    it "builds correct payload with required fields" do
      stub = stub_request(:post, "#{endpoint}/events")
        .to_return(status: 200)

      described_class.post_event("session.start", instance: "myapp", host: "local")

      expect(stub).to have_been_requested
      expect(WebMock).to have_requested(:post, "#{endpoint}/events").with { |req|
        body = JSON.parse(req.body)
        body["event"] == "session.start" &&
          body["instance"] == "myapp" &&
          body["host"] == "local" &&
          body.key?("event_id") &&
          body.key?("ts")
      }
    end

    it "includes optional tool and summary when present" do
      stub = stub_request(:post, "#{endpoint}/events")
        .to_return(status: 200)

      described_class.post_event("tool.invoke",
        instance: "myapp", host: "local",
        tool: "Bash", summary: "npm test")

      expect(WebMock).to have_requested(:post, "#{endpoint}/events").with { |req|
        body = JSON.parse(req.body)
        body["tool"] == "Bash" && body["summary"] == "npm test"
      }
    end

    it "includes optional skill when present" do
      stub = stub_request(:post, "#{endpoint}/events")
        .to_return(status: 200)

      described_class.post_event("tool.invoke",
        instance: "myapp", host: "local",
        tool: "Skill", skill: "superpowers:brainstorming",
        summary: "superpowers:brainstorming")

      expect(WebMock).to have_requested(:post, "#{endpoint}/events").with { |req|
        body = JSON.parse(req.body)
        body["skill"] == "superpowers:brainstorming"
      }
    end

    it "omits skill when nil" do
      stub = stub_request(:post, "#{endpoint}/events")
        .to_return(status: 200)

      described_class.post_event("tool.invoke",
        instance: "myapp", host: "local",
        tool: "Bash", summary: "npm test")

      expect(WebMock).to have_requested(:post, "#{endpoint}/events").with { |req|
        body = JSON.parse(req.body)
        !body.key?("skill")
      }
    end

    it "omits summary when it is empty" do
      stub = stub_request(:post, "#{endpoint}/events")
        .to_return(status: 200)

      described_class.post_event("tool.invoke",
        instance: "myapp", host: "local",
        tool: "Bash", summary: "")

      expect(WebMock).to have_requested(:post, "#{endpoint}/events").with { |req|
        body = JSON.parse(req.body)
        !body.key?("summary")
      }
    end

    it "JSON-encodes meta hash" do
      stub = stub_request(:post, "#{endpoint}/events")
        .to_return(status: 200)

      described_class.post_event("phase.start",
        instance: "myapp", host: "local",
        meta: { "type" => "Explore" })

      expect(WebMock).to have_requested(:post, "#{endpoint}/events").with { |req|
        body = JSON.parse(req.body)
        JSON.parse(body["meta"]) == { "type" => "Explore" }
      }
    end

    it "skips POST when endpoint is missing" do
      ENV.delete("BRIVLO_ENDPOINT")

      expect(Net::HTTP).not_to receive(:new)
      described_class.post_event("session.start", instance: "myapp", host: "local")
    end

    it "skips POST when token is missing" do
      ENV.delete("BRIVLO_TOKEN")

      expect(Net::HTTP).not_to receive(:new)
      described_class.post_event("session.start", instance: "myapp", host: "local")
    end

    it "rescues connection errors silently" do
      stub_request(:post, "#{endpoint}/events")
        .to_raise(Errno::ECONNREFUSED)

      expect {
        described_class.post_event("session.start", instance: "myapp", host: "local")
      }.not_to raise_error
    end
  end
end
