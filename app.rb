require 'sinatra'

get '/*' do
  mode = params['mode'] =~ /^(?:get|set|clear)$/ ? params['mode'] : 'get'
  send(mode)
end

def get
  @cookies = request.cookies
  erb :cookies
end

def set
  @set_cookies = []
  reserved_keys = ['path', 'mode', 'format']
  path = params['path'] || request.path
  format = params['format']

  params.each do |key, value_len|
    next if reserved_keys.any? {|k| k == key}
    next if value_len.is_a? Enumerable
    next if value_len.to_i == 0
    next if value_len.to_i > 100000
    value = ''
    value_len.to_i.times{value  << (65 + rand(25)).chr}
    response.set_cookie(key, {:value => value, :expires => Time.new(Time.new().year + 1, 1, 1), :path => path})
    @set_cookies.push({'key' => key, 'value' => value})
  end

  if format == 'gif'
    content_type 'image/gif'
    "GIF89a\1\0\1\0%c\0\0%c%c%c\0\0\0,\0\0\0\0\1\0\1\0\0%c%c%c\1\0;" % [144, 153, 0, 0, 2, 2, 4]
  else
    erb :set
  end
end

def clear
  @cookies = request.cookies
  request.cookies.each do |key, value|
    response.set_cookie(key, {:value => '', :expires => Time.new(2000,1,1)})
  end
  erb :clear
end

after do
  response['P3P'] = 'CP="ADM NOI OUR"'
end
