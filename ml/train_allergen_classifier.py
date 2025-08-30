import pandas as pd
import re
from pathlib import Path
from sklearn.model_selection import train_test_split
from sklearn.feature_extraction.text import TfidfVectorizer
from sklearn.multiclass import OneVsRestClassifier
from sklearn.linear_model import LogisticRegression
from sklearn.pipeline import Pipeline
from sklearn.metrics import f1_score, classification_report
import joblib

ALLERGEN_COLS = [
  "peanuts","tree_nuts","milk","eggs","fish","shellfish","wheat_gluten","soy","sesame"
]

def clean_text(s: str) -> str:
  if not isinstance(s, str): return ""
  s = re.sub(r"<[^>]+>", " ", s)        # strip HTML
  s = s.lower()
  s = re.sub(r"[^a-z\s]", " ", s)       # keep letters/spaces
  s = re.sub(r"\s+", " ", s).strip()
  return s

def load_csv(path: str):
  df = pd.read_csv(path)
  df["text"] = df["text"].fillna("").map(clean_text)
  y = df[ALLERGEN_COLS].fillna(0).astype(int).values
  return df["text"].tolist(), y

def main():
  train_x, train_y = load_csv("data/allergens/train.csv")
  val_x, val_y = load_csv("data/allergens/val.csv")

  pipe = Pipeline([
    ("tfidf", TfidfVectorizer(ngram_range=(1,2), min_df=2, max_df=0.95)),
    ("clf", OneVsRestClassifier(
      LogisticRegression(max_iter=200, n_jobs=None, solver="liblinear")
    )),
  ])

  pipe.fit(train_x, train_y)
  preds = pipe.predict(val_x)

  print("macro F1:", f1_score(val_y, preds, average="macro"))
  print(classification_report(val_y, preds, target_names=ALLERGEN_COLS))

  Path("models").mkdir(exist_ok=True)
  joblib.dump(pipe, "models/allergen_tfidf_logreg.joblib")
  print("Saved -> models/allergen_tfidf_logreg.joblib")

if __name__ == "__main__":
  main()