require("dotenv").config()

const puppeteer = require("puppeteer")
const { Feed } = require("feed")
const fs = require("fs")

const RSS_FILE_PATH = process.env.ROLLINS_RSS_FILE_PATH || "rollins.xml"

const log = (message) => {
  if (process.env.VERBOSE) console.log(`[${new Date().toISOString()}] ${message}`)
}

async function main() {
  const browser = await puppeteer.launch({ headless: true })
  const page = await browser.newPage()
  await page.setViewport({ width: 1920, height: 1080 })
  await page.goto("https://www.kcrw.com/host/henry-rollins")

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

  for (let i = 0; i < episodes.length; i++) {
    // sleep for 1 second
    await new Promise(resolve => setTimeout(resolve, 1000))

    const episode = episodes[i]
    const page = await browser.newPage()

    log(`Fetching ${episode.title} (${episode.url})...`)
    await page.goto(episode.url)

    const details = await page.evaluate(() => {
      let currentEpisode

      const payload = window.__next_f.map(f => f[1])
        .filter(s => s && s.match(/ondemand(.*)\.mp3/))[0]
        .replace(/^\d\d\:/, '')

      try {
        const data = JSON.parse(payload)[3].children[0][3]
        currentEpisode = data.currentEpisode
      } catch (error) {
        currentEpisode = null
      }

      return {
        mp3: currentEpisode ? currentEpisode.audioMedia.mediaUrl : null,
        description: document.querySelector('section[aria-label="Article content"]').innerText,
      }
    })

    episodes[i] = { ...episode, ...details }
  }

  await browser.close()

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
