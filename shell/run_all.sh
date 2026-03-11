#!/bin/bash
# =============================================================================
# Run All: Execute the full QIIME 2 16S pipeline (Steps 1-9)
# =============================================================================
# Usage:  bash run_all.sh
#         bash run_all.sh 4        # resume from step 4
# =============================================================================
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

START=${1:-1}

STEPS=(
    "01_prepare.sh"
    "02_import.sh"
    "03_cutadapt.sh"
    "04_dada2.sh"
    "05_phylogeny.sh"
    "06_taxonomy.sh"
    "07_diversity.sh"
    "08_differential.sh"
    "09_export.sh"
)

echo "============================================================"
echo " QIIME 2 16S rRNA (V3-V4) Analysis Pipeline"
echo " Starting from step ${START}"
echo "============================================================"

for step in "${STEPS[@]}"; do
    num=${step%%_*}          # e.g. "01"
    num_int=$((10#${num}))   # remove leading zero
    if (( num_int < START )); then
        continue
    fi
    echo ""
    echo ">>> Running ${step} ..."
    echo ""
    bash "${SCRIPT_DIR}/${step}"
done

echo ""
echo "============================================================"
echo " Pipeline complete."
echo "============================================================"
