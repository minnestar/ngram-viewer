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

def download_pages
  pages = JSON.parse(IO.read("pages.json"))
  pages['items'].each do |page|
    LOG.info(page['label'])
    page = Page.new(page['label'])
    page.download_page_text
  end
end

class Page < Object
  def initialize(name)
    @name = name
  end

  def safe_filename
    name = @name.gsub(/\//, '_')
    "raw/#{name}"
  end

  def download_page_text
    if !File.exists?(safe_filename)
      warn "Filename #{safe_filename}"
      uri = URI("http://#{WIKI_SITE}/w/index.php")
      params = { :title => @name, :action => 'raw' }
      uri.query = URI.encode_www_form(params)
      result = Net::HTTP.get(uri)
      IO.write(safe_filename, result)
    end
  end
end

def main
  download_pages
end

main
