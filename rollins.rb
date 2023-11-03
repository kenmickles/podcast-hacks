#
# Generate an RSS feed for Henry Rollins' KCRW radio show
#

require 'nokogiri'
require 'open-uri'
require 'rss'
require 'json'
require 'sanitize'

def fetch_description(data)
  page = Nokogiri::HTML(URI.open(data['url']))
  description = page.css('.content[itemprop=articleBody]')[0].inner_html
	
	Sanitize.fragment(description, 
		elements: %w(b i em ul li p br a strong),
		attributes: { 'a' => ['href'] }
	).strip
end

# scrape website for available episodes
json_urls = []
page = Nokogiri::HTML(URI.open("https://www.kcrw.com/music/shows/henry-rollins"))

page.css('[data-player-json*=rollins]').each do |a|
  json_urls << a.attributes['data-player-json'].value
end

json_urls.uniq!.sort!.reverse!

# fetch episode data from JSON API
episodes = []

json_urls.each do |json_url|
  data = JSON.parse(URI.open(json_url).read)

  # only save the episodes with media attached
  if (data['media'] || []).length > 0
    data['description'] = fetch_description(data)
    episodes << data
  end

  sleep 1.0
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
