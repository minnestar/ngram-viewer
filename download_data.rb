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

  def vars
    @vars
  end

  def session_text
    @session_text
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
        # puts "#{var}=#{value}"
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
  pages = []
  page_names.each do |name|
    page = Page.new(name)
    page.download_page_text
    page.read_raw
    pages << page
  end
  pages
end

def text_to_words(text)
  # TODO(dan): Porter stemming
  # TODO(dan): lowercase?
  # TODO(dan): mark common words?
  words = text.downcase.split(/[^\w]+/)
  # remove words smaller than 2 chars
  words.delete_if { |word| word.length < 2 }
end

def count_words_by_event(pages)
  counts = Hash.new { |hash,key| hash[key] = Hash.new {
      |hash2,key2| hash2[key2] = 0 } }
  pages.each do |page|
    # count # sessions in which a word appears, per event
    text_to_words(page.session_text).each do |word|
      counts[page.vars['Event']][word] += 1
    end
  end
  counts.each do |event,wordmap|
    wordmap.each do |word,count|
      if count > 1
        puts "#{event}\t#{word}\t#{count}"
      end
    end
  end
end

def main
  pages = JSON.parse(IO.read("pages.json"))
  page_names = []
  pages['items'].each do |page|
    page_names << page['label']
  end

  pages = download_pages(page_names)

  count_words_by_event(pages)
end

main
