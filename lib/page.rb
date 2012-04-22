require 'net/http'

WIKI_SITE = 'wiki.minnestar.org'

class Page < Object
  def initialize(name)
    @name = name
    @vars = {}
  end

  def name
    @name
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
