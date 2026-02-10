#!/usr/bin/env ruby
# frozen_string_literal: true

require_relative "../scripts/brivlo_emit"

RSpec.describe BrivloEmit do
  describe ".map_event" do
    it "maps SessionStart to session.start" do
      event, tool, summary, meta = described_class.map_event("hook_event_name" => "SessionStart")
      expect(event).to eq("session.start")
      expect(tool).to be_nil
    end

    it "maps SessionEnd to session.end" do
      event, tool, summary, meta = described_class.map_event("hook_event_name" => "SessionEnd")
      expect(event).to eq("session.end")
      expect(tool).to be_nil
    end

    it "maps PermissionRequest to wait.permission with tool info" do
      input = {
        "hook_event_name" => "PermissionRequest",
        "tool_name" => "Bash",
        "tool_input" => { "command" => "git push origin main" }
      }
      event, tool, summary, meta = described_class.map_event(input)
      expect(event).to eq("wait.permission")
      expect(tool).to eq("Bash")
      expect(summary).to eq("git push origin main")
    end

    context "when hook is Notification" do
      it "maps permission_prompt to wait.permission" do
        input = {
          "hook_event_name" => "Notification",
          "notification_type" => "permission_prompt",
          "message" => "Approve?"
        }
        event, tool, summary, meta = described_class.map_event(input)
        expect(event).to eq("wait.permission")
        expect(tool).to be_nil
      end

      it "maps idle_prompt to wait.idle" do
        input = {
          "hook_event_name" => "Notification",
          "notification_type" => "idle_prompt"
        }
        event, tool, summary, meta = described_class.map_event(input)
        expect(event).to eq("wait.idle")
        expect(tool).to be_nil
      end

      it "returns nil event for unknown notification types" do
        input = {
          "hook_event_name" => "Notification",
          "notification_type" => "something_unknown"
        }
        event, tool, summary, meta = described_class.map_event(input)
        expect(event).to be_nil
      end
    end

    it "maps PreToolUse to tool.invoke" do
      input = {
        "hook_event_name" => "PreToolUse",
        "tool_name" => "Bash",
        "tool_input" => { "command" => "npm test" }
      }
      event, tool, summary, meta = described_class.map_event(input)
      expect(event).to eq("tool.invoke")
      expect(tool).to eq("Bash")
    end

    it "maps PostToolUseFailure to tool.error" do
      input = {
        "hook_event_name" => "PostToolUseFailure",
        "tool_name" => "Bash",
        "tool_input" => { "command" => "failing cmd" }
      }
      event, tool, summary, meta = described_class.map_event(input)
      expect(event).to eq("tool.error")
      expect(tool).to eq("Bash")
    end

    it "maps SubagentStart to phase.start" do
      input = {
        "hook_event_name" => "SubagentStart",
        "agent_type" => "Explore"
      }
      event, tool, summary, meta = described_class.map_event(input)
      expect(event).to eq("phase.start")
      expect(summary).to eq("subagent: Explore")
      expect(meta).to eq("type=Explore")
    end

    it "maps SubagentStop to phase.end" do
      input = {
        "hook_event_name" => "SubagentStop",
        "agent_type" => "Explore"
      }
      event, tool, summary, meta = described_class.map_event(input)
      expect(event).to eq("phase.end")
      expect(summary).to eq("subagent: Explore")
      expect(meta).to eq("type=Explore")
    end

    it "returns nil event for unknown hook events" do
      event, tool, summary, meta = described_class.map_event("hook_event_name" => "SomethingElse")
      expect(event).to be_nil
    end
  end

  describe ".sanitize_summary" do
    it "summarizes Bash commands with first line truncated to 80 chars" do
      result = described_class.sanitize_summary("Bash", { "command" => "npm test" })
      expect(result).to eq("npm test")
    end

    it "summarizes Edit/Write/Read with file_path" do
      result = described_class.sanitize_summary("Edit", { "file_path" => "/foo/bar.rb" })
      expect(result).to eq("/foo/bar.rb")
    end

    it "summarizes WebFetch with domain" do
      result = described_class.sanitize_summary("WebFetch", { "url" => "https://example.com/page" })
      expect(result).to eq("example.com")
    end

    it "summarizes Skill with skill name" do
      result = described_class.sanitize_summary("Skill", { "skill" => "commit" })
      expect(result).to eq("commit")
    end

    it "returns tool_name for unknown tools" do
      result = described_class.sanitize_summary("UnknownTool", { "foo" => "bar" })
      expect(result).to eq("UnknownTool")
    end

    it "returns nil when tool_input is not a Hash" do
      result = described_class.sanitize_summary("Bash", nil)
      expect(result).to be_nil
    end
  end
end
