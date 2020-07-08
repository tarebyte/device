# frozen_string_literal: true

require "dotenv/load"

require "dotenv"
Dotenv.load

require "json"
require "net/http"
require "pp"
require "pry-byebug"
require "uri"

CLIENT_ID = ENV.fetch("CLIENT_ID", "")

# Development
# BASE_URL  = "https://github.localhost"
# PORT       = 3000
# PRODUCTION = false

# Production
BASE_URL    = "https://github.com"
PORT        = ""
PRODUCTION  = true

def post(path, body)
  url = URI("#{BASE_URL}#{path}")

  https = Net::HTTP.new(url.host, url.port)
  https.use_ssl = true

  unless PRODUCTION # rubocop:disable Style/IfUnlessModifier
    https.verify_mode = OpenSSL::SSL::VERIFY_NONE
  end

  request = Net::HTTP::Post.new(url)
  request["Accept"] = "application/json"

  form_data = []
  body.each_pair { |k, v| form_data << [k.to_s, v] }

  request.set_form form_data, "multipart/form-data"
  https.request(request)
end

def request_code
  response = post("/login/device/code", { client_id: CLIENT_ID })

  case response.code
  when "200"
    json_body = JSON.parse(response.body)

    print_response(json_body)
    request_access_token(json_body)
  when "301"
    puts "Moved Permanently"
  else
    puts response.body
  end
end

def obfusate(json)
  fields = %w[access_token refresh_token]
  obfuscator = "*"

  fields.each do |field|
    value = json[field]
    next unless value

    length = value.length

    start = if length > 20
              8
            elsif lengh > 10
              4
            else
              0
            end
    finish = if length > 20
               length - 11
             elsif length > 19
               length - 5
             else
               length
             end

    start.upto(finish) { |index| value[index] = obfuscator }

    json[field] = value
  end

  json
end

def print_response(json_body)
  puts <<~MESSAGE
    Please visit #{json_body['verification_uri']}
    and enter the following code: #{json_body['user_code']}
  MESSAGE
end

def request_access_token(json_body)
  puts "Waiting..."

  sleep(json_body["interval"].to_i)

  response = post("/login/oauth/access_token", {
    client_id: CLIENT_ID,
    device_code: json_body["device_code"],
    grant_type: "urn:ietf:params:oauth:grant-type:device_code"
  })

  response_json = JSON.parse(response.body)
  return puts(obfusate(response_json)) unless response_json.key?("error")

  puts response_json
  request_access_token(json_body)
end

request_code
