#!/usr/bin/env ruby

require 'json'
require 'logger'
require 'set'
require 'stemmify'

require_relative 'lib/page'
require_relative 'lib/log'

# Apply Porter stemming to session text
PORTER_STEMMING = false

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

# Simple tokenizer: give text, get back array of words
def text_to_words(text, porter_stemming = false)
  # TODO(dan): mark common words?
  words = text.downcase.split(/[^\w]+/)
  # remove words smaller than 2 chars
  words.delete_if { |word| word.length < 2 }

  if porter_stemming
    new_words = []
    words.each do |word|
      new_words << word.stem
    end
    words = new_words
  end
  words
end

def count_words_by_event(pages)
  counts = Hash.new { |hash,key| hash[key] = Hash.new {
      |hash2,key2| hash2[key2] = 0 } }
  pages.each do |page|
    # count # sessions in which a word appears, per event
    # wordset has each word once (even if stated multiple times)
    wordset = Set.new
    text_to_words(page.session_text,
                  porter_stemming = PORTER_STEMMING).each do |word|
      wordset.add(word)
    end
    wordset.each do |word|
      counts[page.vars['Event']][word] += 1
#      if word.start_with?('docu')
#        warn "docu: #{page.name}"
#      end
    end
  end
  counts.each do |event,wordmap|
    wordmap.each do |word,count|
#      if count > 1
        puts "#{event}\t#{word}\t#{count}"
#      end
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
