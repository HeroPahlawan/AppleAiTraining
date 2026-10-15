# UrbanHarvest

A SwiftUI prototype for farmers during harvest. The phone camera sorts fruit
into **good** and **defect**, counts each fruit once, and saves the counts to
a dashboard. An advisor suggests what to change, and every result can be read
aloud. The app UI is in Indonesian.

- iOS 17+, SwiftUI, SwiftData, Swift Charts, Vision, Core ML, AVFoundation
- No third-party dependencies, no networking, no ML training code
- **Runs without any model files** (demo mode). Your Create ML models drop in
  with no code changes.

## 1. Generate the project

You need Xcode 15 or newer and [XcodeGen](https://github.com/yonaskolb/XcodeGen).

```bash
brew install xcodegen
xcodegen generate
open UrbanHarvest.xcodeproj
```

`UrbanHarvest.xcodeproj` is generated and git-ignored. Run `xcodegen generate`
again after adding, removing or renaming files.

To run on a device, set your team under *Signing & Capabilities*. In the
simulator there is no camera, so the Deteksi tab shows a simulated feed (in
demo mode) and a **Foto uji** mode that runs detection on a photo or the
bundled sample image.

## 2. Add your models

Put these two files in `UrbanHarvest/Models/`, then run `xcodegen generate`:

| File                    | Create ML template | Used for                  |
|-------------------------|--------------------|---------------------------|
| `FruitDetector.mlmodel` | Object Detection   | Live detection & counting |
| `YieldAdvisor.mlmodel`  | Tabular Regression | Advisor & what-if         |

Xcode compiles each model to `<name>.mlmodelc` inside the app. At launch,
`ModelLoader` loads it by name with `MLModel(contentsOf:)`. If a model is
missing or fails to load, the app switches to a mock (random boxes / a simple
rule-based advisor) and shows a **Mode Demo** badge. *Pengaturan › Model
Create ML* shows which models are active.

Want different file names? Change `models.detector` / `models.advisor` in
`UrbanHarvest/Resources/ClassMapping.json`.

### Training the advisor

Train on `UrbanHarvest/Resources/sample_training_data.csv` (200 synthetic
rows), or your own CSV with **the same column names and values**. The columns
are defined once, in `UrbanHarvest/Models/FeatureSchema.swift`. Pick
`defect_rate` **or** `yield_kg_per_m2` as the target and leave the other target
column out of the features. The app reads the target from the model's output
name (or from `advisor.target` in `ClassMapping.json`).

If you change the schema, update `scripts/generate_sample_csv.py` and run:

```bash
python3 scripts/generate_sample_csv.py
```

A unit test fails if the CSV and `FeatureSchema.swift` drift apart.

See `UrbanHarvest/Models/README.md` for the full column table.

## 3. Edit class labels

Open `UrbanHarvest/Resources/ClassMapping.json` and list your detector's
labels under `labels.good` and `labels.defect`:

```json
"labels": {
  "good":   ["fresh_apple", "fresh_banana"],
  "defect": ["rotten_apple", "rotten_banana"]
}
```

- Matching ignores case and surrounding spaces.
- A label that is not listed is split on `_`, `-` and spaces and checked
  against `keywords` (defect first). For example, `rotten_pear` becomes
  *defect*.
- Anything still unmatched follows `unknownLabel.policy`: `ignore`, `good` or
  `defect`.
- `detection.minimumConfidence` drops weak boxes. `displayNames` sets the text
  drawn on each box.

The JSON is read at launch, so rebuild and run after editing it. No Swift
changes are needed.

## 4. Run the tests

In Xcode press **⌘U**, or:

```bash
xcodegen generate
xcodebuild build test \
  -project UrbanHarvest.xcodeproj \
  -scheme UrbanHarvest \
  -destination 'platform=iOS Simulator,name=iPhone 16' \
  CODE_SIGNING_ALLOWED=NO
```

The tests cover the centroid tracker and counting rules, the class mapping,
what-if ranking (with a stub and with the mock predictor), the spoken-text
formatting, the CSV-vs-schema check and the dashboard maths. They run without
model files. CI (`.github/workflows/ci.yml`) runs the same build and tests on
a macOS runner for every push.

## How it works

| Feature | Where | Notes |
|---|---|---|
| Live detection | `Features/Detection` | AVCaptureSession → Vision `VNCoreMLRequest` → green/red boxes |
| Count once | `Services/Tracker` | Centroid tracker assigns IDs. A fruit is counted when it crosses the yellow line, or after N stable frames. Method and thresholds are in *Pengaturan › Penghitungan*. |
| Photo test | Deteksi › Foto uji | Photo picker or `SampleImage` (add `Resources/sample_fruits.jpg` to use a real photo) |
| Dashboard | `Features/Dashboard` | SwiftData `HarvestSession`, totals, good/defect %, daily/weekly Swift Charts, history. Demo mode seeds example sessions. |
| Advisor | `Features/Advisor` | Tabular prediction. What-if changes **only** irrigation or harvest timing, one at a time, and shows the best 1–3 as estimates. A rule layer gives warnings (e.g. heavy rain → rot) without any model. |
| Speech | `Services/SpeechService` | `AVSpeechSynthesizer` with speak/pause/continue/stop. Plays through the speaker. Default `id-ID`, English in Settings. Spoken text uses short sentences and says "14 persen", not "14%". |

```
UrbanHarvest/
  App/                      app entry, settings, shared views, Info.plist
  Features/Detection/       camera, pipeline, overlay, photo test, save sheet
  Features/Dashboard/       stats, charts, demo seeder
  Features/Advisor/         form, what-if analyzer, advisory rules
  Features/Settings/
  Services/ModelLoader/     protocols, Core ML + mock implementations, ClassMapping
  Services/Tracker/         CentroidTracker, FruitCounter, CountingConfig
  Services/SpeechService/   SpeechService, SpokenText
  Models/                   ← drop .mlmodel files here; FeatureSchema, HarvestSession
  Resources/                ClassMapping.json, sample_training_data.csv
Tests/
scripts/                    CSV generator, CI helper
project.yml                 XcodeGen spec
```
