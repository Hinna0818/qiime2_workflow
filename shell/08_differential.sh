#!/bin/bash
# =============================================================================
# Step 8: Differential Abundance Analysis (ANCOM-BC)
# =============================================================================
# 1) Collapse feature table to phylum (L2) and genus (L6) levels
# 2) Filter low-prevalence features
# 3) Run ANCOM-BC for each GROUP_VAR at both taxonomic levels
# 4) Generate DA barplots
#
# Input:  output/table.qza, output/taxonomy.qza, output/metadata.tsv
# Output: output/differential/  (ancombc-*.qza, da-barplot-*.qzv)
# =============================================================================
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "${SCRIPT_DIR}/00_config.sh"
activate_qiime2

TABLE="${OUTPUT_DIR}/table.qza"
TAXONOMY="${OUTPUT_DIR}/taxonomy.qza"
DIFFDIR="${OUTPUT_DIR}/differential"

echo "============================================================"
echo " Step 8: Differential Abundance (ANCOM-BC)"
echo "============================================================"

[[ -f "${TABLE}" ]]    || { echo "ERROR: table.qza not found."; exit 1; }
[[ -f "${TAXONOMY}" ]] || { echo "ERROR: taxonomy.qza not found."; exit 1; }
mkdir -p "${DIFFDIR}"

# ── 8.1 Collapse by taxonomy level ──────────────────────────────────────────
echo ""
echo "[1/4] Collapsing feature table by taxonomic level..."
declare -A LEVELS=( [2]="phylum" [6]="genus" )

for level in 2 6; do
    name="${LEVELS[$level]}"
    outfile="${DIFFDIR}/table-${name}.qza"
    if [[ -f "${outfile}" ]]; then
        echo "  ${name} (L${level}): exists, skipping."
    else
        echo "  ${name} (L${level})..."
        qiime taxa collapse \
            --i-table "${TABLE}" \
            --i-taxonomy "${TAXONOMY}" \
            --p-level "${level}" \
            --o-collapsed-table "${outfile}" \
            --verbose
    fi
done

# ── 8.2 Filter low-prevalence features ──────────────────────────────────────
echo ""
echo "[2/4] Filtering low-prevalence features (min 10% of samples)..."
for name in phylum genus; do
    outfile="${DIFFDIR}/table-${name}-filt.qza"
    if [[ -f "${outfile}" ]]; then
        echo "  ${name}: exists, skipping."
    else
        echo "  ${name}..."
        # min-samples = 10% of total (at least 1)
        n_samples=$(qiime feature-table summarize \
            --i-table "${DIFFDIR}/table-${name}.qza" \
            --o-summary /dev/null 2>&1 | grep -oP '\d+ samples' | grep -oP '\d+' || echo "10")
        min_samples=10
        qiime feature-table filter-features \
            --i-table "${DIFFDIR}/table-${name}.qza" \
            --p-min-samples "${min_samples}" \
            --o-filtered-table "${outfile}" \
            --verbose
    fi
done

# ── 8.3 ANCOM-BC ────────────────────────────────────────────────────────────
echo ""
echo "[3/4] Running ANCOM-BC..."

for name in phylum genus; do
    for j in "${!GROUP_VARS[@]}"; do
        group="${GROUP_VARS[$j]}"
        ref="${GROUP_REFS[$j]}"
        safe=$(echo "${group}" | sed 's/[^a-zA-Z0-9]/_/g')
        outfile="${DIFFDIR}/ancombc-${name}-${safe}.qza"
        if [[ -f "${outfile}" ]]; then
            echo "  ${name} x ${group}: exists, skipping."
        else
            echo "  ${name} x ${group} (ref: ${ref})..."
            qiime composition ancombc \
                --i-table "${DIFFDIR}/table-${name}-filt.qza" \
                --m-metadata-file "${METADATA}" \
                --p-formula "${group}" \
                --p-reference-levels "${ref}" \
                --p-p-adj-method "${PADJ_METHOD}" \
                --p-prv-cut "${PREVALENCE_CUTOFF}" \
                --o-differentials "${outfile}" \
                --verbose
        fi
    done
done

# ── 8.4 DA barplots ─────────────────────────────────────────────────────────
echo ""
echo "[4/4] Generating DA barplots..."

for name in phylum genus; do
    for j in "${!GROUP_VARS[@]}"; do
        group="${GROUP_VARS[$j]}"
        safe=$(echo "${group}" | sed 's/[^a-zA-Z0-9]/_/g')
        infile="${DIFFDIR}/ancombc-${name}-${safe}.qza"
        outfile="${DIFFDIR}/da-barplot-${name}-${safe}.qzv"
        if [[ -f "${outfile}" ]]; then
            echo "  ${name} x ${group}: exists, skipping."
        else
            echo "  ${name} x ${group}..."
            qiime composition da-barplot \
                --i-data "${infile}" \
                --p-significance-threshold 0.05 \
                --p-effect-size-threshold 0 \
                --p-level-delimiter ";" \
                --o-visualization "${outfile}" \
                --verbose
        fi
    done
done

echo ""
echo "Step 8 complete."
