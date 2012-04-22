#!/usr/bin/env ruby

require 'json'
require 'logger'
require 'net/http'

WIKI_SITE = 'wiki.minnestar.org'

LOG = Logger.new(STDERR)
LOG.level = Logger::INFO

def download_page_names
  #page_name_query = '/wiki/Special:Ask/-5B-5BCategory:Session-5D-5D/limit%3D500/searchlabel%3D/format%3Djson'
  #result = Net::HTTP.get(wiki_site, page_name_query)
  #puts "#{result}"

  # returned JSON is invalid, so we have to hand-edit it :(
end

def safe_filename(name)
  name = name.gsub(/\//, '_')
  "raw/#{name}"
end

def download_page_text(title)
  filename = safe_filename(title)
  if !File.exists?(filename)
    warn "Filename #{filename}"
    uri = URI("http://#{WIKI_SITE}/w/index.php")
    params = { :title => title, :action => 'raw' }
    uri.query = URI.encode_www_form(params)
    result = Net::HTTP.get(uri)
    IO.write(filename, result)
  end
end

def main
  pages = JSON.parse(IO.read("pages.json"))
  pages['items'].each do |page|
    LOG.info(page['label'])
    download_page_text(page['label'])
  end
end

main
