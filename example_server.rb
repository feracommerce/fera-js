class ExampleServer
  def call(env)
    req = Rack::Request.new(env)
    # params = Rack::Utils.parse_nested_query(req['QUERY_STRING'].to_s)

    if req.path =~ /^\/dist\//i
      new_path = req.path.gsub(/^\/dist\//i, '')
      content_type = req.path =~ /^\/css/i ? 'text/css' : 'application/javascript'
      [200, { 'Content-Type' => content_type }, [File.read("dist/#{ new_path }")]]
    elsif req.path != "/"
      [200, req.path =~ /\\.html$/i ? { 'Content-Type' => 'text/html' } : {}, [File.read("examples#{ req.path }")]]
    else
      [200, { 'Content-Type' => 'text/html' }, [File.read("examples/index.html")]]
    end
  rescue Errno::ENOENT
    not_found!
  end

  def not_found!
    [404, { 'Content-Type' => 'text/plain' }, ["File not found."]]
  end
end
