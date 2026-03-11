#!/bin/bash
# =============================================================================
# QIIME 2 16S rRNA (V3-V4) Analysis Pipeline — Configuration
# =============================================================================
# Edit this file BEFORE running any pipeline step.
# All scripts source this file to obtain paths and parameters.
# =============================================================================

# ── Project paths ────────────────────────────────────────────────────────────
PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DATA_DIR="${PROJECT_DIR}/data_raw"          # Raw FASTQ + metadata.tsv
OUTPUT_DIR="${PROJECT_DIR}/output"          # All pipeline outputs
REF_DIR="${OUTPUT_DIR}/ref"                 # Reference database cache
METADATA="${OUTPUT_DIR}/metadata.tsv"       # Cleaned metadata (created by 01)

# ── QIIME 2 activation ──────────────────────────────────────────────────────
# Adjust this to match your QIIME 2 environment (conda or venv).
QIIME2_ENV="${HOME}/qiime2_env/bin/activate"
# QIIME2_ENV="${HOME}/miniconda3/envs/qiime2-amplicon-2024.10/bin/activate"

# ── Primer sequences (V3-V4) ────────────────────────────────────────────────
PRIMER_F="CCTACGGGNGGCWGCAG"               # 341F (17 bp)
PRIMER_R="GACTACHVGGGTATCTAATCC"           # 805R (21 bp)

# ── DADA2 truncation parameters ─────────────────────────────────────────────
# Decide after inspecting demux-trimmed.qzv quality plots.
# V3-V4 amplicon ~460 bp; after primer removal ~422 bp.
# Overlap = TRUNC_F + TRUNC_R − amplicon_length.  Minimum overlap ≥ 12 bp.
TRUNC_F=230
TRUNC_R=215

# ── Rarefaction depth ────────────────────────────────────────────────────────
# Choose from the sample-frequency table in table.qzv.
# Aim for the highest depth that retains all (or most) samples.
RAREFACTION_DEPTH=13000

# ── Threads / parallelism ───────────────────────────────────────────────────
THREADS=4

# ── Taxonomy reference (Silva 138, 99% OTUs) ────────────────────────────────
SILVA_SEQS_URL="https://data.qiime2.org/2024.10/common/silva-138-99-seqs.qza"
SILVA_TAX_URL="https://data.qiime2.org/2024.10/common/silva-138-99-tax.qza"

# ── Grouping variables for diversity & differential abundance ────────────────
# Column names in metadata.tsv to test.
# For each variable, specify the reference level for ANCOM-BC.
GROUP_VARS=("group1" "group2")
GROUP_REFS=("group1::Control" "group2::Normal")

# ── ANCOM-BC parameters ─────────────────────────────────────────────────────
PADJ_METHOD="BH"                           # p-value adjustment (BH, holm, etc.)
PREVALENCE_CUTOFF=0.1                      # Minimum prevalence filter (10%)

# =============================================================================
# Helper: activate QIIME 2
# =============================================================================
activate_qiime2() {
    if [[ -f "${QIIME2_ENV}" ]]; then
        # shellcheck disable=SC1090
        source "${QIIME2_ENV}"
    else
        echo "ERROR: QIIME 2 environment not found at ${QIIME2_ENV}"
        echo "       Edit QIIME2_ENV in 00_config.sh"
        exit 1
    fi
}
