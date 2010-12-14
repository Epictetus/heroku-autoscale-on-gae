# Fix exception
# body, RestClient::Payload::UrlEncoded recive to_java_bytes

module Net  # :nodoc:
  # Monkey patch Net::HTTP to makes requests using Google App Engine's
  # URLFetch Service.
  class HTTP
    def request(req, body=nil, &block)
      begin
        proto = use_ssl? ? 'https' : 'http'
        url = "#{proto}://#{addr_port}#{req.path}"
        options = {
#            :payload => body || req.body,
            :payload => body.to_s || req.body,
            :follow_redirects => false,
            :allow_truncated => true,
            :method => req.method,
            :headers => req
            }
        res = AppEngine::URLFetch.fetch(url, options)
      end while res.kind_of?(Net::HTTPContinue)
      res.reading_body(nil, req.response_body_permitted?) {
        yield res if block_given?
      }
      return res
    end
  end
end
