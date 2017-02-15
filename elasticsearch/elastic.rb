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
require 'cgi'



def elastic_call args = ARGV
  STDERR.print "elasticsearch_url(host:port):" 
  url = args.shift || gets.chomp
  STDERR.print "index_name:" 
  index_name = args.shift || gets.chomp
  STDERR.print "mapping_name:" 
  mapping_name = args.shift || gets.chomp
  STDERR.print "document_name:" 
  document_name = args.shift || gets.chomp
  STDERR.print "query:" 
  query = args.shift || gets.chomp
  STDERR.print "json[control-D to stop; empty/invalid json will perform a GET instead]:"
  json_doc = args.shift ||  readlines.join
  STDERR.puts

  query  = (query.length > 0) && ("_search?q=#{query}&pretty=true") || query
  index_name = CGI.escape index_name
  mapping_name = CGI.escape mapping_name
  document_name = CGI.escape document_name
  puts document_name
  # query = CGI.escape query
  uri = "#{url}/#{index_name}/#{mapping_name}/#{document_name}/#{query}"
  c = begin
      JSON.parse json_doc
      puts "curl -XPUT \"#{uri}\" -d \"#{json_doc}\""
      Curl::Easy.http_put uri, json_doc
    rescue
      puts "curl -XGET \"#{uri}\""
      Curl::Easy.http_get uri
  end
=begin
  c.http_auth_types = :basic
  c.username = username
  c.password = password
=end
  c.headers['Content-Type'] = 'application/json'
  # pp "c ... "
  c.perform
  response = JSON.parse c.body_str
  response
end


def populate_json_elastic_call args = ARGV
  STDERR.print "elasticsearch_url(host:port):" 
  url = args.shift || gets.chomp
  STDERR.print "index_name:" 
  index_name = args.shift || gets.chomp
  STDERR.print "json_uri:" 
  json_uri = args.shift || gets.chomp
  json_obj = begin
      JSON.parse open(json_uri).read
    rescue
      {}
  end
  {
    "populate_json_elastic_call" => json_obj.map { |k, v|
       p k
       elastic_call [url, index_name, (File.basename json_uri), k, '',  {k => v}.to_json]
    }
  }
end

def main args = ARGV
  STDERR.print "action [elastic_call, populate_json_elastic_call]:" 
  action = args.shift || gets.chomp
  pp method(action).call 
end

main

=begin
c = Curl::Easy.http_get("#{url}/#{index_name}/#{mapping_name}/comment")
c.http_auth_types = :basic
c.username = username
c.password = password
c.perform
#  amount of comments currently on that issue:
total = ((JSON.parse c.body_str).fetch "total")

p "... Response:"
pp (JSON.parse c.body_str)
=end
