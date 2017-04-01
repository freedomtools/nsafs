require 'rfusefs'
require 'rest-client'
require 'json'

DEFAULT_WAIT           = 0
POLL_STATUS_INTERVAL   = 300
JURISDICTION           = 10
AGENCY_NSA             = 17
AGENCY_CIA             = 6
API_BASE               = 'https://www.muckrock.com/api_v1'
IP_SERVER              = 'http://whatismyip.akamai.com'
OPTIONS_HELP           = '  -o username=testuser,api_token=abc123[,wait=600] '\
                         'MuckRock username and API token, seconds to wait for data'
DOC_REQUEST_FORMAT     = 'I would like to obtain the %d bytes of HTTP body data transmitted in a request from '\
                         'my computer (IP address %s) to https://www.%s.com/ at exactly %s.'
DOC_REQUEST_FORMAT_CIA = 'I would like to obtain %d bytes of data consumed by proccess #%d on '\
                         'my computer (IP address %s) at exactly %s.'
UNAVAILABLE_ERROR_MSG  = 'Current file data unavailable: FOIA request still pending'
PAYMENT_ERROR_MSG      = 'Out of requests. FOIA request has been saved as a draft, but not submitted.'
OPTIONS                = [:username, :api_token, :endpoint, :cia_mode, :wait]
ENDPOINTS              = [:aol, :apple, :facebook, :google, :microsoft, :paltalk, :skype, :yahoo, :youtube]


class NSAFS

  def initialize username, api_token, endpoint=nil, cia_mode=nil, wait=nil
    raise ArgumentError, 'username is required' unless username && username.length > 0
    raise ArgumentError, 'api_token is required' unless api_token && api_token.length > 0
    raise ArgumentError, 'invalid endpoint' unless !endpoint || ENDPOINTS.include?(endpoint.downcase.to_sym)
    @username, @api_token = username, api_token
    @endpoint = (endpoint && endpoint.downcase) || ENDPOINTS.first
    @cia_mode = cia_mode == '1'
    @wait = (wait || DEFAULT_WAIT).to_i
  end


  def contents path
    path == '/' ? file_entries.keys : []
  end

  def file? path
    !!find_entry(path)
  end

  def directory? path
    path == '/'
  end

  def can_mkdir? path
    false
  end

  def can_rmdir? path
    false
  end

  # Once in the cloud, always in the cloud (TM)
  def can_delete? path
    false
  end

  def can_write? path
    true
  end

  def touch path, modtime
    puts 'Not implemented'
  end

  def write_to path, body
    return if body.length <= 0
    if @cia_mode
      # No need to transmit data ourselves; the backdoors will handle it.
    else
      begin
        RestClient.post("https://www.#{@endpoint}.com/", body)
      rescue RestClient::ExceptionWithResponse
        # Ignore HTTP errors; we've done our job. Data is in safe gov't keeping now.
      end
    end
    title = generate_title(File.basename(path), body.length)
    doc_request = @cia_mode ?
      DOC_REQUEST_FORMAT_CIA % [body.length, Process.pid, my_ip, Time.new.to_s]
      : DOC_REQUEST_FORMAT % [body.length, my_ip, @endpoint, Time.new.to_s]
    begin
      send_request(:post, '/foia/', {}, {
        jurisdiction: JURISDICTION,
        agency: @cia_mode ? AGENCY_CIA : AGENCY_NSA,
        title: title,
        document_request: doc_request,
      })
    rescue RestClient::PaymentRequired
      puts PAYMENT_ERROR_MSG
    end
  end

  def read_file path
    waited = 0
    while !(done = find_entry(path, status: 'done')) || !done[:url]
      if waited >= @wait
        puts UNAVAILABLE_ERROR_MSG
        return ''
      end
      wait = [[POLL_STATUS_INTERVAL, @wait - waited].min, 0].max
      waited += wait
      sleep wait
    end
    RestClient.get(done[:url]).body
  end

  def size path
    entry = find_entry(path)
    entry && entry[:size]
  end

  def times path
    entry = find_entry(path)
    entry && [entry[:timestamp]] * 3
  end


  private

  def find_entry path, criteria={}
    filename = File.basename(path)
    found = file_entries(criteria).find{|f, entry| f == filename }
    found && found[1]
  end

  # Each time a file is created/modified, a separate FOIA request is made.
  # When listing files, we only consider the latest version for each unique name.
  def file_entries criteria={}
    files = {}
    my_foias(criteria).each do |entry|
      existing = files[entry[:filename]]
      files[entry[:filename]] = entry if !existing || (existing[:timestamp] < entry[:timestamp])
    end
    files
  end

  def generate_title filename, size, timestamp=Time.new
    '%s (%d,%d)' % [filename, size, timestamp.to_i]
  end

  def title_props title
    filename, size, timestamp = title.scan(/(.*)\s*\((\d+),(\d+)\)$/i)[0]
    { filename: filename.strip, size: size.to_i, timestamp: Time.at(timestamp.to_i) }
  end

  def my_foias criteria={}
    filter = { user: @username }.merge(criteria)
    send_request(:get, '/foia/', filter)['results'].map do |r|
      title_props(r['title']).merge({
        url: (r['communications'].find{|r| r['response'] && r['status'] == 'done' }['files'][0]['ffile'] rescue nil)
      })
    end
  end

  def send_request request_method, path, params={}, payload=nil
    headers = { Authorization: 'Token %s' % @api_token, content_type: :json, accept: :json }
    response = RestClient::Request.execute(
      method: request_method,
      url: API_BASE + path,
      headers: headers.merge(params: params),
      payload: payload && payload.to_json,
    )
    JSON.parse(response)
  end

  def my_ip
    RestClient.get(IP_SERVER).body
  end

end


# Usage: #{$0} mountpoint [mount_options]
FuseFS.main(ARGV, OPTIONS, OPTIONS_HELP) do |options|
  NSAFS.new(*OPTIONS.map{|o| options[o] })
end
