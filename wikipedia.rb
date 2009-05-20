require 'net/http'
require 'uri'
require 'cgi'

# slightly simplified version of current wikipedia source adapter from rhosync
    
class Wikipedia
  attr_accessor :search_query
  attr_accessor :source
  
  def initialize(source)
    @source=source
  end
  
  #
  # direct response to query from device
  # in the case of wikipedia we return 2 objects per page
  # the header object has information about the page, and
  # the data object has the contents of the page
  #
  # we split this in 2 becasue the data portions are large and we only want
  # to load them selectively for pages to conserve RAM usage on device
  #
  def ask(params)
    puts "Wikipedia ask with #{params.inspect.to_s}\n"
    
    # currently device cannot pass multiple params via ask so we split apart the params here
    device_params = CGI::parse("question="+params['question'])
    
    puts "device params = #{device_params.inspect.to_s}"
    
    question = device_params['question']
    question = question[0] if question.class == Array
    refresh = device_params['refresh'].present?
    
    data = ask_wikipedia question
    
    header_id = "header_#{CGI::escape(question)}"
    data_id = "data_#{CGI::escape(question)}"
    
    # if we are asking to refresh an existing page we have to give it a new object id
    # that is different that the existing object ID or we will get duplicates on the device
    # here we append "_refresh". Device should delete "_refresh" version and overwrite existing
    # TODO: what if there is a device error and there is already a _refresh on device
    if refresh
      header_id += "_refresh"
      data_id += "_refresh"
      
      puts "Doing a refresh of existing page"
      puts "#{header_id}\n#{data_id}\n"
    end
      
    # return array of objects that correspond
    [ 
      ObjectValue.new(@source.id, header_id, "section", "header"),
      ObjectValue.new(@source.id, header_id, "created_at", DateTime.now.to_s),
      ObjectValue.new(@source.id, header_id, "question", question),
      ObjectValue.new(@source.id, header_id, "data_id", data_id),
      
      ObjectValue.new(@source.id, data_id, "section", "data"),
      ObjectValue.new(@source.id, data_id, "data_length", data.length.to_s),
      ObjectValue.new(@source.id, data_id, "data", data),
    ]
  end
  
  protected
  
  # def wiki_name(raw_string)
  #   raw_string == "::Home" ? raw_string : ERB::Util.url_encode(raw_string.gsub(" ", "_"))
  # end
  
  def ask_wikipedia(search)
    # what is passed in when following a link will be encoded
    search = CGI::unescape(search)
    
    # looks like the encoding we are receiving is not the same as what wikipedia will take in some cases 
    # so we decode and then re-encode this so it goes to wikipedia correctly
    search = CGI::escape(search) unless search == "::Home"

    path = "/wiki/#{search}"
    puts "path = #{path}"
 
    # temporarily we hardcode these headers which are required by m.wikipedia.org
    headers = {
      # 'User-Agent' => 'Mozilla/5.0 (iPhone; U; CPU like Mac OS X; en) AppleWebKit/420+ (KHTML, like Gecko) Version/3.0 Mobile/1C28'
      'User-Agent' => 'Rhosync'
    }
    
    response, data = fetch(path, headers)
    data = rewrite_urls(data)
    
    [data].pack("m").gsub("\n", "")
  end
  
  # follow redirects here on the server until we are at final page
  def fetch(path, headers, limit = 10)
    raise ArgumentError, 'HTTP redirect too deep' if limit == 0
 
    mobile_wikipedia_server_url = @source.url
    mobile_wikipedia_server_url.gsub!('http://', '')
    
    # should be http://en.m.wikipedia.org
    puts "mobile_wikipedia_server_url = #{mobile_wikipedia_server_url}"
    http = Net::HTTP.new(mobile_wikipedia_server_url)
    http.set_debug_output $stderr
    
    response, data = http.get(path, headers)
    
    puts "Code = #{response.code}"
    puts "Message = #{response.message}"
    response.each {|key, val|
      puts key + ' = ' + val
    }
    
    case response
    when Net::HTTPSuccess then
      nil
    when Net::HTTPRedirection then
      # location has changed so in effect new search query
      @search_query = response['location'].sub('/wiki/', '')
      response, data = fetch(response['location'], headers, limit - 1)
    else
      response.error!
    end
    
    return response, data
  end
 
  #
  # wikipedia pages are shown in an iframe in the Rhodes app
  # here we rewrite URLs so that they work in that context
  #
  # rewrite URLs of the form:
  # <a href="/wiki/Feudal_System"
  # to
  # <a href="/Wikipedia/WikipediaPage/{Feudal_System}/fetch"
  #
  
  # Did you mean: <a href="/w/index.php?title=Special:Search&amp;search=blackberry&amp;fulltext=Search&amp;ns0=1&amp;redirs=0" title="Special:Search">
  # <em>blackberry</em>
  # </a>
  
  def rewrite_urls(html)
    # images
    html = html.gsub('<img src="/images/logo-en.png" />', '<img src="http://en.m.wikipedia.org/images/logo-en.png" />')
    html = html.gsub(%Q(src='/images/w.gif'), %Q(src='http://en.m.wikipedia.org/images/w.gif'))
    
    # javascripts
    html = html.gsub('window.location', 'top.location')
    html = html.gsub('/wiki/::Random', '/app/WikipediaPage/{::Random}/fetch')
    
    #stylesheets
    # html = html.gsub('<link href=\'/stylesheets/application.css\'', '<link href=\'http://m.wikipedia.org/stylesheets/application.css\'')
    
    #links to other articles
    html = html.gsub(/href=\"\/wiki\/([\w\(\)%:\-\,\/._]*)\"/i) do |s|
      # parameter must be double encoded, rhodes will unencode once automatically
      # if not double encoded will fail
      %Q(href="/app/WikipediaPage/{#{CGI::escape(CGI::escape($1))}}/fetch" target="_top")
    end
    
    # redlinks
    html.gsub(%Q(href="/w/index.php?), %Q(target="_top" href="http://en.wikipedia.org/w/index.php?))
  end
end