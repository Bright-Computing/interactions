#!/bin/ruby

# Copyright 2017 Bright Computing Holding BV.

# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at

# http://www.apache.org/licenses/LICENSE-2.0

# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.


require "json"
require "pp"
require "io/console"
require 'webrick'
require 'stringio'
require 'open-uri'
require 'curb'

=begin
print "issue:" 
issue = ARGV.shift || gets.chomp
print "username:"
username = ARGV.shift || gets.chomp
print "password:" 
password = ARGV.shift || begin STDIN.noecho{ gets}.chomp rescue gets.chomp end
puts
print "comment[control-D to stop]:"
comment = ARGV.shift ||  readlines.join
puts
=end

print "url:" 
url = ARGV.shift || gets.chomp

print "index_name:" 
index_name = ARGV.shift || gets.chomp

print "mapping_name:" 
mapping_name = ARGV.shift || gets.chomp

print "document_name:" 
mapping_name = ARGV.shift || gets.chomp

print "query:" 
query = ARGV.shift || gets.chomp

print "json[control-D to stop]:"
json = ARGV.shift ||  readlines.join
puts

c = Curl::Easy.http_get("https://jira.brightcomputing.com:8443/rest/api/2/issue/#{issue}/comment")
c.http_auth_types = :basic
c.username = username
c.password = password
c.perform
#  amount of comments currently on that issue:
total = ((JSON.parse c.body_str).fetch "total")

h = {}
h["body"] = "_comment#{total + 1}:_\n#{comment}"
# puts h.to_json
data = h.to_json
c = (Curl::Easy.http_post "https://jira.brightcomputing.com:8443/rest/api/2/issue/#{issue}/comment", data)
c.http_auth_types = :basic
c.username = username
c.password = password
c.headers['Content-Type'] = 'application/json'
# pp "c ... "
c.perform
# p "... Response:"
pp (JSON.parse c.body_str)
