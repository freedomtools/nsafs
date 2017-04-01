#!/usr/bin/env ruby

require 'io/console'
require 'net/http'
require 'uri'
require 'json'

API_BASE = 'https://www.muckrock.com/api_v1'

print 'MuckRock Username: '
username = gets.chomp

print 'MuckRock Password: '
password = STDIN.noecho(&:gets).chomp
puts

begin
  response = Net::HTTP.post_form(URI(API_BASE + '/token-auth/'), username: username, password: password)
  token = JSON.parse(response.body)['token'] rescue nil
  raise 'Invalid response data' unless token
  puts 'API Token: ' + token
rescue => e
  puts [e.class.name, (e.message rescue nil)].compact.join(': ')
end
