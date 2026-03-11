#!/bin/bash
# =============================================================================
# Step 1: Data Preparation
# =============================================================================
# Clean metadata and generate a QIIME 2 paired-end FASTQ manifest.
#
# Input:  data_raw/metadata.tsv, data_raw/*_R1_001.fastq.gz
# Output: output/metadata.tsv, output/manifest.tsv
# =============================================================================
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "${SCRIPT_DIR}/00_config.sh"

mkdir -p "${OUTPUT_DIR}"

echo "============================================================"
echo " Step 1: Data Preparation"
echo "============================================================"

# ── 1.1 Clean metadata ──────────────────────────────────────────────────────
echo ""
echo "[1/3] Cleaning metadata..."

python3 << 'PYEOF'
import os, csv, sys

data_dir   = os.environ.get("DATA_DIR",   "data_raw")
output_dir = os.environ.get("OUTPUT_DIR",  "output")
raw_path   = os.path.join(data_dir, "metadata.tsv")
clean_path = os.path.join(output_dir, "metadata.tsv")

if not os.path.isfile(raw_path):
    print(f"ERROR: {raw_path} not found"); sys.exit(1)

with open(raw_path, "r", encoding="utf-8") as f:
    content = f.read().replace("\r\n", "\n").replace("\r", "\n")

lines = content.strip().split("\n")
header = lines[0].split("\t")

# Ensure first column is "sample-id"
if header[0].lower() in ("id", "sampleid", "sample_id", "#SampleID"):
    header[0] = "sample-id"

with open(clean_path, "w", newline="") as f:
    writer = csv.writer(f, delimiter="\t", lineterminator="\n")
    writer.writerow(header)
    for line in lines[1:]:
        fields = line.split("\t")
        if fields[0].strip():
            writer.writerow(fields)

n = len(lines) - 1
print(f"  Processed {n} samples -> {clean_path}")
PYEOF

# ── 1.2 Generate manifest ───────────────────────────────────────────────────
echo ""
echo "[2/3] Generating QIIME 2 manifest..."

DATA_DIR="${DATA_DIR}" OUTPUT_DIR="${OUTPUT_DIR}" python3 << 'PYEOF'
import os, glob, csv, sys

data_dir   = os.environ["DATA_DIR"]
output_dir = os.environ["OUTPUT_DIR"]
meta_path  = os.path.join(output_dir, "metadata.tsv")
manifest   = os.path.join(output_dir, "manifest.tsv")

# Read sample IDs from cleaned metadata
with open(meta_path) as f:
    reader = csv.DictReader(f, delimiter="\t")
    meta_ids = [row["sample-id"].strip() for row in reader]

# Scan R1 FASTQ files  (Illumina format: SAMPLEID_S*_L*_R1_001.fastq.gz)
fastq_r1 = sorted(glob.glob(os.path.join(data_dir, "*_R1_001.fastq.gz")))
fastq_map = {}
for r1 in fastq_r1:
    sid = os.path.basename(r1).split("_")[0]
    r2  = r1.replace("_R1_001.fastq.gz", "_R2_001.fastq.gz")
    if os.path.exists(r2):
        fastq_map[sid] = (os.path.abspath(r1), os.path.abspath(r2))

# Match metadata IDs to FASTQ files
matched = []
for mid in meta_ids:
    if mid in fastq_map:
        matched.append((mid, *fastq_map[mid]))
    elif mid + "R" in fastq_map:          # handle R-suffix convention
        matched.append((mid, *fastq_map[mid + "R"]))

with open(manifest, "w", newline="") as f:
    writer = csv.writer(f, delimiter="\t", lineterminator="\n")
    writer.writerow(["sample-id", "forward-absolute-filepath", "reverse-absolute-filepath"])
    for row in sorted(matched):
        writer.writerow(row)

print(f"  Matched {len(matched)}/{len(meta_ids)} samples -> {manifest}")
if len(matched) < len(meta_ids):
    missing = set(meta_ids) - {m[0] for m in matched}
    print(f"  WARNING: unmatched samples: {sorted(missing)}")
    sys.exit(1)
PYEOF

# ── 1.3 Verify ──────────────────────────────────────────────────────────────
echo ""
echo "[3/3] Verification"
echo "  metadata lines : $(wc -l < "${METADATA}")"
echo "  manifest lines : $(wc -l < "${OUTPUT_DIR}/manifest.tsv")"
echo ""
echo "Step 1 complete."
