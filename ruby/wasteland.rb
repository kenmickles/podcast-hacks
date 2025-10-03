#
# Generate an RSS feed for the Teenage Wasteland radio show
#

require 'nokogiri'
require 'open-uri'
require 'rss'

# scrape website for MP3s
url = "http://wfmu.org/playlists/TW"
page = Nokogiri::HTML(open(url))
mp3s = {}

page.css('a:contains("MP3 - 128K")').each do |a|
  show_id = a.attributes['href'].to_s.gsub(/(.*)show=/, '').gsub(/\&(.*)/, '')
  m3u_url = "http://wfmu.org#{a.attributes['href']}"
  open(m3u_url) do |f|
    mp3s[show_id] = f.read.strip
  end
end

# build RSS feed
rss = RSS::Maker.make("2.0") do |maker|
  maker.channel.author = "Bill Kelly"
  maker.channel.itunes_author = "Bill Kelly"
  maker.channel.link = url
  maker.channel.title = "Teenage Wasteland"
  maker.channel.description = "Bill Kelly's Black Hole of Rock 'N' Roll. Sundays 3-5pm (EDT) on WFMU."
  maker.channel.lastBuildDate = Time.now.to_s
  maker.channel.itunes_image = "http://i.imgur.com/nbAP0iK.jpg"

  mp3s.each_pair do |show_id, mp3|
    date = Date.parse(mp3.gsub(/(.*)\/tw/, '').gsub(/\.mp3$/, '').strip)
    maker.items.new_item do |item|
      item.title = date.strftime("%B %-d, %Y")
      item.description = "See <a href='http://wfmu.org/playlists/shows/#{show_id}'>http://wfmu.org/playlists/shows/#{show_id}</a> for the playlist."
      item.enclosure.url = mp3
      item.enclosure.length = 0
      item.enclosure.type = "audio/mpeg"
      item.guid.content = mp3
      item.guid.isPermaLink = true
      item.pubDate = date.to_s
    end
  end
end

puts rss
