from fastapi import HTTPException
from fastapi import FastAPI
from pydantic import BaseModel
import joblib
import re
import numpy as np

MODEL_PATH = "models/allergen_tfidf_logreg.joblib"
ALLERGEN_COLS = [
  "peanuts","tree_nuts","milk","eggs","fish","shellfish","wheat_gluten","soy","sesame"
]

app = FastAPI(title="SmartDiet ML API")

class PredictRequest(BaseModel):
  text: str

def clean_text(s: str) -> str:
  s = re.sub(r"<[^>]+>", " ", s or "")
  s = s.lower()
  s = re.sub(r"[^a-z\s]", " ", s)
  s = re.sub(r"\s+", " ", s).strip()
  return s

# Load model once at startup
pipe = joblib.load(MODEL_PATH)

@app.post("/predict_allergens")
def predict_allergens(req: PredictRequest):
  try:
    txt = clean_text(req.text)

    # Use the full pipeline so TF-IDF runs
    if hasattr(pipe, "predict_proba"):
      scores = pipe.predict_proba([txt])[0]  # shape: (n_labels,)
      thr = 0.2
      labels = {ALLERGEN_COLS[i]: int(scores[i] >= thr) for i in range(len(ALLERGEN_COLS))}
      return {
        "scores": {ALLERGEN_COLS[i]: float(scores[i]) for i in range(len(ALLERGEN_COLS))},
        "labels": labels,
        "threshold": thr
      }

    # Fallback: decision_function → sigmoid to get 0..1
    if hasattr(pipe, "decision_function"):
      z = pipe.decision_function([txt])[0]
      scores = 1 / (1 + np.exp(-z))
      thr = 0.2
      labels = {ALLERGEN_COLS[i]: int(scores[i] >= thr) for i in range(len(ALLERGEN_COLS))}
      return {
        "scores": {ALLERGEN_COLS[i]: float(scores[i]) for i in range(len(ALLERGEN_COLS))},
        "labels": labels,
        "threshold": thr
      }

    # Last resort: binary predict only
    pred = pipe.predict([txt])[0]
    return {"labels": {ALLERGEN_COLS[i]: int(pred[i]) for i in range(len(ALLERGEN_COLS))}}

  except Exception as e:
    raise HTTPException(status_code=500, detail=str(e))