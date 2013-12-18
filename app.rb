require 'sinatra'

get '/' do
  @cookies = request.cookies
  erb :cookies
end

get '/set' do
  @set_cookies = []
  params.each do |key, value_len|
    next if value_len.to_i == 0
    next if value_len.to_i > 100000
    value = ''
    value_len.to_i.times{value  << (65 + rand(25)).chr}
    response.set_cookie(key, value)
    @set_cookies.push({'key' => key, 'value' => value})
  end
  erb :set
end

get '/clear' do
  @cookies = request.cookies
  request.cookies.each do |key, value|
    response.set_cookie(key, {:value => '', :expires => Time.new(2000,1,1)})
  end
  erb :clear
end

after do
  response['P3P'] = 'CP="ADM NOI OUR"'
end
