#!/usr/bin/env ruby

require 'json'
require 'logger'
require 'net/http'

WIKI_SITE = 'wiki.minnestar.org'

LOG = Logger.new(STDERR)
LOG.level = Logger::INFO

class Page < Object
  def initialize(name)
    @name = name
    @vars = {}
  end

  def safe_filename
    name = @name.gsub(/\//, '_')
    "raw/#{name}"
  end

  def download_page_text
    if !File.exists?(safe_filename)
      LOG.info("Download #{safe_filename}")
      uri = URI("http://#{WIKI_SITE}/w/index.php")
      params = { :title => @name, :action => 'raw' }
      uri.query = URI.encode_www_form(params)
      result = Net::HTTP.get(uri)
      IO.write(safe_filename, result)
    end
  end

  def read_raw
    raw = IO.read(safe_filename)
    # warn "** #{safe_filename}"
    md = /{{Session\n(.+)}}(.+)/m.match(raw)
    raise "empty md" if !md
    # part 1 has vars
    md[1].split("\n").each do |line|
      if line.start_with?('|')
        var, value = line.split('=')
        # drop initial |
        var.slice!(0)
        puts "#{var}=#{value}"
        @vars[var] = value
      end
    end
    # part 2 has session text
    @session_text = md[2]
    #puts "session_text #{@session_text}"
  end
end

def download_page_names
  #page_name_query = '/wiki/Special:Ask/-5B-5BCategory:Session-5D-5D/limit%3D500/searchlabel%3D/format%3Djson'
  #result = Net::HTTP.get(wiki_site, page_name_query)
  #puts "#{result}"

  # returned JSON is invalid, so we have to hand-edit it :(
end

def download_pages(page_names)
  page_names.each do |name|
    page = Page.new(name)
    page.download_page_text
  end
end

def count_events(page_names)
  page_names.each do |name|
    page = Page.new(name)
    page.read_raw
  end
end

def main
  pages = JSON.parse(IO.read("pages.json"))
  page_names = []
  pages['items'].each do |page|
    page_names << page['label']
  end

  download_pages(page_names)

  count_events(page_names)
end

main
