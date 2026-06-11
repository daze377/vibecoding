# Day 7 example, step 1-2 — scrape the bookstore with Crawl4AI, save books.csv
# Run:  python scrape_books.py
# (serves site/ on localhost first, so everything runs offline;
#  in class you would point BASE at https://books.toscrape.com instead)
import asyncio
import csv
import json
import threading
from functools import partial
from http.server import HTTPServer, SimpleHTTPRequestHandler

from crawl4ai import AsyncWebCrawler, CrawlerRunConfig, CacheMode
from crawl4ai import JsonCssExtractionStrategy

BASE = "http://localhost:8731"
PAGES = [f"{BASE}/index.html", f"{BASE}/page-2.html", f"{BASE}/page-3.html"]

# the extraction schema: WHERE each fact lives on the page
schema = {
    "name": "books",
    "baseSelector": "article.product_pod",
    "fields": [
        {"name": "title", "selector": "h3 a", "type": "text"},
        {"name": "category", "selector": ".category", "type": "text"},
        {"name": "rating", "selector": ".star-rating", "type": "attribute",
         "attribute": "class"},
        {"name": "price", "selector": ".price_color", "type": "text"},
    ],
}

async def main():
    rows = []
    config = CrawlerRunConfig(
        cache_mode=CacheMode.BYPASS,
        extraction_strategy=JsonCssExtractionStrategy(schema),
    )
    async with AsyncWebCrawler() as crawler:
        for url in PAGES:                      # one page at a time...
            result = await crawler.arun(url, config=config)
            books = json.loads(result.extracted_content)
            rows.extend(books)
            print(f"{url}  ->  {len(books)} books")
            await asyncio.sleep(1)             # ...with a polite delay

    with open("books.csv", "w", newline="") as f:
        w = csv.DictWriter(f, fieldnames=["title", "category", "rating", "price"])
        w.writeheader()
        w.writerows(rows)
    print(f"saved {len(rows)} books to books.csv")

if __name__ == "__main__":
    # serve the local site quietly in the background
    handler = partial(SimpleHTTPRequestHandler, directory="site")
    server = HTTPServer(("localhost", 8731), handler)
    server.log_message = lambda *a: None
    threading.Thread(target=server.serve_forever, daemon=True).start()

    asyncio.run(main())
    server.shutdown()
