# Day 7 example, step 0 — build a tiny local bookstore to practice on.
# Same HTML structure as books.toscrape.com, but it runs offline.
# Run:  python make_site.py   ->  site/ (3 pages, 60 books)
import os
import random

random.seed(42)
ADJ = ["Silent", "Golden", "Lost", "Hidden", "Brave", "Curious", "Midnight",
       "Electric", "Paper", "Winter", "Glass", "Iron", "Lucky", "Secret", "Wild"]
NOUN = ["Garden", "River", "Code", "Dragon", "Library", "Planet", "Compass",
        "Symphony", "Robot", "Island", "Mirror", "Forest", "Rocket", "Clock"]
CATS = ["Fiction", "Science", "Mystery", "Fantasy", "History", "Poetry"]
STARS = ["One", "Two", "Three", "Four", "Five"]

BOOK = '''    <article class="product_pod">
      <h3><a href="#">{title}</a></h3>
      <p class="category">{cat}</p>
      <p class="star-rating {stars}">{stars} star</p>
      <p class="price_color">£{price}</p>
    </article>'''

PAGE = '''<!DOCTYPE html>
<html><head><meta charset="utf-8"><title>Mini Bookstore — page {n}</title></head>
<body>
  <h1>Mini Bookstore</h1>
  <p>A practice site for the Vibe Coding class. We love being scraped!</p>
  <section class="books">
{books}
  </section>
  <nav>{prev} {next}</nav>
</body></html>'''

os.makedirs("site", exist_ok=True)
titles = random.sample([f"The {a} {n}" for a in ADJ for n in NOUN], 60)
for page in range(1, 4):
    books = []
    for i in range(20):
        t = titles[(page - 1) * 20 + i]
        books.append(BOOK.format(
            title=t, cat=random.choice(CATS),
            stars=random.choice(STARS),
            price=f"{random.uniform(8, 60):.2f}"))
    name = "index.html" if page == 1 else f"page-{page}.html"
    prev = f'<a href="{"index" if page == 2 else f"page-{page-1}"}.html">prev</a>' if page > 1 else ""
    nxt = f'<a href="page-{page+1}.html">next</a>' if page < 3 else ""
    with open(f"site/{name}", "w") as f:
        f.write(PAGE.format(n=page, books="\n".join(books), prev=prev, next=nxt))
print("site/ built: index.html, page-2.html, page-3.html (60 books)")
