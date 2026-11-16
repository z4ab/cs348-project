from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
OUT = ROOT / "data" / "production"

OUT.mkdir(parents=True, exist_ok=True)

print("Production folder ready:", OUT)
