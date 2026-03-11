#!/bin/bash
# =============================================================================
# Step 2: Import FASTQ Data into QIIME 2
# =============================================================================
# Input:  output/manifest.tsv
# Output: output/demux-paired.qza, output/demux-paired.qzv
# =============================================================================
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "${SCRIPT_DIR}/00_config.sh"
activate_qiime2

echo "============================================================"
echo " Step 2: Import paired-end FASTQ into QIIME 2"
echo "============================================================"

MANIFEST="${OUTPUT_DIR}/manifest.tsv"
[[ -f "${MANIFEST}" ]] || { echo "ERROR: manifest not found. Run 01_prepare.sh first."; exit 1; }

echo "  Samples: $(( $(wc -l < "${MANIFEST}") - 1 ))"

echo ""
echo "[1/2] Importing..."
if [[ -f "${OUTPUT_DIR}/demux-paired.qza" ]]; then
    echo "  demux-paired.qza exists, skipping."
else
    qiime tools import \
        --type 'SampleData[PairedEndSequencesWithQuality]' \
        --input-format PairedEndFastqManifestPhred33V2 \
        --input-path "${MANIFEST}" \
        --output-path "${OUTPUT_DIR}/demux-paired.qza"
    echo "  Done."
fi

echo ""
echo "[2/2] Generating demux summary visualization..."
if [[ -f "${OUTPUT_DIR}/demux-paired.qzv" ]]; then
    echo "  demux-paired.qzv exists, skipping."
else
    qiime demux summarize \
        --i-data "${OUTPUT_DIR}/demux-paired.qza" \
        --o-visualization "${OUTPUT_DIR}/demux-paired.qzv"
    echo "  Done."
fi

echo ""
echo "Step 2 complete.  Inspect demux-paired.qzv at https://view.qiime2.org"
