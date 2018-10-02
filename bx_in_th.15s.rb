#!/usr/bin/env ruby

require 'net/http'
require 'json'

# https://bx.in.th/api/pairing/
PAIRINGS = JSON.parse('{"1":{"pairing_id":"1","primary_currency":"THB","secondary_currency":"BTC","primary_min":"10.00000000","secondary_min":"0.00050000","active":true},"2":{"pairing_id":"2","primary_currency":"BTC","secondary_currency":"LTC","primary_min":"0.00050000","secondary_min":"0.04000000","active":true},"3":{"pairing_id":"3","primary_currency":"BTC","secondary_currency":"NMC","primary_min":"0.00050000","secondary_min":"0.60000000","active":true},"4":{"pairing_id":"4","primary_currency":"BTC","secondary_currency":"DOG","primary_min":"0.00050000","secondary_min":"1000.00000000","active":true},"5":{"pairing_id":"5","primary_currency":"BTC","secondary_currency":"PPC","primary_min":"0.00050000","secondary_min":"0.25000000","active":true},"6":{"pairing_id":"6","primary_currency":"BTC","secondary_currency":"FTC","primary_min":"0.00050000","secondary_min":"25.00000000","active":true},"7":{"pairing_id":"7","primary_currency":"BTC","secondary_currency":"XPM","primary_min":"0.00050000","secondary_min":"3.00000000","active":true},"8":{"pairing_id":"8","primary_currency":"BTC","secondary_currency":"ZEC","primary_min":"0.00050000","secondary_min":"0.00800000","active":true},"9":{"pairing_id":"9","primary_currency":"BTC","secondary_currency":"ZET","primary_min":"0.00050000","secondary_min":"1000.00000000","active":false},"11":{"pairing_id":"11","primary_currency":"BTC","secondary_currency":"CPT","primary_min":"0.00050000","secondary_min":"100.00000000","active":false},"13":{"pairing_id":"13","primary_currency":"BTC","secondary_currency":"HYP","primary_min":"0.00050000","secondary_min":"500.00000000","active":true},"14":{"pairing_id":"14","primary_currency":"BTC","secondary_currency":"PND","primary_min":"0.00050000","secondary_min":"3000.00000000","active":true},"15":{"pairing_id":"15","primary_currency":"BTC","secondary_currency":"XCN","primary_min":"0.00050000","secondary_min":"20.00000000","active":true},"17":{"pairing_id":"17","primary_currency":"BTC","secondary_currency":"XPY","primary_min":"0.00050000","secondary_min":"50.00000000","active":true},"18":{"pairing_id":"18","primary_currency":"BTC","secondary_currency":"LEO","primary_min":"0.00050000","secondary_min":"1000.00000000","active":false},"19":{"pairing_id":"19","primary_currency":"BTC","secondary_currency":"QRK","primary_min":"0.00050000","secondary_min":"100.00000000","active":true},"20":{"pairing_id":"20","primary_currency":"BTC","secondary_currency":"ETH","primary_min":"0.00050000","secondary_min":"0.00200000","active":true},"21":{"pairing_id":"21","primary_currency":"THB","secondary_currency":"ETH","primary_min":"10.00000000","secondary_min":"0.00200000","active":true},"22":{"pairing_id":"22","primary_currency":"THB","secondary_currency":"DAS","primary_min":"10.00000000","secondary_min":"0.00200000","active":true},"23":{"pairing_id":"23","primary_currency":"THB","secondary_currency":"REP","primary_min":"10.00000000","secondary_min":"0.00200000","active":true},"24":{"pairing_id":"24","primary_currency":"THB","secondary_currency":"GNO","primary_min":"10.00000000","secondary_min":"0.00200000","active":true},"25":{"pairing_id":"25","primary_currency":"THB","secondary_currency":"XRP","primary_min":"10.00000000","secondary_min":"0.30000000","active":true},"26":{"pairing_id":"26","primary_currency":"THB","secondary_currency":"OMG","primary_min":"10.00000000","secondary_min":"0.20000000","active":true},"27":{"pairing_id":"27","primary_currency":"THB","secondary_currency":"BCH","primary_min":"10.00000000","secondary_min":"0.00010000","active":true},"28":{"pairing_id":"28","primary_currency":"THB","secondary_currency":"EVX","primary_min":"10.00000000","secondary_min":"0.01000000","active":true},"29":{"pairing_id":"29","primary_currency":"THB","secondary_currency":"XZC","primary_min":"10.00000000","secondary_min":"0.01000000","active":true},"30":{"pairing_id":"30","primary_currency":"THB","secondary_currency":"LTC","primary_min":"10.00000000","secondary_min":"0.00100000","active":true},"31":{"pairing_id":"31","primary_currency":"THB","secondary_currency":"POW","primary_min":"10.00000000","secondary_min":"0.30000000","active":true},"32":{"pairing_id":"32","primary_currency":"THB","secondary_currency":"ZMN","primary_min":"10.00000000","secondary_min":"0.30000000","active":true}}').freeze

