#!/usr/bin/env ruby

require 'net/http'
require 'json'

# https://bx.in.th/api/pairing/
PAIRINGS = JSON.parse('{"1":{"pairing_id":1,"primary_currency":"THB","secondary_currency":"BTC"},"21":{"pairing_id":21,"primary_currency":"THB","secondary_currency":"ETH"},"22":{"pairing_id":22,"primary_currency":"THB","secondary_currency":"DAS"},"23":{"pairing_id":23,"primary_currency":"THB","secondary_currency":"REP"},"20":{"pairing_id":20,"primary_currency":"BTC","secondary_currency":"ETH"},"4":{"pairing_id":4,"primary_currency":"BTC","secondary_currency":"DOG"},"6":{"pairing_id":6,"primary_currency":"BTC","secondary_currency":"FTC"},"24":{"pairing_id":24,"primary_currency":"THB","secondary_currency":"GNO"},"13":{"pairing_id":13,"primary_currency":"BTC","secondary_currency":"HYP"},"2":{"pairing_id":2,"primary_currency":"BTC","secondary_currency":"LTC"},"3":{"pairing_id":3,"primary_currency":"BTC","secondary_currency":"NMC"},"26":{"pairing_id":26,"primary_currency":"THB","secondary_currency":"OMG"},"14":{"pairing_id":14,"primary_currency":"BTC","secondary_currency":"PND"},"5":{"pairing_id":5,"primary_currency":"BTC","secondary_currency":"PPC"},"19":{"pairing_id":19,"primary_currency":"BTC","secondary_currency":"QRK"},"15":{"pairing_id":15,"primary_currency":"BTC","secondary_currency":"XCN"},"7":{"pairing_id":7,"primary_currency":"BTC","secondary_currency":"XPM"},"17":{"pairing_id":17,"primary_currency":"BTC","secondary_currency":"XPY"},"25":{"pairing_id":25,"primary_currency":"THB","secondary_currency":"XRP"},"8":{"pairing_id":8,"primary_currency":"BTC","secondary_currency":"ZEC"}}').freeze

DEFAULT_PAIRING_ID = 26 # THB-OMG

def run
  # TODO: Remove this line
  # More info: https://github.com/narze/bitbar-bx/pull/1
  rename_old_settings_file

  settings = load_settings
  settings['pairing_id'] ||= DEFAULT_PAIRING_ID.to_s
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
  else
    # Do nothing for now
  end

  url = 'https://bx.in.th/api/'
  response = Net::HTTP.get(URI(url))
  data = JSON.parse(response)[settings['pairing_id']]
  output(data, previous_price: settings['previous_price'])

  settings['previous_price'] = data['last_price']
  save_settings(settings)
end

def output(d, previous_price: nil)
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
  summary = "#{primary}-#{secondary} @ #{r(last_price)}#{direction} (#{change_percent})"
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
    "Change pairing | bash='#{__FILE__}' param1=set_pairing terminal=false refresh=true",
    "Refresh | bash='/usr/bin/open' param1='bitbar://refreshPlugin?name=bx_in_th.*?.rb' terminal=false",
    "Go to bx.in.th | href=https://bx.in.th",
  ]

  [
    summary,
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

# TODO: Remove this method
# More info: https://github.com/narze/bitbar-bx/pull/1
def rename_old_settings_file
  if File.exist? old_settings_file
    File.rename(old_settings_file, settings_file)
  end
end

# TODO: Remove this method
# More info: https://github.com/narze/bitbar-bx/pull/1
def old_settings_file
  File.join(File.dirname(__FILE__), "bx_in_th.conf")
end

def settings_file
  File.join(File.dirname(__FILE__), ".bx_in_th.conf")
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
