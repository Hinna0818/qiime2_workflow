#!/bin/bash
# =============================================================================
# Step 4: Denoising with DADA2
# =============================================================================
# Generates ASV feature table, representative sequences, and denoising stats.
#
# Key parameters (set in 00_config.sh):
#   TRUNC_F / TRUNC_R  — forward / reverse truncation lengths
#   THREADS            — number of CPU threads
#
# Input:  output/demux-trimmed.qza
# Output: output/table.qza, output/rep-seqs.qza, output/denoising-stats.qza
# =============================================================================
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "${SCRIPT_DIR}/00_config.sh"
activate_qiime2

echo "============================================================"
echo " Step 4: DADA2 Denoising"
echo "============================================================"
echo "  Truncation: forward=${TRUNC_F}, reverse=${TRUNC_R}"
echo "  Threads:    ${THREADS}"

[[ -f "${OUTPUT_DIR}/demux-trimmed.qza" ]] || { echo "ERROR: demux-trimmed.qza not found."; exit 1; }

echo ""
echo "[1/4] Running DADA2 denoise-paired..."
if [[ -f "${OUTPUT_DIR}/table.qza" && -f "${OUTPUT_DIR}/rep-seqs.qza" ]]; then
    echo "  table.qza and rep-seqs.qza exist, skipping."
else
    time qiime dada2 denoise-paired \
        --i-demultiplexed-seqs "${OUTPUT_DIR}/demux-trimmed.qza" \
        --p-trunc-len-f "${TRUNC_F}" \
        --p-trunc-len-r "${TRUNC_R}" \
        --p-n-threads "${THREADS}" \
        --o-table "${OUTPUT_DIR}/table.qza" \
        --o-representative-sequences "${OUTPUT_DIR}/rep-seqs.qza" \
        --o-denoising-stats "${OUTPUT_DIR}/denoising-stats.qza" \
        --verbose
    echo "  Done."
fi

echo ""
echo "[2/4] Feature table summary..."
if [[ -f "${OUTPUT_DIR}/table.qzv" ]]; then
    echo "  table.qzv exists, skipping."
else
    qiime feature-table summarize \
        --i-table "${OUTPUT_DIR}/table.qza" \
        --m-metadata-file "${METADATA}" \
        --o-summary "${OUTPUT_DIR}/table.qzv"
    echo "  Done."
fi

echo ""
echo "[3/4] Representative sequences summary..."
if [[ -f "${OUTPUT_DIR}/rep-seqs.qzv" ]]; then
    echo "  rep-seqs.qzv exists, skipping."
else
    qiime feature-table tabulate-seqs \
        --i-data "${OUTPUT_DIR}/rep-seqs.qza" \
        --o-visualization "${OUTPUT_DIR}/rep-seqs.qzv"
    echo "  Done."
fi

echo ""
echo "[4/4] Denoising statistics..."
if [[ -f "${OUTPUT_DIR}/denoising-stats.qzv" ]]; then
    echo "  denoising-stats.qzv exists, skipping."
else
    qiime metadata tabulate \
        --m-input-file "${OUTPUT_DIR}/denoising-stats.qza" \
        --o-visualization "${OUTPUT_DIR}/denoising-stats.qzv"
    echo "  Done."
fi

echo ""
echo "Step 4 complete."
echo "  Inspect table.qzv to choose rarefaction depth (RAREFACTION_DEPTH in config)."
