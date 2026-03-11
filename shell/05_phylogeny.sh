#!/bin/bash
# =============================================================================
# Step 5: Phylogenetic Tree Construction
# =============================================================================
# MAFFT alignment → masking → FastTree → midpoint rooting
#
# Input:  output/rep-seqs.qza
# Output: output/rooted-tree.qza  (+ intermediate alignment artifacts)
# =============================================================================
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "${SCRIPT_DIR}/00_config.sh"
activate_qiime2

echo "============================================================"
echo " Step 5: Phylogenetic Tree (MAFFT + FastTree)"
echo "============================================================"

[[ -f "${OUTPUT_DIR}/rep-seqs.qza" ]] || { echo "ERROR: rep-seqs.qza not found."; exit 1; }

if [[ -f "${OUTPUT_DIR}/rooted-tree.qza" ]]; then
    echo "  rooted-tree.qza exists, skipping."
else
    echo "[1/1] Running align-to-tree-mafft-fasttree..."
    time qiime phylogeny align-to-tree-mafft-fasttree \
        --i-sequences "${OUTPUT_DIR}/rep-seqs.qza" \
        --p-n-threads auto \
        --o-alignment "${OUTPUT_DIR}/aligned-rep-seqs.qza" \
        --o-masked-alignment "${OUTPUT_DIR}/masked-aligned-rep-seqs.qza" \
        --o-tree "${OUTPUT_DIR}/unrooted-tree.qza" \
        --o-rooted-tree "${OUTPUT_DIR}/rooted-tree.qza" \
        --verbose
    echo "  Done."
fi

echo ""
echo "Step 5 complete."
