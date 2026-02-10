#!/usr/bin/env ruby
# frozen_string_literal: true

# Brivlo event emitter — called by Claude Code hooks.
# Always exits 0 (fail-open).

require "json"
require "net/http"
require "securerandom"
require "socket"
require "uri"
require "yaml"

module BrivloEmit
  CONFIG_FILES = [
    File.join(Dir.pwd, ".brivlo.yml"),
    File.join(Dir.home, ".brivlo.yml"),
  ].freeze

  module_function

  def load_config
    path = CONFIG_FILES.find { |p| File.exist?(p) }
    return unless path

    YAML.load_file(path).each do |key, value|
      ENV[key] ||= value.to_s
    end
  rescue
    nil
  end

  def detect_instance
    ENV["BRIVLO_INSTANCE"] || File.basename(Dir.pwd)
  end

  def detect_host
    ENV["BRIVLO_HOST"] || default_hostname
  end

  def default_hostname
    name = Socket.gethostname
    name.end_with?(".local") ? "local" : name
  end

  def sanitize_summary(tool_name, tool_input)
    return nil unless tool_input.is_a?(Hash)

    case tool_name
    when "Bash"
      tool_input["command"].to_s.split("\n").first.to_s[0, 80]
    when "Edit", "Write", "Read"
      tool_input["file_path"]
    when "WebFetch"
      domain = URI.parse(tool_input["url"].to_s).host rescue nil
      domain || "unknown"
    when "Skill"
      tool_input["skill"]
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

  TIMEOUT = 2

  def post_event(event, instance:, host:, tool: nil, summary: nil, meta: nil)
    endpoint = ENV["BRIVLO_ENDPOINT"]
    token    = ENV["BRIVLO_TOKEN"]
    return unless endpoint && token

    payload = {
      event_id: SecureRandom.uuid,
      ts:       Time.now.utc.iso8601,
      event:    event,
      instance: instance,
      host:     host,
    }
    payload[:tool]    = tool if tool
    payload[:summary] = summary if summary && !summary.empty?
    payload[:meta]    = meta.to_json if meta

    uri  = URI.join(endpoint, "/events")
    http = Net::HTTP.new(uri.host, uri.port)
    http.open_timeout = TIMEOUT
    http.read_timeout = TIMEOUT
    http.use_ssl = uri.scheme == "https"

    request = Net::HTTP::Post.new(uri.path)
    request["Content-Type"]  = "application/json"
    request["Authorization"] = "Bearer #{token}"
    request.body = JSON.generate(payload)

    response = http.request(request)
    $stderr.puts "[brivlo] Server returned #{response.code}" unless response.is_a?(Net::HTTPSuccess)
  rescue Errno::ECONNREFUSED, Net::OpenTimeout, Net::ReadTimeout, SocketError => e
    $stderr.puts "[brivlo] #{e.message}" if ENV["BRIVLO_DEBUG"]
  end

  def run
    load_config

    unless ENV["BRIVLO_ENDPOINT"] && ENV["BRIVLO_TOKEN"]
      $stderr.puts "brivlo: missing BRIVLO_ENDPOINT or BRIVLO_TOKEN" if ENV["BRIVLO_DEBUG"]
      return
    end

    input = JSON.parse($stdin.read)
    event, tool, summary, meta_str = map_event(input)
    return unless event

    meta = nil
    if meta_str
      key, value = meta_str.split("=", 2)
      meta = { key => value } if key
    end

    post_event(event,
      instance: detect_instance,
      host:     detect_host,
      tool:     tool,
      summary:  summary,
      meta:     meta)
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
