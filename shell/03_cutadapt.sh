#!/bin/bash
# =============================================================================
# Step 3: Primer Removal with Cutadapt
# =============================================================================
# Removes V3-V4 primer sequences (341F / 805R) from paired-end reads.
# Reads without detectable primers are discarded (--p-discard-untrimmed).
#
# Input:  output/demux-paired.qza
# Output: output/demux-trimmed.qza, output/demux-trimmed.qzv
# =============================================================================
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "${SCRIPT_DIR}/00_config.sh"
activate_qiime2

echo "============================================================"
echo " Step 3: Primer Removal (Cutadapt)"
echo "============================================================"
echo "  Forward primer (341F): ${PRIMER_F}"
echo "  Reverse primer (805R): ${PRIMER_R}"

[[ -f "${OUTPUT_DIR}/demux-paired.qza" ]] || { echo "ERROR: demux-paired.qza not found."; exit 1; }

echo ""
echo "[1/2] Running cutadapt trim-paired..."
if [[ -f "${OUTPUT_DIR}/demux-trimmed.qza" ]]; then
    echo "  demux-trimmed.qza exists, skipping."
else
    qiime cutadapt trim-paired \
        --i-demultiplexed-sequences "${OUTPUT_DIR}/demux-paired.qza" \
        --p-front-f "${PRIMER_F}" \
        --p-front-r "${PRIMER_R}" \
        --p-discard-untrimmed \
        --p-no-indels \
        --p-cores "${THREADS}" \
        --o-trimmed-sequences "${OUTPUT_DIR}/demux-trimmed.qza" \
        --verbose
    echo "  Done."
fi

echo ""
echo "[2/2] Generating post-trim QC visualization..."
if [[ -f "${OUTPUT_DIR}/demux-trimmed.qzv" ]]; then
    echo "  demux-trimmed.qzv exists, skipping."
else
    qiime demux summarize \
        --i-data "${OUTPUT_DIR}/demux-trimmed.qza" \
        --o-visualization "${OUTPUT_DIR}/demux-trimmed.qzv"
    echo "  Done."
fi

echo ""
echo "Step 3 complete.  Inspect demux-trimmed.qzv to decide DADA2 truncation lengths."
