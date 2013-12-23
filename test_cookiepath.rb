#!/usr/bin/env ruby
require 'selenium-webdriver'
require 'nokogiri'
require 'net/http'
require 'uri'
require 'json'

@username = ENV['BROWSERSTACK_USER']
@passphrase = ENV['BROWSERSTACK_PASS']

def _request_and_get_cookie(driver, url)
  cookies = {}
  driver.navigate.to url
  html = driver.page_source
  doc = Nokogiri::HTML(html)
  doc.css('.cookies').each do |x|
    k, v = x.content.split('=')
    cookies[k] = v
  end
  return cookies
end

def _build_driver(browser, browser_version)
  driver_endpoint = sprintf 'http://%s:%s@hub.browserstack.com/wd/hub', @username, @passphrase
  caps = Selenium::WebDriver::Remote::Capabilities.new
  caps["browser"] = browser
  caps["browser_version"] = browser_version
  Selenium::WebDriver.for(:remote,
                          :url => driver_endpoint,
                          :desired_capabilities => caps)
end

def _run(browser, browser_version, cookie_pathes)
  cookie_app_url = 'http://cookie-baker.herokuapp.com'
  test_pathes = ['/foo', '/foo/', '/foobar', '/foo/bar']
  result = []

  driver = _build_driver browser, browser_version

  begin
    set_cookies = {}
    cookie_pathes.each_index do |i|
      key = i.to_s
      path = cookie_pathes[i]
      cookies = _request_and_get_cookie(driver, sprintf("%s%s?mode=set&%s=10", cookie_app_url, path, key))
      set_cookies[key] = {'value' => cookies[key], 'path' => path}
    end

    test_pathes.each do |test_path|
      got_cookies = _request_and_get_cookie(driver, sprintf("%s%s", cookie_app_url, test_path))
      received_cookies = got_cookies.keys.map{|key|
        is_received = set_cookies.include?(key) and got_cookies[key] == set_cookies[key]['value']
        is_received ? set_cookies[key]['path'] : false
      }.select{|x| x}
      result.push({
                    'browser' => browser,
                    'browser_version' => browser_version,
                    'cookie_path' => cookie_pathes.join(','),
                    'test_path' => test_path,
                    'result' => received_cookies.length > 0 ? received_cookies.join(',') : '-',
                  })
    end
  rescue => e
    result.push({
                  'browser' => browser,
                  'browser_version' => browser_version,
                  'cookie_path' => cookie_pathes.join(','),
                  'test_path' => '-',
                  'result' => "error: #{$!}",
                })
  end

  driver.quit

  return result
end

def run(browser, browser_version)
  results = []

  results.concat(_run(browser, browser_version, ['/foo']))

  sleep 5

  results.concat(_run(browser, browser_version, ['/foo/']))

  sleep 5

  results.concat(_run(browser, browser_version, ['/foo', '/foo/']))

  return results
end

def output_as_tsv(results)
  results.each do |res|
    browser = res['browser']
    browser_version = res['browser_version']
    cookie_path = res['cookie_path']
    test_path = res['test_path']
    result = res['result']
    puts [browser, browser_version, cookie_path, test_path, result].join("\t")
  end
  STDOUT.flush
end

def fetch_browser_list
  results = []

  url = URI.parse('https://www.browserstack.com/automate/browsers.json')
  req = Net::HTTP::Get.new(url.path)
  req.basic_auth @username, @passphrase
  http = Net::HTTP.new(url.host, url.port)
  http.use_ssl = true

  begin
    res = http.request(req)
    api_response = JSON.parse(res.body)
  rescue Exception
    puts "error: #{$!}"
    return
  end

  target_browsers = ['ie', 'chrome', 'firefox', 'opera', 'safari']
  api_response.each do |env|
    next unless target_browsers.include? env['browser']
    results.push([env['browser'], env['browser_version']])
  end

  results.uniq.sort {|a, b| a[0] == b[0] ? a[1].to_f <=> b[1].to_f :  a[0] <=> b[0]}
end

def main
  if ARGV[0] and ARGV[1]
    browsers = [[ARGV[0], ARGV[1]]]
  else
    browsers = fetch_browser_list
  end

  browsers.each do |browser|
    results = run(browser[0], browser[1])
    output_as_tsv(results)
  end
end

main
