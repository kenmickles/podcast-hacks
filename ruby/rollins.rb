#
# Generate an RSS feed for Henry Rollins' KCRW radio show
#

require 'nokogiri'
require 'open-uri'
require 'rss'
require 'json'
require 'sanitize'

def fetch_description(url)
  page = Nokogiri::HTML(URI.open(url))
  description = page.css('.content[itemprop=articleBody]')[0].inner_html

  Sanitize.fragment(description,
    elements: %w(b i em ul li p br a strong),
    attributes: { 'a' => ['href'] }
  ).strip
end

# fetch episode data from JSON API
episodes = JSON.parse(URI.open("https://www.kcrw.com/music/shows/henry-rollins/episodes.json").read)

# remove episodes without media attached
episodes.reject! { |e| (e['media'] || []).length < 1 }

# build RSS feed
rss = RSS::Maker.make("2.0") do |maker|
  maker.channel.author = "Henry Rollins"
  maker.channel.itunes_author = "Henry Rollins"
  maker.channel.link = "https://www.kcrw.com/host/henry-rollins"
  maker.channel.title = "Henry Rollins - KCRW"
  maker.channel.description = "Henry Rollins hosts a great mix of all kinds from all over from all time."
  maker.channel.lastBuildDate = Time.now.to_s
  maker.channel.itunes_image = "https://images.ctfassets.net/2658fe8gbo8o/5883da63a527de85856a5c05e27331b8-photo-asset/cea6afe85802c22262210b1ab3fa0f7a/rect.jpg?w=640&h=640&fm=webp&q=80&fit=fill&f=top_right"

  episodes.each do |ep|
    # fetch full description from episode page
    description = fetch_description(ep['url'])
    sleep 1.0

    maker.items.new_item do |item|
      item.title = ep['title']
      item.description = description
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
