# Day 6 example — the full Titanic pipeline: explore, clean, chart, model
# Run:  python analyze_titanic.py
import pandas as pd
import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt
from sklearn.tree import DecisionTreeClassifier
from sklearn.model_selection import train_test_split

# ---- 1. explore -------------------------------------------------------
df = pd.read_csv("titanic.csv")
print("shape:", df.shape)
print(df[["Name", "Sex", "Age", "Pclass", "Fare", "Survived"]].head(3))

# ---- 2. ask questions -------------------------------------------------
by_class = df.groupby("Pclass")["Survived"].mean() * 100
by_sex = df.groupby("Sex")["Survived"].mean() * 100
print("\nsurvival by class (%):\n", by_class.round(1))
print("\nsurvival by sex (%):\n", by_sex.round(1))

# ---- 3. clean ---------------------------------------------------------
print("\nmissing ages:", df["Age"].isna().sum())
df["Age"] = df["Age"].fillna(df["Age"].median())   # fill blanks, explain choice
df["SexNum"] = (df["Sex"] == "female").astype(int)  # words -> numbers for the model

# ---- 4. charts --------------------------------------------------------
for series, fname, title in [
    (by_class, "by_class.png", "Survival by ticket class (%)"),
    (by_sex, "by_sex.png", "Survival by sex (%)"),
]:
    ax = series.plot(kind="bar", color=["#0EA5E9", "#0284C7", "#F97316"],
                     figsize=(5, 3.4))
    ax.set_title(title)
    ax.set_ylim(0, 85)
    plt.tight_layout()
    plt.savefig(fname)
    plt.close()
df["Age"].plot(kind="hist", bins=20, color="#0EA5E9", figsize=(5, 3.4),
               title="Ages on board")
plt.tight_layout(); plt.savefig("ages.png"); plt.close()
print("charts saved: by_class.png, by_sex.png, ages.png")

# ---- 5. machine learning ---------------------------------------------
X = df[["Pclass", "SexNum", "Age", "Fare"]]
y = df["Survived"]
X_tr, X_te, y_tr, y_te = train_test_split(X, y, test_size=0.2, random_state=42)

model = DecisionTreeClassifier(max_depth=3, random_state=42)
model.fit(X_tr, y_tr)
acc = model.score(X_te, y_te)
print(f"\ntest accuracy: {acc:.2f}  (baseline: always guess 'died' = "
      f"{1 - y_te.mean():.2f})")
