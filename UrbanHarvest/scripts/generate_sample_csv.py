#!/usr/bin/env python3
"""Generate UrbanHarvest/Resources/sample_training_data.csv.

Column names and allowed values come from UrbanHarvest/Models/FeatureSchema.swift
(the single source of truth). The formula mirrors HarvestFormula in
UrbanHarvest/Services/ModelLoader/MockYieldPredictor.swift, plus noise.

The unit test FeatureSchemaTests.testBundledCSVMatchesSchema fails if the CSV
header or any value drifts from FeatureSchema.swift.

Usage:  python3 scripts/generate_sample_csv.py [--rows 200] [--seed 7]
"""

import argparse
import csv
import math
import random
from pathlib import Path

# Keep in sync with FeatureSchema.swift
COLUMNS = [
    "fruit_type", "field_area_m2", "rainfall", "temperature", "sky",
    "irrigation_level", "harvest_timing",
    "defect_rate", "yield_kg_per_m2",
]
FRUITS = ["apple", "orange", "mango", "tomato", "banana", "strawberry"]
RAINFALL = ["low", "medium", "high"]
TEMPERATURE = ["cool", "normal", "hot"]
SKY = ["sunny", "cloudy", "rainy"]
IRRIGATION = ["low", "medium", "high"]
TIMING = ["early", "on_time", "late"]
AREA_RANGE = (10, 1_000_000)


def defect_rate(r):
    rate = {"apple": 8, "orange": 9, "mango": 11, "tomato": 12, "banana": 10, "strawberry": 15}[r["fruit_type"]]
    rate += {"low": 0, "medium": 2, "high": 6}[r["rainfall"]]
    rate += {"cool": -1, "normal": 0, "hot": 4}[r["temperature"]]
    rate += {"sunny": 0, "cloudy": 1, "rainy": 4}[r["sky"]]
    if r["irrigation_level"] == "low":
        rate += 4 if r["rainfall"] == "low" else 2
    elif r["irrigation_level"] == "high":
        rate += 6 if r["rainfall"] == "high" else 1
    if r["harvest_timing"] == "early":
        rate -= 2
    elif r["harvest_timing"] == "late":
        rate += 7
        if r["temperature"] == "hot":
            rate += 3
        if r["sky"] == "rainy":
            rate += 2
    area = max(r["field_area_m2"], 1)
    rate += min(max(1.5 * math.log10(area / 1000), -1.5), 4.5)
    return min(max(rate, 1), 60)


def yield_per_area(r, rate):
    v = {"apple": 3.0, "orange": 2.5, "mango": 2.0, "tomato": 6.0, "banana": 4.0, "strawberry": 1.5}[r["fruit_type"]]
    if r["rainfall"] == "low":
        v *= 0.75 if r["irrigation_level"] == "low" else 0.9
    elif r["rainfall"] == "high":
        v *= 0.95
    v *= {"cool": 0.9, "normal": 1.0, "hot": 0.88}[r["temperature"]]
    v *= {"sunny": 1.05, "cloudy": 1.0, "rainy": 0.92}[r["sky"]]
    if r["irrigation_level"] == "low":
        v *= 0.85
    elif r["irrigation_level"] == "high":
        v *= 0.95 if r["rainfall"] == "high" else 1.05
    v *= {"early": 0.88, "on_time": 1.0, "late": 0.93}[r["harvest_timing"]]
    v *= 1 - rate / 100 * 0.5
    return v


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--rows", type=int, default=200)
    parser.add_argument("--seed", type=int, default=7)
    parser.add_argument("--out", default=str(Path(__file__).resolve().parent.parent / "UrbanHarvest" / "Resources" / "sample_training_data.csv"))
    args = parser.parse_args()

    rng = random.Random(args.seed)
    rows = []
    for _ in range(args.rows):
        r = {
            "fruit_type": rng.choice(FRUITS),
            # Log-uniform between 100 m² and 5 ha, rounded to 10 m².
            "field_area_m2": round(10 ** rng.uniform(2, math.log10(50_000)), -1),
            "rainfall": rng.choice(RAINFALL),
            "temperature": rng.choice(TEMPERATURE),
            "sky": rng.choice(SKY),
            "irrigation_level": rng.choice(IRRIGATION),
            "harvest_timing": rng.choice(TIMING),
        }
        assert AREA_RANGE[0] <= r["field_area_m2"] <= AREA_RANGE[1]
        rate = min(max(defect_rate(r) + rng.gauss(0, 1.5), 0.5), 80)
        r["defect_rate"] = round(rate, 1)
        r["yield_kg_per_m2"] = round(max(yield_per_area(r, rate) * rng.gauss(1, 0.05), 0.05), 2)
        rows.append(r)

    with open(args.out, "w", newline="", encoding="utf-8") as f:
        writer = csv.DictWriter(f, fieldnames=COLUMNS, lineterminator="\n")
        writer.writeheader()
        for r in rows:
            r["field_area_m2"] = int(r["field_area_m2"])
            writer.writerow(r)
    print(f"Wrote {len(rows)} rows to {args.out}")


if __name__ == "__main__":
    main()
