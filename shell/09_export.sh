#!/bin/bash
# =============================================================================
# Step 9: Export Results to TSV
# =============================================================================
# Exports key QIIME 2 artifacts to plain-text TSV files for downstream
# analysis in R, Python, or other tools.
#
# Exports:
#   - Alpha diversity vectors (Shannon, Faith PD, Observed Features, Evenness)
#   - DADA2 denoising statistics
#   - Relative abundance tables (phylum, genus)
#   - ANCOM-BC differential abundance results
#   - ASV feature table and taxonomy
#
# Input:  Various .qza files from previous steps
# Output: output/exported/*.tsv
# =============================================================================
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "${SCRIPT_DIR}/00_config.sh"
activate_qiime2

EXPORT="${OUTPUT_DIR}/exported"
mkdir -p "${EXPORT}"

echo "============================================================"
echo " Step 9: Export Results to TSV"
echo "============================================================"

# ── 9.1 Alpha diversity ─────────────────────────────────────────────────────
echo ""
echo "[1/5] Exporting alpha diversity..."

python3 << PYEOF
import qiime2, pandas as pd, os

div_dir = "${OUTPUT_DIR}/diversity"
export_dir = "${EXPORT}"

metrics = {
    "shannon": "shannon_vector",
    "faith_pd": "faith_pd_vector",
    "observed_features": "observed_features_vector",
    "evenness": "evenness_vector"
}

dfs = []
for name, fname in metrics.items():
    fpath = os.path.join(div_dir, f"{fname}.qza")
    if os.path.isfile(fpath):
        s = qiime2.Artifact.load(fpath).view(pd.Series)
        s.name = name
        dfs.append(s)

if dfs:
    alpha = pd.concat(dfs, axis=1)
    alpha.index.name = "sample-id"
    out = os.path.join(export_dir, "alpha-diversity.tsv")
    alpha.to_csv(out, sep="\t")
    print(f"  alpha-diversity.tsv  ({alpha.shape[0]} samples x {alpha.shape[1]} metrics)")
PYEOF

# ── 9.2 DADA2 stats ─────────────────────────────────────────────────────────
echo ""
echo "[2/5] Exporting DADA2 denoising stats..."

python3 << PYEOF
import qiime2, os

fpath = "${OUTPUT_DIR}/denoising-stats.qza"
if os.path.isfile(fpath):
    df = qiime2.Artifact.load(fpath).view(qiime2.Metadata).to_dataframe()
    out = "${EXPORT}/dada2-stats.tsv"
    df.to_csv(out, sep="\t")
    print(f"  dada2-stats.tsv  ({df.shape[0]} samples)")
PYEOF

# ── 9.3 Relative abundance tables ───────────────────────────────────────────
echo ""
echo "[3/5] Exporting relative abundance tables..."

python3 << PYEOF
import qiime2, pandas as pd, os

diff_dir   = "${OUTPUT_DIR}/differential"
export_dir = "${EXPORT}"

for name in ("phylum", "genus"):
    fpath = os.path.join(diff_dir, f"table-{name}.qza")
    if os.path.isfile(fpath):
        df = qiime2.Artifact.load(fpath).view(pd.DataFrame)
        rel = df.div(df.sum(axis=1), axis=0)
        rel.index.name = "sample-id"
        out = os.path.join(export_dir, f"rel-abundance-{name}.tsv")
        rel.to_csv(out, sep="\t")
        print(f"  rel-abundance-{name}.tsv  ({rel.shape[0]} samples x {rel.shape[1]} taxa)")
PYEOF

# ── 9.4 ANCOM-BC results ────────────────────────────────────────────────────
echo ""
echo "[4/5] Exporting ANCOM-BC results..."

python3 << PYEOF
import qiime2, pandas as pd, os, glob

diff_dir   = "${OUTPUT_DIR}/differential"
export_dir = "${EXPORT}"

for fpath in sorted(glob.glob(os.path.join(diff_dir, "ancombc-*.qza"))):
    basename = os.path.splitext(os.path.basename(fpath))[0]
    try:
        df = qiime2.Artifact.load(fpath).view(pd.DataFrame)
        out = os.path.join(export_dir, f"{basename}.tsv")
        df.to_csv(out, sep="\t")
        sig_cols = [c for c in df.columns if "q_val" in c.lower() or "q-val" in c.lower()]
        n_sig = 0
        if sig_cols:
            n_sig = (df[sig_cols[0]] < 0.05).sum()
        print(f"  {basename}.tsv  ({df.shape[0]} features, {n_sig} significant)")
    except Exception as e:
        print(f"  WARNING: {basename} export failed: {e}")
PYEOF

# ── 9.5 ASV table + taxonomy ────────────────────────────────────────────────
echo ""
echo "[5/5] Exporting ASV table and taxonomy..."

python3 << PYEOF
import qiime2, pandas as pd, os

export_dir = "${EXPORT}"

fpath = "${OUTPUT_DIR}/table.qza"
if os.path.isfile(fpath):
    df = qiime2.Artifact.load(fpath).view(pd.DataFrame)
    df.index.name = "sample-id"
    out = os.path.join(export_dir, "asv-table.tsv")
    df.to_csv(out, sep="\t")
    print(f"  asv-table.tsv  ({df.shape[0]} samples x {df.shape[1]} ASVs)")

fpath = "${OUTPUT_DIR}/taxonomy.qza"
if os.path.isfile(fpath):
    df = qiime2.Artifact.load(fpath).view(pd.DataFrame)
    out = os.path.join(export_dir, "taxonomy.tsv")
    df.to_csv(out, sep="\t")
    print(f"  taxonomy.tsv  ({df.shape[0]} ASVs)")
PYEOF

echo ""
echo "Step 9 complete.  Exported files:"
ls -lh "${EXPORT}"/*.tsv 2>/dev/null || echo "  (none)"
