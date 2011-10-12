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
else
  url = nil
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

commit_changes = `#{git} log --abbrev-commit --oneline --since='#{revtime}' --reverse`
unless commit_changes.empty?
  message = "Just pushed to #{repository}:<br/>"
  commit_changes.split("\n").each do |commit|
    if commit.strip =~ /^([\da-z]+) (.*)/
      if url
        message += "<a href=\"#{url + $1}\">"
      end
      message += $1
      if url
        message += "</a>"
      end
      message += " #{$2.split("\n").first}<br/>"
    end
  end
  speak message
end

# Call to post-speak hook
load File.join(File.dirname(__FILE__), 'post-speak') if File.exist?(File.join(File.dirname(__FILE__), 'post-speak'))
