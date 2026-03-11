#!/bin/bash
# =============================================================================
# Step 6: Taxonomic Classification (Silva 138)
# =============================================================================
# Downloads Silva 138 99% OTU reference, extracts the V3-V4 region,
# trains a Naive-Bayes classifier, and classifies ASVs.
#
# Input:  output/rep-seqs.qza, output/table.qza
# Output: output/taxonomy.qza, output/taxonomy.qzv, output/taxa-barplot.qzv
#         output/ref/classifier-v3v4.qza  (cached for reuse)
# =============================================================================
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "${SCRIPT_DIR}/00_config.sh"
activate_qiime2

echo "============================================================"
echo " Step 6: Taxonomic Classification (Silva 138)"
echo "============================================================"

[[ -f "${OUTPUT_DIR}/rep-seqs.qza" ]] || { echo "ERROR: rep-seqs.qza not found."; exit 1; }
mkdir -p "${REF_DIR}"

# ── 6.1 Download reference ──────────────────────────────────────────────────
echo ""
echo "[1/5] Downloading Silva 138 reference..."
for url_var in SILVA_SEQS_URL SILVA_TAX_URL; do
    url="${!url_var}"
    fname=$(basename "${url}")
    if [[ -f "${REF_DIR}/${fname}" ]]; then
        echo "  ${fname} exists, skipping."
    else
        echo "  Downloading ${fname}..."
        curl -L -o "${REF_DIR}/${fname}" "${url}"
    fi
done

# ── 6.2 Extract V3-V4 reads ─────────────────────────────────────────────────
echo ""
echo "[2/5] Extracting V3-V4 region from reference..."
if [[ -f "${REF_DIR}/ref-seqs-v3v4.qza" ]]; then
    echo "  ref-seqs-v3v4.qza exists, skipping."
else
    qiime feature-classifier extract-reads \
        --i-sequences "${REF_DIR}/silva-138-99-seqs.qza" \
        --p-f-primer "${PRIMER_F}" \
        --p-r-primer "${PRIMER_R}" \
        --p-min-length 300 \
        --p-max-length 600 \
        --o-reads "${REF_DIR}/ref-seqs-v3v4.qza" \
        --verbose
    echo "  Done."
fi

# ── 6.3 Train classifier ────────────────────────────────────────────────────
echo ""
echo "[3/5] Training Naive-Bayes classifier (this may take 15-30 min)..."
if [[ -f "${REF_DIR}/classifier-v3v4.qza" ]]; then
    echo "  classifier-v3v4.qza exists, skipping."
else
    time qiime feature-classifier fit-classifier-naive-bayes \
        --i-reference-reads "${REF_DIR}/ref-seqs-v3v4.qza" \
        --i-reference-taxonomy "${REF_DIR}/silva-138-99-tax.qza" \
        --o-classifier "${REF_DIR}/classifier-v3v4.qza" \
        --verbose
    echo "  Done."
fi

# ── 6.4 Classify ASVs ───────────────────────────────────────────────────────
echo ""
echo "[4/5] Classifying ASVs..."
if [[ -f "${OUTPUT_DIR}/taxonomy.qza" ]]; then
    echo "  taxonomy.qza exists, skipping."
else
    time qiime feature-classifier classify-sklearn \
        --i-classifier "${REF_DIR}/classifier-v3v4.qza" \
        --i-reads "${OUTPUT_DIR}/rep-seqs.qza" \
        --o-classification "${OUTPUT_DIR}/taxonomy.qza" \
        --verbose
    echo "  Done."
fi

if [[ ! -f "${OUTPUT_DIR}/taxonomy.qzv" ]]; then
    qiime metadata tabulate \
        --m-input-file "${OUTPUT_DIR}/taxonomy.qza" \
        --o-visualization "${OUTPUT_DIR}/taxonomy.qzv"
fi

# ── 6.5 Taxa barplot ────────────────────────────────────────────────────────
echo ""
echo "[5/5] Generating taxa barplot..."
if [[ -f "${OUTPUT_DIR}/taxa-barplot.qzv" ]]; then
    echo "  taxa-barplot.qzv exists, skipping."
else
    qiime taxa barplot \
        --i-table "${OUTPUT_DIR}/table.qza" \
        --i-taxonomy "${OUTPUT_DIR}/taxonomy.qza" \
        --m-metadata-file "${METADATA}" \
        --o-visualization "${OUTPUT_DIR}/taxa-barplot.qzv"
    echo "  Done."
fi

echo ""
echo "Step 6 complete."
