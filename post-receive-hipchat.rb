#!/usr/bin/env ruby

require 'yaml'
require 'time'
require 'net/https'

CONFIG = YAML::load(File.open(File.join(File.dirname(__FILE__), 'config.yml')))

def speak(message)
  uri = URI.parse("https://api.hipchat.com/")
  http = Net::HTTP.new(uri.host, uri.port)
  http.use_ssl = true
  http.verify_mode = OpenSSL::SSL::VERIFY_NONE
  request = Net::HTTP::Post.new("/v1/rooms/message")
  request.set_form_data({"message" => message,
      "auth_token" => CONFIG['hipchat_api_token'],
      "room_id" => CONFIG['hipchat_room'],
      "notify" => CONFIG['notify'],
      "from" => CONFIG['from']})
  response = http.request(request)
end

repository = CONFIG['repository'] ||= File.basename(Dir.getwd, ".git")
if CONFIG['gitweb_url']
  url = "#{CONFIG['gitweb_url']}/#{repository}.git/commit/"
elsif CONFIG['cgit_url']
  url = "#{CONFIG['cgit_url']}/#{repository}/commit/?id="
end

git = `which git`.strip

# Call to pre-speak hook
load File.join(File.dirname(__FILE__), 'pre-speak') if File.exist?(File.join(File.dirname(__FILE__), 'pre-speak'))

# Write in a file the timestamp of the last commit already posted to the room.
filename = File.join(File.dirname(__FILE__), repository[/[\w.]+/] + ".log")
if File.exist?(filename)
  last_revision = Time.parse(File.open(filename) { |f| f.read.strip })
else
  # TODO: Skip error message if push includes first commit?
  # Commenting out noisy error message for now
  # room.speak("Warning: Couldn't find the previous push timestamp.")
  last_revision = Time.now - 120
end

revtime = last_revision.strftime("%Y %b %d %H:%M:%S %Z")
File.open(filename, "w+") { |f| f.write Time.now.utc }

if CONFIG['message_format'] == "edouard"
  text = `#{git} log --all --since='#{revtime}' --reverse`
  lines = text.split("\n\ncommit ")

  if lines.any?
    speak "Repository #{repository} has been pushed with the following commits:"
    lines.each do |line|
      revision       = line[/([a-f0-9]{40})/]
      commit_author  = `#{git} show --pretty=format:"%an" #{revision} | sed q`.chomp
      commit_log     = `#{git} show --pretty=format:"%s" #{revision}  | sed q`.chomp
      commit_date    = `#{git} show --pretty=format:"%aD" #{revision} | sed q`.chomp
      commit_changed = `#{git} diff-tree --name-status #{revision}    | sed -n '$p'`
      commit_changes = commit_changed.split("\n").inject([]) do |memo, line|
        if line.strip =~ /(\w)\s+(.*)/
          memo << [$1, $2]
        end
      end.to_yaml
      speak "#{commit_author} commited "#{commit_log}". #{url + revision}"
    end
  end

elsif CONFIG['message_format'] == "git-log"
  commit_changes = `#{git} log --name-status --since='#{revtime}' --reverse`
  unless commit_changes.empty?
    revision = commit_changes[/([a-f0-9]{40})/]
    message = "Repository #{repository} has been pushed with the following commits:\n\n"
    message += commit_changes
    message += "\n"
    message += "View commit at: #{url + revision}\n" unless CONFIG['use_url'] == false
    speak "#{message}"
  end
end

# Call to post-speak hook
load File.join(File.dirname(__FILE__), 'post-speak') if File.exist?(File.join(File.dirname(__FILE__), 'post-speak'))
