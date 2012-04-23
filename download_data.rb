#!/usr/bin/env ruby

require 'json'
require 'logger'
require 'set'
require 'stemmify'

require_relative 'lib/page'
require_relative 'lib/log'

# Apply Porter stemming to session text
PORTER_STEMMING = true

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
def text_to_words(text)
  # TODO(dan): mark common words?
  words = text.downcase.split(/[^\w]+/)
  # remove words smaller than 2 chars
  words.delete_if { |word| word.length < 2 }
  words
end

# Take some words and Porter stem them
def stem_words(words)
  new_words = []
  words.each do |word|
    new_words << word.stem
  end
  new_words
end

def count_words_by_event(pages)
  counts = Hash.new { |hash,key| hash[key] = Hash.new {
      |hash2,key2| hash2[key2] = 0 } }
  sessions_per_event = Hash.new { |hash,key| hash[key] = 0 }
  words_to_stems = {}
  pages.each do |page|
    event = page.vars['Event']
    sessions_per_event[event] += 1
    # count # sessions in which a word appears, per event
    # wordset has each word once (even if stated multiple times)
    wordset = Set.new
    [ page.session_text, page.name ].each do |text|
      words = text_to_words(text)
      if PORTER_STEMMING
        stems = stem_words(words) 
        stems.each_with_index do |stem, idx|
          words_to_stems[words[idx]] = stem
        end
        wordset.merge(stems)
      else
        wordset.merge(words)
      end
    end
    wordset.each do |word|
      counts[event][word] += 1
    end
  end
  records = []
  counts.each do |event,wordmap|
    num_sessions = sessions_per_event[event]
    wordmap.each do |word,count|
      fraction = Float(count) / num_sessions
      records << { :event => event, :word => word,
        :count => count, :fraction => fraction }
    end
  end
  [ words_to_stems, records ]
end

def main
  pages = JSON.parse(IO.read("pages.json"))
  page_names = []
  pages['items'].each do |page|
    page_names << page['label']
  end

  pages = download_pages(page_names)

  words_to_stems, records = count_words_by_event(pages)
  # write word => stem file
  if PORTER_STEMMING
    filename = 'words_to_stems.csv'
    LOG.info("Write #{filename}")
    File.open(filename, 'w') do |stemfile|
      stemfile << "word,stem\n"
      words_to_stems.each do |word, stem|
        stemfile << "#{word},#{stem}\n"
      end
    end
    porter_infix = "_porter"
  end
  # write word stats file
  cols = [ :event, :word, :count, :fraction ]
  filename = "word_stats#{porter_infix}.csv"
  LOG.info("Write #{filename}")
  File.open(filename, 'w') do |wordfile|
    wordfile << cols.join(',') << "\n"
    records.each do |record|
      arr = []
      cols.each do |col|
        arr << record[col]
      end
      wordfile << arr.join(',') << "\n"
    end
  end
  # write word stats summary (by event)
  earliest = {}
  total_count = Hash.new { |hash,key| hash[key] = 0 }
  records.each do |record|
    word = record[:word]
    total_count[word] += record[:count]
    event = record[:event]
    earliest[word] = event if !earliest.key?(word) || event < earliest[word]
  end
  filename = "word_stats_summary#{porter_infix}.csv"
  LOG.info("Write #{filename}")
  File.open(filename, 'w') do |summaryfile|
    summaryfile << 'word,count,earliest_event' << "\n"
    total_count.each do |word, count|
      summaryfile << [ word, count, earliest[word] ].join(',') << "\n"
    end
  end
end

main
