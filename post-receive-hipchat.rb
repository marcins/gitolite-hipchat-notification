#!/usr/bin/env ruby

require 'yaml'
require 'time'
require 'net/https'

CONFIG = YAML::load(File.open(File.join(File.dirname(__FILE__), 'config.yml')))

def speak(message)
  uri = URI.parse("https://api.hipchat.com/")
  http = Net::HTTP.new(uri.host, uri.port, CONFIG['proxy_address'],
      CONFIG['proxy_port'])
  http.use_ssl = true
  http.verify_mode = OpenSSL::SSL::VERIFY_NONE
  request = Net::HTTP::Post.new("/v1/rooms/message")
  request.set_form_data({"message" => message,
      "auth_token" => CONFIG['hipchat_api_token'],
      "room_id" => CONFIG['hipchat_room'],
      "notify" => CONFIG['notify'],
      "from" => CONFIG['from']})
  response = http.request(request)
  puts "HipChat: Response - #{response.body}"
end

repository = CONFIG['repository'] ||= File.basename(Dir.getwd, ".git")
if CONFIG['gitweb_url']
  repo_url = "#{CONFIG['gitweb_url']}/#{repository}.git/"
  commit_url = repo_url + "commit/"
elsif CONFIG['cgit_url']
  repo_url = "#{CONFIG['cgit_url']}/#{repository}/"
  commit_url = repo_url + "commit/?id="
elsif CONFIG['fisheye_url']
  repo_url = "#{CONFIG['fisheye_url']}/browse/#{repository}/"
  commit_url = "#{CONFIG['fisheye_url']}/changelog/#{repository}?cs="
else
  repo_url = commit_url = nil
end

git = `which git`.strip

# Call to pre-speak hook
load File.join(File.dirname(__FILE__), 'pre-speak') if File.exist?(File.join(File.dirname(__FILE__), 'pre-speak'))

# Write in a file the timestamp of the last commit already posted to the room.
filename = File.join(File.dirname(__FILE__), repository[/[\w.]+/] + ".log")
if ARGV[0] and ARGV[0] == 'test'
  last_revision = Time.now - 100_000_000
elsif File.exist?(filename)
  last_revision = Time.parse(File.open(filename) { |f| f.read.strip })
else
  # TODO: Skip error message if push includes first commit?
  # Commenting out noisy error message for now
  # room.speak("Warning: Couldn't find the previous push timestamp.")
  last_revision = Time.now - 120
end

revtime = last_revision.strftime("%Y %b %d %H:%M:%S %Z")
File.open(filename, "w+") { |f| f.write Time.now.utc }

commit_changes = `#{git} log --abbrev-commit --oneline --since='#{revtime}' --reverse --pretty=format:"%h %d %an: %s" --all`
unless commit_changes.empty?
  message = "Commits just pushed to "
  if repo_url
    message += "<a href=\"#{repo_url}\">"
  end
  message += repository
  if repo_url
    message += "</a>"
  end
  message += ":<br/>"

  commit_changes.split("\n").each do |commit|
    if commit.strip =~ /^([\da-z]+) (.*)/
      if commit_url
        message += "<a href=\"#{commit_url + $1}\">"
      end
      message += $1
      if commit_url
        message += "</a>"
      end
      message += " #{$2.split("\n").first}<br/>"
    end
  end
  speak message
end

# Call to post-speak hook
load File.join(File.dirname(__FILE__), 'post-speak') if File.exist?(File.join(File.dirname(__FILE__), 'post-speak'))
