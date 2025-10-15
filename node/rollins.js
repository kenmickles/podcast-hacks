require("dotenv").config()

const puppeteer = require("puppeteer")
const { Feed } = require("feed")
const fs = require("fs")
const cheerio = require("cheerio")
const createDOMPurify = require('dompurify')
const { JSDOM } = require('jsdom')

const RSS_FILE_PATH = process.env.ROLLINS_RSS_FILE_PATH || "rollins.xml"

const log = (message) => {
  if (process.env.VERBOSE) console.log(`[${new Date().toISOString()}] ${message}`)
}

const sanitizeHTML = (html) => {
  const window = new JSDOM('').window
  const DOMPurify = createDOMPurify(window)
  return DOMPurify.sanitize(html, { ALLOWED_TAGS: ['b', 'i', 'em', 'ul' ,'li', 'p', 'br', 'a', 'strong'] })
}


async function main() {
  const browser = await puppeteer.launch({ headless: true })
  const page = await browser.newPage()
  await page.setViewport({ width: 1920, height: 1080 })
  await page.goto("https://www.kcrw.com/host/henry-rollins")
  await page.waitForNetworkIdle()

  const episodes = await page.evaluate(() => {
    const episodes = []
    document.querySelectorAll('article > a').forEach(el => {
      episodes.push({
        title: el.querySelector('h3').textContent,
        url: el.href,
        date: el.querySelector('time.text-nowrap').getAttribute('datetime'),
        duration_in_seconds: parseFloat(el.querySelector('time:not(.text-nowrap)').getAttribute('datetime'))
      })
    })
    return episodes
  })

  await browser.close()

  for (let i = 0; i < episodes.length; i++) {
    // sleep for 1 second
    await new Promise(resolve => setTimeout(resolve, 1000))

    const episode = episodes[i]

    log(`Fetching ${episode.title} (${episode.url})...`)
    const response = await fetch(episode.url)
    const html = await response.text()

    const matches = html.match(/https:\/\/ondemand-media\.kcrw\.com\/(.*)\.mp3/gi)

    if (matches.length > 0) {
      episodes[i].mp3 = matches[0].replace(/(.*)"/g, '')

      const $ = cheerio.load(html)
      const description = $('section[aria-label="Article content"]').html()
      episodes[i].description = sanitizeHTML(description)
    }
  }

  const feed = new Feed({
    title: "Henry Rollins - KCRW",
    description: "Henry Rollins hosts a great mix of all kinds from all over from all time.",
    link: "https://www.kcrw.com/host/henry-rollins",
    language: "en",
    image: "https://images.ctfassets.net/2658fe8gbo8o/5883da63a527de85856a5c05e27331b8-photo-asset/cea6afe85802c22262210b1ab3fa0f7a/rect.jpg?w=640&h=640&fm=webp&q=80&fit=fill&f=top_right",
  })

  episodes.forEach(episode => {
    if (!episode.mp3) return

    feed.addItem({
      title: episode.title,
      description: episode.description,
      link: episode.url,
      enclosure: {
        url: episode.mp3,
        length: 0,
        type: "audio/mpeg",
      },
      guid: episode.mp3,
      isPermaLink: true,
      date: new Date(episode.date),
    })
  })

  fs.writeFileSync(RSS_FILE_PATH, feed.rss2())
}

main().catch(console.error)
