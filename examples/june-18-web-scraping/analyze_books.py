# Day 7 example, step 3-6 — clean, analyze, chart, and write the report
# Run:  python analyze_books.py   (after scrape_books.py)
import pandas as pd
import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt

# ---- 3. clean ---------------------------------------------------------
df = pd.read_csv("books.csv")
df["price"] = df["price"].str.replace("£", "").astype(float)
stars = {"One": 1, "Two": 2, "Three": 3, "Four": 4, "Five": 5}
# the crawler returns the class as "['star-rating', 'Three']" — pull the word out
df["rating"] = df["rating"].str.extract(r"(One|Two|Three|Four|Five)")[0].map(stars)
print(df.head(3))

# ---- 4. analyze -------------------------------------------------------
avg_price = df["price"].mean()
by_cat = df.groupby("category")["price"].mean().sort_values()
by_rating = df.groupby("rating")["price"].mean()
biggest = df["category"].value_counts()
print(f"\naverage price: £{avg_price:.2f}")
print("\navg price by category:\n", by_cat.round(2))
print("\nbiggest category:", biggest.index[0], f"({biggest.iloc[0]} books)")

# ---- 5. charts --------------------------------------------------------
by_cat.plot(kind="barh", color="#0EA5E9", figsize=(5.4, 3.4),
            title="Average price by category (£)")
plt.tight_layout(); plt.savefig("price_by_category.png"); plt.close()

df["price"].plot(kind="hist", bins=12, color="#F97316", figsize=(5.4, 3.4),
                 title="Book prices (£)")
plt.tight_layout(); plt.savefig("price_hist.png"); plt.close()

by_rating.plot(kind="bar", color="#0284C7", figsize=(5.4, 3.4),
               title="Average price by star rating (£)")
plt.tight_layout(); plt.savefig("price_by_rating.png"); plt.close()
print("charts saved: price_by_category.png, price_hist.png, price_by_rating.png")

# ---- 6. report --------------------------------------------------------
corr = df["price"].corr(df["rating"])
with open("report.md", "w") as f:
    f.write(f"""# Mini Bookstore Price Study

**Question:** what do books cost, and does a better rating mean a higher price?

**Method:** scraped {len(df)} books (3 pages) with Crawl4AI from our practice
bookstore, cleaned the data with pandas, charted it with matplotlib.

![avg price by category](price_by_category.png)
![price histogram](price_hist.png)
![price by rating](price_by_rating.png)

## Findings
1. The average book costs **£{avg_price:.2f}**.
2. Price vs rating correlation is **{corr:.2f}** — better-rated books are
   NOT more expensive.
3. The biggest category is **{biggest.index[0]}** with {biggest.iloc[0]} books.

*Data source: local practice site (structure of books.toscrape.com).*
""")
print("report.md written")
