# Examples — Week 2 (all really run)

Working, tested examples for the Week 2 slides. Every script here was actually
executed; the output files (docx, xlsx, pdf, csv, png, md) are the real results.

## june-15-word-excel-latex (Day 5)
| Script | Output |
|---|---|
| `make_report.py` | `report.docx` — Word report with heading, table, paragraphs |
| `make_certificates.py` | `names.xlsx` + `certificates/` — 20 certificates from a name list |
| `make_grades.py` | `grades.xlsx` — gradebook with live AVERAGE formulas + highlights |
| `homework.tex` | `homework.pdf` — math homework built with `pdflatex` |

## june-16-data-analysis-ml (Day 6)
| Script | Output |
|---|---|
| `analyze_titanic.py` | survival stats, `by_class.png`, `by_sex.png`, `ages.png`, decision-tree accuracy **0.80** (baseline 0.59) |

Data: `titanic.csv` (891 passengers, datasciencedojo/datasets).

## june-18-web-scraping (Day 7)
| Script | Output |
|---|---|
| `make_site.py` | `site/` — a 3-page, 60-book practice bookstore (offline copy of the books.toscrape.com idea) |
| `scrape_books.py` | `books.csv` — scraped with **Crawl4AI** (CSS schema, 1 s polite delay) |
| `analyze_books.py` | 3 charts + `report.md` with findings |

In class, point `BASE` in `scrape_books.py` at `https://books.toscrape.com`
to scrape the real practice site (1,000 books, 50 pages).

Setup used: `pip install python-docx openpyxl pandas scikit-learn matplotlib crawl4ai`
then `crawl4ai-setup`.
