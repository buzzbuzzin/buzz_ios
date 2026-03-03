// Supabase Edge Function to fetch drone news from multiple sources
// Sources: FAA Press Releases (RSS), Transport Canada Drone Safety (HTML), DroneLIFE (RSS)

import { serve } from "https://deno.land/std@0.168.0/http/server.ts"
import { XMLParser } from "https://esm.sh/fast-xml-parser@4.3.2"

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
}

// --- Interfaces ---

interface FetchDroneNewsRequest {
  source: "faa" | "transport_canada" | "global"
}

interface NewsArticle {
  id: string
  title: string
  summary: string
  url: string
  publishedDate: string
  author: string
  source: string
  category: string
  imageUrl: string | null
}

// --- Utility Functions ---

function stripHtml(html: string): string {
  return html
    .replace(/<[^>]*>/g, "")
    .replace(/&amp;/g, "&")
    .replace(/&lt;/g, "<")
    .replace(/&gt;/g, ">")
    .replace(/&quot;/g, '"')
    .replace(/&#039;/g, "'")
    .replace(/&rsquo;/g, "'")
    .replace(/&lsquo;/g, "'")
    .replace(/&rdquo;/g, "\u201D")
    .replace(/&ldquo;/g, "\u201C")
    .replace(/&mdash;/g, "\u2014")
    .replace(/&ndash;/g, "\u2013")
    .replace(/&nbsp;/g, " ")
    .replace(/&#8217;/g, "'")
    .replace(/&#8220;/g, "\u201C")
    .replace(/&#8221;/g, "\u201D")
    .replace(/\s+/g, " ")
    .trim()
}

async function generateId(input: string): Promise<string> {
  const encoder = new TextEncoder()
  const data = encoder.encode(input)
  const hashBuffer = await crypto.subtle.digest("SHA-256", data)
  const hashArray = Array.from(new Uint8Array(hashBuffer))
  return hashArray.map(b => b.toString(16).padStart(2, "0")).join("").substring(0, 16)
}

function parseDate(dateStr: string): string {
  try {
    const d = new Date(dateStr)
    if (!isNaN(d.getTime())) {
      return d.toISOString()
    }
  } catch {
    // Fall through
  }
  return new Date().toISOString()
}

function extractImageFromHtml(html: string): string | null {
  const imgMatch = html.match(/<img[^>]+src=["']([^"']+)["']/)
  if (imgMatch && imgMatch[1]) {
    const src = imgMatch[1]
    // Skip tiny tracking pixels and icons
    if (src.includes("gravatar") || src.includes("pixel") || src.includes("1x1")) {
      return null
    }
    return src
  }
  return null
}

function isValidImageUrl(url: string): boolean {
  if (!url || url.length < 10) return false
  // Skip tiny icons, SVGs, tracking pixels, data URIs
  if (url.includes(".svg") || url.includes("data:") || url.includes("1x1") ||
      url.includes("pixel") || url.includes("gravatar") || url.includes("favicon") ||
      url.includes("logo") || url.includes("icon") || url.includes("badge") ||
      url.includes("spinner") || url.includes("loading") || url.includes("flag")) {
    return false
  }
  return true
}

/**
 * Fetch an article's web page and extract the first meaningful image.
 * Priority: og:image > JSON-LD image > first content <img>
 */
async function extractImageFromPage(url: string): Promise<string | null> {
  try {
    const controller = new AbortController()
    const timeoutId = setTimeout(() => controller.abort(), 5000)

    const response = await fetch(url, {
      headers: {
        "User-Agent": "Buzz/1.0",
        "Accept": "text/html",
      },
      signal: controller.signal,
    })
    clearTimeout(timeoutId)

    if (!response.ok) return null

    const html = await response.text()

    // 1. Try og:image meta tag
    const ogImageMatch = html.match(/<meta\s+(?:property|name)=["']og:image["']\s+content=["']([^"']+)["']/i)
      || html.match(/<meta\s+content=["']([^"']+)["']\s+(?:property|name)=["']og:image["']/i)
    if (ogImageMatch && ogImageMatch[1] && isValidImageUrl(ogImageMatch[1])) {
      return ogImageMatch[1]
    }

    // 2. Try twitter:image meta tag
    const twitterImageMatch = html.match(/<meta\s+(?:property|name)=["']twitter:image["']\s+content=["']([^"']+)["']/i)
      || html.match(/<meta\s+content=["']([^"']+)["']\s+(?:property|name)=["']twitter:image["']/i)
    if (twitterImageMatch && twitterImageMatch[1] && isValidImageUrl(twitterImageMatch[1])) {
      return twitterImageMatch[1]
    }

    // 3. Try JSON-LD structured data
    const jsonLdMatch = html.match(/<script\s+type=["']application\/ld\+json["'][^>]*>([\s\S]*?)<\/script>/i)
    if (jsonLdMatch && jsonLdMatch[1]) {
      try {
        const jsonLd = JSON.parse(jsonLdMatch[1])
        const imageData = jsonLd.image || jsonLd.thumbnailUrl
        if (imageData) {
          const imageUrl = typeof imageData === "string" ? imageData
            : (imageData.url || imageData[0]?.url || (Array.isArray(imageData) ? imageData[0] : null))
          if (imageUrl && typeof imageUrl === "string" && isValidImageUrl(imageUrl)) {
            return imageUrl
          }
        }
      } catch {
        // Invalid JSON-LD, skip
      }
    }

    // 4. Fallback: first meaningful <img> in the article body
    const imgRegex = /<img[^>]+src=["']([^"']+)["'][^>]*>/gi
    let imgMatch
    while ((imgMatch = imgRegex.exec(html)) !== null) {
      const src = imgMatch[1]
      if (isValidImageUrl(src) && (src.includes(".jpg") || src.includes(".jpeg") ||
          src.includes(".png") || src.includes(".webp") || src.includes("wp-content") ||
          src.includes("uploads") || src.includes("images"))) {
        return src
      }
    }

    return null
  } catch {
    // Timeout or network error — silently return null
    return null
  }
}

/**
 * Enrich articles with images by fetching each article's page in parallel.
 * Only fetches for articles that don't already have an imageUrl.
 */
async function enrichArticlesWithImages(articles: NewsArticle[]): Promise<NewsArticle[]> {
  const results = await Promise.allSettled(
    articles.map(async (article) => {
      if (article.imageUrl) return article
      const imageUrl = await extractImageFromPage(article.url)
      return { ...article, imageUrl }
    })
  )

  return results.map((result, index) => {
    if (result.status === "fulfilled") {
      return result.value
    }
    return articles[index] // Keep original on failure
  })
}

// --- FAA News ---

async function fetchFAANews(): Promise<NewsArticle[]> {
  const rssUrl = "https://www.faa.gov/newsroom/press_releases/rss"
  const response = await fetch(rssUrl, {
    headers: {
      "User-Agent": "Buzz/1.0",
      "Accept": "application/xml, text/xml, application/rss+xml",
    },
  })

  if (!response.ok) {
    throw new Error(`FAA RSS fetch failed: ${response.status}`)
  }

  const xmlText = await response.text()
  const parser = new XMLParser({
    ignoreAttributes: false,
    attributeNamePrefix: "@_",
  })
  const parsed = parser.parse(xmlText)

  const channel = parsed?.rss?.channel
  if (!channel) {
    throw new Error("Invalid FAA RSS structure")
  }

  const items = Array.isArray(channel.item) ? channel.item : channel.item ? [channel.item] : []

  const articles: NewsArticle[] = []
  for (const item of items.slice(0, 20)) {
    const title = typeof item.title === "string" ? item.title.trim() : ""
    const link = typeof item.link === "string" ? item.link.trim() : ""
    const description = typeof item.description === "string" ? stripHtml(item.description) : ""
    const pubDate = typeof item.pubDate === "string" ? item.pubDate : ""

    if (!title || !link) continue

    const id = await generateId(link || title)
    articles.push({
      id,
      title,
      summary: description || title,
      url: link,
      publishedDate: parseDate(pubDate),
      author: "FAA",
      source: "FAA",
      category: "Regulations",
      imageUrl: null,
    })
  }

  return articles
}

// --- Transport Canada News ---

async function fetchTransportCanadaNews(): Promise<NewsArticle[]> {
  const articles: NewsArticle[] = []

  // Fetch main drone safety page
  const pageUrl = "https://tc.canada.ca/en/aviation/drone-safety"
  const response = await fetch(pageUrl, {
    headers: {
      "User-Agent": "Buzz/1.0",
      "Accept": "text/html",
    },
  })

  if (!response.ok) {
    throw new Error(`Transport Canada fetch failed: ${response.status}`)
  }

  const htmlText = await response.text()

  // Extract links from "Most Requested" section
  const mostRequestedMatch = htmlText.match(/most\s*requested[\s\S]*?<ul[^>]*>([\s\S]*?)<\/ul>/i)
  if (mostRequestedMatch) {
    const listHtml = mostRequestedMatch[1]
    const linkRegex = /<a\s+href="([^"]*)"[^>]*>([^<]+)<\/a>/gi
    let match
    while ((match = linkRegex.exec(listHtml)) !== null) {
      const href = match[1].trim()
      const title = match[2].trim()
      if (!href || !title) continue

      const fullUrl = href.startsWith("http") ? href : `https://tc.canada.ca${href}`
      const id = await generateId(fullUrl)

      articles.push({
        id,
        title,
        summary: title,
        url: fullUrl,
        publishedDate: new Date().toISOString(),
        author: "Transport Canada",
        source: "Transport Canada",
        category: "Regulations",
        imageUrl: null,
      })
    }
  }

  // Extract "Services and Information" section items
  const servicesMatch = htmlText.match(/services\s+and\s+information[\s\S]*?(<div[\s\S]*?)(?:<section|<footer|$)/i)
  if (servicesMatch) {
    const servicesHtml = servicesMatch[1]
    const svcRegex = /<h[23][^>]*>\s*<a\s+href="([^"]*)"[^>]*>([^<]+)<\/a>\s*<\/h[23]>\s*<p[^>]*>([^<]+)<\/p>/gi
    let svcMatch
    while ((svcMatch = svcRegex.exec(servicesHtml)) !== null) {
      const href = svcMatch[1].trim()
      const title = svcMatch[2].trim()
      const desc = svcMatch[3].trim()
      if (!href || !title) continue

      const fullUrl = href.startsWith("http") ? href : `https://tc.canada.ca${href}`
      const id = await generateId(fullUrl)

      if (articles.some(a => a.url === fullUrl)) continue

      articles.push({
        id,
        title,
        summary: desc || title,
        url: fullUrl,
        publishedDate: new Date().toISOString(),
        author: "Transport Canada",
        source: "Transport Canada",
        category: "Safety",
        imageUrl: null,
      })
    }
  }

  // Also get Drone Zone newsletter links
  const droneZoneRegex = /<a\s+href="(\/en\/aviation\/drone-safety\/drone-zone\/[^"]*)"[^>]*>([^<]+)<\/a>/gi
  let dzMatch
  while ((dzMatch = droneZoneRegex.exec(htmlText)) !== null) {
    const href = dzMatch[1].trim()
    const title = dzMatch[2].trim()
    if (!href || !title) continue

    const fullUrl = `https://tc.canada.ca${href}`
    const id = await generateId(fullUrl)

    if (articles.some(a => a.url === fullUrl)) continue

    articles.push({
      id,
      title,
      summary: `Drone Zone: ${title}`,
      url: fullUrl,
      publishedDate: new Date().toISOString(),
      author: "Transport Canada",
      source: "Transport Canada",
      category: "Newsletter",
      imageUrl: null,
    })
  }

  return articles.slice(0, 20)
}

// --- Global Drone News (DroneLIFE) ---

async function fetchGlobalNews(): Promise<NewsArticle[]> {
  const rssUrl = "https://dronelife.com/feed/"
  const response = await fetch(rssUrl, {
    headers: {
      "User-Agent": "Buzz/1.0",
      "Accept": "application/xml, text/xml, application/rss+xml",
    },
  })

  if (!response.ok) {
    throw new Error(`DroneLIFE RSS fetch failed: ${response.status}`)
  }

  const xmlText = await response.text()
  const parser = new XMLParser({
    ignoreAttributes: false,
    attributeNamePrefix: "@_",
  })
  const parsed = parser.parse(xmlText)

  const channel = parsed?.rss?.channel
  if (!channel) {
    throw new Error("Invalid DroneLIFE RSS structure")
  }

  const items = Array.isArray(channel.item) ? channel.item : channel.item ? [channel.item] : []

  const articles: NewsArticle[] = []
  for (const item of items.slice(0, 20)) {
    const title = typeof item.title === "string" ? item.title.trim() : ""
    const link = typeof item.link === "string" ? item.link.trim() : ""
    const descriptionRaw = typeof item.description === "string" ? item.description : ""
    const description = stripHtml(descriptionRaw)
    const pubDate = typeof item.pubDate === "string" ? item.pubDate : ""
    const creator = item["dc:creator"] || "DroneLIFE"

    // Extract category - can be string or array
    let category = "Industry"
    if (item.category) {
      if (Array.isArray(item.category)) {
        category = typeof item.category[0] === "string" ? item.category[0] : "Industry"
      } else if (typeof item.category === "string") {
        category = item.category
      }
    }

    // Try to extract image from description HTML
    const imageUrl = extractImageFromHtml(descriptionRaw)

    if (!title || !link) continue

    const id = await generateId(link || title)
    articles.push({
      id,
      title,
      summary: description || title,
      url: link,
      publishedDate: parseDate(pubDate),
      author: typeof creator === "string" ? creator : "DroneLIFE",
      source: "DroneLIFE",
      category,
      imageUrl,
    })
  }

  return articles
}

// --- Main Handler ---

serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders })
  }

  try {
    const { source }: FetchDroneNewsRequest = await req.json()

    if (!["faa", "transport_canada", "global"].includes(source)) {
      return new Response(
        JSON.stringify({
          error: "Invalid source. Must be 'faa', 'transport_canada', or 'global'.",
          articles: [],
          source: source || "",
          fetchedAt: new Date().toISOString(),
        }),
        {
          status: 400,
          headers: { ...corsHeaders, "Content-Type": "application/json" },
        }
      )
    }

    let articles: NewsArticle[] = []

    switch (source) {
      case "faa":
        articles = await fetchFAANews()
        break
      case "transport_canada":
        articles = await fetchTransportCanadaNews()
        break
      case "global":
        articles = await fetchGlobalNews()
        break
    }

    // Enrich articles with images from their web pages
    articles = await enrichArticlesWithImages(articles)

    return new Response(
      JSON.stringify({
        articles,
        source,
        fetchedAt: new Date().toISOString(),
      }),
      {
        headers: { ...corsHeaders, "Content-Type": "application/json" },
        status: 200,
      }
    )
  } catch (error: any) {
    console.error("Error fetching drone news:", error)

    return new Response(
      JSON.stringify({
        error: error.message,
        articles: [],
        source: "",
        fetchedAt: new Date().toISOString(),
      }),
      {
        status: 500,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      }
    )
  }
})
