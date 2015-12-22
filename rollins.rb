#
# Generate an RSS feed for Henry Rollins' KCRW radio show
#

require 'nokogiri'
require 'open-uri'
require 'rss'
require 'json'

# scrape website for latest episode number
url = "http://www.kcrw.com/music/programs/hr"
episodes = []
page = Nokogiri::HTML(open(url))

page.css('#all_episodes a[data-player-json]').each do |a|
  json_url = a.attributes['data-player-json']
  data = JSON.parse(open(json_url).read)
  # only save the episodes with media attached
  episodes << data if (data['media'] || []).length > 0
end

# build RSS feed
rss = RSS::Maker.make("2.0") do |maker|
  maker.channel.author = "Henry Rollins"
  maker.channel.itunes_author = "Henry Rollins"
  maker.channel.link = "http://www.kcrw.com/music/shows/henry-rollins"
  maker.channel.title = "Henry Rollins - KCRW"
  maker.channel.description = "Henry Rollins hosts a great mix of all kinds from all over from all time."
  maker.channel.lastBuildDate = Time.now.to_s
  maker.channel.itunes_image = "http://www.kcrw.com/music/shows/henry-rollins/@@images/square_image"

  episodes.each do |ep|
    maker.items.new_item do |item|
      item.title = ep['title']
      item.description = ep['description']
      item.enclosure.url = ep['media'][0]['url']
      item.enclosure.length = 0
      item.enclosure.type = "audio/mpeg"
      item.guid.content = ep['uuid']
      item.guid.isPermaLink = false
      item.pubDate = ep['airdate']
    end
  end
end

puts rss