DEFAULT_PAIRING_ID = 26 # THB-OMG
DEFAULT_MODE = 'default'

def run
  settings = load_settings
  settings['pairing_id'] ||= DEFAULT_PAIRING_ID.to_s
  settings['mode'] ||= DEFAULT_MODE
  current_pairing = PAIRINGS[settings['pairing_id']].values_at('primary_currency', 'secondary_currency').join('-')

  case ARGV[0]
  when 'set_pairing'
    pairing_input = prompt("Set pairing in XXX-YYY eg. THB-OMG", current_pairing)
    primary, secondary = pairing_input.upcase.split('-')
    pairing = PAIRINGS.detect { |_id, p| p['primary_currency'] == primary && p['secondary_currency'] == secondary }

    if pairing
      settings['pairing_id'] = pairing[0]
      settings['previous_price'] = nil
      notification('Pairing changed', "Pairing changed to #{primary}-#{secondary}")
    else
      notification('Error', 'Invalid pairing')
    end
  when 'set_mode'
    settings['mode'] = ARGV[1]
  else
    # Do nothing for now
  end

  url = 'https://bx.in.th/api/'
  response = Net::HTTP.get(URI(url))

  begin
    data = JSON.parse(response)[settings['pairing_id']]
  rescue Exception => _
    puts "Error : Bad response from bx API. Maybe server is down"
    return
  end

  output(data, previous_price: settings['previous_price'], mode: settings['mode'])

  settings['previous_price'] = data['last_price']
  save_settings(settings)
end

def output(d, previous_price: nil, mode: DEFAULT_MODE)
  primary = d['primary_currency']
  secondary = d['secondary_currency']
  last_price = d['last_price']
  change = d['change']
  order_book = d['orderbook']
  bids = order_book['bids']
  asks = order_book['asks']

  if previous_price && previous_price > last_price
    direction = ' ⬇︎'
  elsif previous_price && previous_price < last_price
    direction = ' ⬆︎'
  else
    direction = ''
  end

  change_percent = "#{change > 0 ? '+' : ''}#{change}%"
  summary = {
    default: "#{primary}-#{secondary} @ #{r(last_price)}#{direction} (#{change_percent})",
    mini: "#{secondary} #{r(last_price)}#{direction}",
  }
  mode_change = {
    default: "Mini Mode | bash='#{__FILE__}' param1=set_mode param2=mini terminal=false refresh=true",
    mini: "Default Mode | bash='#{__FILE__}' param1=set_mode param2=default terminal=false refresh=true",
  }
  details = [
    "---",
    "24h volume : #{r(d['volume_24hours'])} #{secondary}",
    "Change : #{change_percent}",
    "---",
    "Buy orders (Bids) @ #{r(bids['highbid'])} #{secondary}",
    "Volume : #{r(bids['volume'])} #{secondary}",
    "Total : #{c(bids['total'])} orders",
    "---",
    "Sell orders (Asks) @ #{r(asks['highbid'])} #{secondary}",
    "Volume : #{r(asks['volume'])} #{secondary}",
    "Total : #{c(asks['total'])} orders",
    "---",
    mode_change[mode.to_sym],
    "Change pairing | bash='#{__FILE__}' param1=set_pairing terminal=false refresh=true",
    "Refresh | href=bitbar://refreshPlugin?name=bx_in_th.*?.rb",
    "Go to bx.in.th | href=https://bx.in.th",
    "---",
    "Download update | href=bitbar://openPlugin?title=BX&src=https://github.com/narze/bitbar-bx/raw/master/bx_in_th.15s.rb",
    "Go to Github | href=https://github.com/narze/bitbar-bx",
  ]

  [
    summary[mode.to_sym],
    *details,
  ].each(&method(:puts))
end

def prompt(question, default=nil)
  `/usr/bin/osascript -e 'Tell application "System Events" to display dialog "#{question}" default answer "#{default}"' -e 'text returned of result'`.strip
end

def notification(title, message)
  `/usr/bin/osascript -e 'display notification "#{message}" with title "#{title}"'`
end

def save_settings(settings)
  File.open(settings_file, 'w') {|f| f.write(settings.to_json) }
end

def load_settings
  if File.exist? settings_file
    JSON.parse(File.read(settings_file))
  else
    {}
  end
end

def settings_file
  File.join("/tmp", "bitbar_bx.conf")
end

def r(number)
  c("%0.02f" % number)
end

def c(number)
  left, right = number.to_s.split('.')
  left.gsub!(/(\d)(?=(\d\d\d)+(?!\d))/) do |digits|
    "#{digits},"
  end
  [left, right].compact.join('.')
end

begin
  run
rescue StandardError => msg
  puts "Error occurred : #{msg}"
end
