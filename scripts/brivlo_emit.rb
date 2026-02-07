#!/usr/bin/env ruby
# frozen_string_literal: true

# Brivlo event emitter — called by Claude Code hooks.
# Always exits 0 (fail-open).

require "json"
require "socket"
require "uri"

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

  def sanitize_summary(tool_name, tool_input)
    return tool_name unless tool_input.is_a?(Hash)

    case tool_name
    when "Bash"
      cmd = tool_input["command"].to_s.split("\n").first.to_s
      "#{tool_name}: #{cmd[0, 80]}"
    when "Edit", "Write", "Read"
      "#{tool_name}: #{tool_input["file_path"]}"
    when "WebFetch"
      domain = URI.parse(tool_input["url"].to_s).host rescue nil
      "#{tool_name}: #{domain || "unknown"}"
    when "Skill"
      "#{tool_name}: #{tool_input["skill"]}"
    else
      tool_name
    end
  rescue
    tool_name.to_s
  end

  def map_event(input)
    hook = input["hook_event_name"]
    tool_name = input["tool_name"]
    tool_input = input["tool_input"] || {}

    case hook
    when "SessionStart"
      ["session.start", nil, nil, nil]
    when "SessionEnd"
      ["session.end", nil, nil, nil]
    when "PermissionRequest"
      summary = sanitize_summary(tool_name, tool_input)
      ["wait.permission", tool_name, summary, nil]
    when "Notification"
      case input["notification_type"]
      when "permission_prompt"
        msg = input["message"].to_s[0, 80]
        ["wait.permission", nil, msg, nil]
      when "idle_prompt"
        ["wait.idle", nil, nil, nil]
      else
        [nil, nil, nil, nil]
      end
    when "PreToolUse"
      summary = sanitize_summary(tool_name, tool_input)
      ["tool.invoke", tool_name, summary, nil]
    when "PostToolUseFailure"
      summary = sanitize_summary(tool_name, tool_input)
      ["tool.error", tool_name, summary, nil]
    when "SubagentStart"
      agent_type = input["agent_type"] || "unknown"
      ["phase.start", nil, "subagent: #{agent_type}", "type=#{agent_type}"]
    when "SubagentStop"
      agent_type = input["agent_type"] || "unknown"
      ["phase.end", nil, "subagent: #{agent_type}", "type=#{agent_type}"]
    else
      [nil, nil, nil, nil]
    end
  end

  def brivlo_event_available?
    ENV.key?("BRIVLO_ENDPOINT") && ENV.key?("BRIVLO_TOKEN") && system("which brivlo_event > /dev/null 2>&1")
  end

  def run
    unless brivlo_event_available?
      $stderr.puts "brivlo: brivlo_event not available (missing CLI or env vars)" if ENV["BRIVLO_DEBUG"]
      return
    end

    input = JSON.parse($stdin.read)
    event, tool, summary, meta = map_event(input)
    return unless event

    args = [
      "brivlo_event", event,
      "--instance", detect_instance,
      "--host", hostname,
    ]
    args.push("--tool", tool) if tool
    args.push("--summary", summary) if summary && !summary.empty?
    args.push("--meta", meta) if meta

    exec(*args)
  end
end

if __FILE__ == $0
  begin
    BrivloEmit.run
  rescue => e
    $stderr.puts "brivlo: #{e.message}" if ENV["BRIVLO_DEBUG"]
  ensure
    exit 0
  end
end
