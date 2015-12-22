#
# Download every episode of a podcast
#

require 'open-uri'
require 'nokogiri'

url = "http://casbah.podomatic.com/rss2.xml"
open(url) do |rss|
  doc = Nokogiri::XML(rss)
  doc.xpath("//item").each do |item|
    puts `wget -nc "#{item.xpath('enclosure').attr('url')}"`
  end
end