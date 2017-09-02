#!/usr/bin/env ruby

require 'net/http'
require 'json'

# See pairing id at https://bx.in.th/api/pairing/
PAIRING_ID = 26 # THB-OMG
#PAIRING_ID = 1 # THB-BTC
#PAIRING_ID = 21 # THB-ETH

def run
  url = 'https://bx.in.th/api/'
  response = Net::HTTP.get(URI(url))
  data = JSON.parse(response)[PAIRING_ID.to_s]
  last_price = data["last_price"]
  change = data["change"]
  primary_currency = data["primary_currency"]
  secondary_currency = data["secondary_currency"]
  puts "#{primary_currency}-#{secondary_currency} @ #{last_price} (#{change}%)"
end

begin
  run
rescue StandardError => msg
  puts "Error occurred : #{msg}"
end
