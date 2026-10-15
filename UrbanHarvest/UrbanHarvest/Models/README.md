# Models — drop your Create ML files here

The app runs without anything in this folder (it uses **demo mode**). To use
your own models, put these two files here:

| File                    | Create ML template          | What it does                                  |
|-------------------------|-----------------------------|-----------------------------------------------|
| `FruitDetector.mlmodel` | **Object Detection**        | Finds fruit in the camera image, with a label |
| `YieldAdvisor.mlmodel`  | **Tabular Regression**      | Predicts defect rate *or* yield               |

Then run, from the repository root:

```bash
xcodegen generate
```

XcodeGen only picks up files that exist when it runs, so re-generate after
adding or renaming a model. Xcode compiles each `.mlmodel` into a
`.mlmodelc` folder inside the app; the app loads it **by name at runtime**
(`MLModel(contentsOf:)`). The app does not use Xcode's generated model
classes, so it builds whether or not the files are here.

`.mlpackage` files work too.

## Different file names?

Edit `models.detector` / `models.advisor` in `Resources/ClassMapping.json`
(name without extension).

## FruitDetector: labels

Your detector can use any labels (`fresh` / `rotten`, `fresh_apple` /
`rotten_apple`, …). List them under `labels.good` and `labels.defect` in
`Resources/ClassMapping.json`. Unlisted labels fall back to keyword matching,
then to `unknownLabel.policy`.

## YieldAdvisor: columns

Train on `Resources/sample_training_data.csv`, or on your own data with
**exactly the same column names and values**. The columns are defined in
`Models/FeatureSchema.swift`:

| Column             | Type   | Values                                   |
|--------------------|--------|------------------------------------------|
| `fruit_type`       | text   | apple, orange, mango, tomato, banana, strawberry |
| `field_area_m2`    | number | 10 – 1,000,000                           |
| `rainfall`         | text   | low, medium, high                        |
| `temperature`      | text   | cool, normal, hot                        |
| `sky`              | text   | sunny, cloudy, rainy                     |
| `irrigation_level` | text   | low, medium, high *(controllable)*       |
| `harvest_timing`   | text   | early, on_time, late *(controllable)*    |
| `defect_rate`      | target | percent, 0–100 (lower is better)         |
| `yield_kg_per_m2`  | target | kg per m² (higher is better)             |

In Create ML choose **one** target (`defect_rate` or `yield_kg_per_m2`) and
**leave the other target column out of the features**. The app reads the
target from the model's output name (or from `advisor.target` in
`ClassMapping.json`).
