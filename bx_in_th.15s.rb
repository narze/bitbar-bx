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
  output(data)
end

def output(d)
  primary = d['primary_currency']
  secondary = d['secondary_currency']
  last_price = d['last_price']
  change = d['change']
  order_book = d['orderbook']
  bids = order_book['bids']
  asks = order_book['asks']

  summary = "#{primary}-#{secondary} @ #{last_price} (#{change}%)"
  details = [
    "---",
    "24h volume : #{d['volume_24hours']} #{secondary}",
    "---",
    "Buy orders (Bids) @ #{bids['highbid']} #{secondary}",
    "Volume : #{bids['volume']} #{secondary}",
    "Total : #{bids['total']} orders",
    "---",
    "Sell orders (Asks) @ #{asks['highbid']} #{secondary}",
    "Volume : #{asks['volume']} #{secondary}",
    "Total : #{asks['total']} orders",
  ]

  [
    summary,
    *details,
  ].each(&method(:puts))
end

begin
  run
rescue StandardError => msg
  puts "Error occurred : #{msg}"
end
