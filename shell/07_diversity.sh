#!/bin/bash
# =============================================================================
# Step 7: Diversity Analysis (Alpha + Beta)
# =============================================================================
# 1) Alpha rarefaction curves
# 2) Core-metrics-phylogenetic at chosen sampling depth
# 3) Alpha group significance (Kruskal-Wallis) for all metadata columns
# 4) Beta group significance (PERMANOVA, 999 permutations) for GROUP_VARS
#
# Input:  output/table.qza, output/rooted-tree.qza, output/metadata.tsv
# Output: output/diversity/  (distance matrices, PCoA, emperor, significance)
#         output/alpha-rarefaction.qzv
# =============================================================================
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "${SCRIPT_DIR}/00_config.sh"
activate_qiime2

TABLE="${OUTPUT_DIR}/table.qza"
TREE="${OUTPUT_DIR}/rooted-tree.qza"
DIVDIR="${OUTPUT_DIR}/diversity"

echo "============================================================"
echo " Step 7: Diversity Analysis (depth = ${RAREFACTION_DEPTH})"
echo "============================================================"

[[ -f "${TABLE}" ]] || { echo "ERROR: table.qza not found."; exit 1; }
[[ -f "${TREE}" ]]  || { echo "ERROR: rooted-tree.qza not found."; exit 1; }

# ── 7.1 Alpha rarefaction ───────────────────────────────────────────────────
echo ""
echo "[1/4] Alpha rarefaction curves..."
if [[ -f "${OUTPUT_DIR}/alpha-rarefaction.qzv" ]]; then
    echo "  Exists, skipping."
else
    qiime diversity alpha-rarefaction \
        --i-table "${TABLE}" \
        --i-phylogeny "${TREE}" \
        --p-max-depth 40000 \
        --p-steps 20 \
        --p-iterations 10 \
        --m-metadata-file "${METADATA}" \
        --p-metrics observed_features shannon faith_pd \
        --o-visualization "${OUTPUT_DIR}/alpha-rarefaction.qzv" \
        --verbose
    echo "  Done."
fi

# ── 7.2 Core metrics ────────────────────────────────────────────────────────
echo ""
echo "[2/4] Core metrics phylogenetic..."
if [[ -d "${DIVDIR}" ]]; then
    echo "  diversity/ directory exists, skipping core-metrics."
else
    qiime diversity core-metrics-phylogenetic \
        --i-table "${TABLE}" \
        --i-phylogeny "${TREE}" \
        --p-sampling-depth "${RAREFACTION_DEPTH}" \
        --m-metadata-file "${METADATA}" \
        --p-n-jobs-or-threads "${THREADS}" \
        --output-dir "${DIVDIR}" \
        --verbose
    echo "  Done."
fi

# ── 7.3 Alpha group significance ────────────────────────────────────────────
echo ""
echo "[3/4] Alpha group significance (Kruskal-Wallis)..."
ALPHA_METRICS=(shannon_vector faith_pd_vector observed_features_vector evenness_vector)
ALPHA_NAMES=(shannon faith_pd observed_features evenness)

for i in "${!ALPHA_METRICS[@]}"; do
    metric="${ALPHA_METRICS[$i]}"
    name="${ALPHA_NAMES[$i]}"
    outfile="${DIVDIR}/alpha-sig-${name}.qzv"
    if [[ -f "${outfile}" ]]; then
        echo "  ${name}: exists, skipping."
    else
        echo "  ${name}..."
        qiime diversity alpha-group-significance \
            --i-alpha-diversity "${DIVDIR}/${metric}.qza" \
            --m-metadata-file "${METADATA}" \
            --o-visualization "${outfile}" \
            --verbose
    fi
done

# ── 7.4 Beta group significance (PERMANOVA) ─────────────────────────────────
echo ""
echo "[4/4] Beta group significance (PERMANOVA, 999 permutations)..."
BETA_METRICS=(bray_curtis_distance_matrix weighted_unifrac_distance_matrix unweighted_unifrac_distance_matrix jaccard_distance_matrix)
BETA_NAMES=(bray_curtis weighted_unifrac unweighted_unifrac jaccard)

for i in "${!BETA_METRICS[@]}"; do
    metric="${BETA_METRICS[$i]}"
    bname="${BETA_NAMES[$i]}"
    for group in "${GROUP_VARS[@]}"; do
        safe=$(echo "${group}" | sed 's/[^a-zA-Z0-9]/_/g')
        outfile="${DIVDIR}/beta-sig-${bname}-${safe}.qzv"
        if [[ -f "${outfile}" ]]; then
            echo "  ${bname} x ${group}: exists, skipping."
        else
            echo "  ${bname} x ${group}..."
            qiime diversity beta-group-significance \
                --i-distance-matrix "${DIVDIR}/${metric}.qza" \
                --m-metadata-file "${METADATA}" \
                --m-metadata-column "${group}" \
                --p-method permanova \
                --p-pairwise \
                --p-permutations 999 \
                --o-visualization "${outfile}" \
                --verbose
        fi
    done
done

echo ""
echo "Step 7 complete."
