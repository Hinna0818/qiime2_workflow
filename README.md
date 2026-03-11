# QIIME 2 16S rRNA (V3-V4) Analysis Pipeline

A reproducible, ready-to-use shell pipeline for 16S rRNA gene amplicon sequencing data analysis using **QIIME 2**. Designed for paired-end Illumina reads targeting the **V3-V4 hypervariable region** (primers 341F / 805R).

## Overview

```text
01_prepare.sh      Clean metadata & generate FASTQ manifest
02_import.sh       Import paired-end FASTQ into QIIME 2
03_cutadapt.sh     Remove primer sequences (Cutadapt)
04_dada2.sh        Denoise with DADA2 → ASV table + rep-seqs
05_phylogeny.sh    Build phylogenetic tree (MAFFT + FastTree)
06_taxonomy.sh     Taxonomic classification (Silva 138, Naive-Bayes)
07_diversity.sh    Alpha/Beta diversity + group significance tests
08_differential.sh Differential abundance analysis (ANCOM-BC)
09_export.sh       Export results to TSV for downstream analysis
run_all.sh         Run the full pipeline (or resume from any step)
```

## Requirements

| Software | Version | Notes |
|----------|---------|-------|
| QIIME 2 | ≥ 2024.10 (amplicon distribution) | Tested with 2026.1.0 |
| Python | ≥ 3.10 | Bundled with QIIME 2 |
| curl | any | For downloading Silva reference |

Install QIIME 2 following the [official guide](https://docs.qiime2.org/). Both **conda** and **native pip** installations are supported.

## Quick Start

### 1. Clone the repository

```bash
git clone https://github.com/Hinna0818/qiime2_workflow.git
cd qiime2_workflow
```

### 2. Prepare your data

Place your files under `data_raw/`:

```text
data_raw/
├── metadata.tsv              # Sample metadata (tab-separated)
├── Sample1_S1_L001_R1_001.fastq.gz
├── Sample1_S1_L001_R2_001.fastq.gz
├── Sample2_S2_L001_R1_001.fastq.gz
├── Sample2_S2_L001_R2_001.fastq.gz
└── ...
```

**Metadata format**: The first column must be `sample-id` (or `id`; it will be renamed automatically). FASTQ filenames must follow the standard Illumina naming convention (`{SampleID}_S*_L*_R{1,2}_001.fastq.gz`), where the sample ID is the part before the first underscore.

### 3. Edit the configuration

Open `shell/00_config.sh` and set:

```bash
# Path to your QIIME 2 environment activation script
QIIME2_ENV="${HOME}/qiime2_env/bin/activate"

# DADA2 truncation lengths (inspect demux-trimmed.qzv first)
TRUNC_F=230
TRUNC_R=215

# Rarefaction depth (inspect table.qzv first)
RAREFACTION_DEPTH=13000

# Grouping variables for statistical tests
GROUP_VARS=("Treatment" "Sex")
GROUP_REFS=("Treatment::Control" "Sex::Male")
```

### 4. Run the pipeline

```bash
# Full pipeline
bash shell/run_all.sh

# Or run individual steps
bash shell/01_prepare.sh
bash shell/02_import.sh
# ... etc.

# Resume from step 4 (e.g., after adjusting DADA2 parameters)
bash shell/run_all.sh 4
```

> **Interactive steps**: After Steps 2–4, inspect the `.qzv` files at [view.qiime2.org](https://view.qiime2.org) to confirm quality profiles and choose optimal truncation lengths and rarefaction depth before proceeding.

## Pipeline Details

### Step 1: Data Preparation

- Cleans Windows line endings (`\r`) from metadata
- Renames the first column to `sample-id` if needed
- Generates a `PairedEndFastqManifestPhred33V2` manifest by matching metadata sample IDs to FASTQ filenames

### Step 2: Import

- Imports paired-end FASTQ files into a QIIME 2 `SampleData[PairedEndSequencesWithQuality]` artifact

### Step 3: Primer Removal

- Removes V3-V4 primers (341F / 805R) using **Cutadapt**
- Discards reads without detectable primer sequences (`--p-discard-untrimmed`)

### Step 4: DADA2 Denoising

- Runs `dada2 denoise-paired` with user-specified truncation lengths
- Outputs: ASV feature table, representative sequences, denoising statistics

### Step 5: Phylogenetic Tree

- MAFFT multiple sequence alignment → gap masking → FastTree → midpoint rooting

### Step 6: Taxonomic Classification

- Downloads **Silva 138** (99% OTUs) reference sequences and taxonomy
- Extracts V3-V4 region using primer sequences
- Trains a **Naive-Bayes** classifier (region-specific)
- Classifies ASVs and generates taxa barplot

### Step 7: Diversity Analysis

- **Alpha rarefaction** curves (observed features, Shannon, Faith PD)
- **Core metrics phylogenetic** at specified sampling depth (produces Bray-Curtis, Jaccard, weighted/unweighted UniFrac distance matrices and PCoA)
- **Alpha group significance**: Kruskal-Wallis test for all metadata columns
- **Beta group significance**: PERMANOVA (999 permutations) for each distance metric × grouping variable

### Step 8: Differential Abundance (ANCOM-BC)

- Collapses feature table to phylum (L2) and genus (L6)
- Filters features present in < 10% of samples
- Runs **ANCOM-BC** with BH correction for each grouping variable
- Generates DA barplots

### Step 9: Export

- Exports alpha diversity, relative abundance (phylum/genus), ANCOM-BC results, ASV table, and taxonomy to plain-text TSV files

## Output Structure

```text
output/
├── demux-paired.qza / .qzv
├── demux-trimmed.qza / .qzv
├── table.qza / .qzv
├── rep-seqs.qza / .qzv
├── denoising-stats.qza / .qzv
├── rooted-tree.qza
├── taxonomy.qza / .qzv
├── taxa-barplot.qzv
├── alpha-rarefaction.qzv
├── ref/
│   ├── silva-138-99-seqs.qza
│   ├── silva-138-99-tax.qza
│   ├── ref-seqs-v3v4.qza
│   └── classifier-v3v4.qza
├── diversity/
│   ├── *_distance_matrix.qza
│   ├── *_pcoa_results.qza
│   ├── *_emperor.qzv
│   ├── alpha-sig-*.qzv
│   └── beta-sig-*.qzv
├── differential/
│   ├── table-{phylum,genus}[-filt].qza
│   ├── ancombc-*.qza
│   └── da-barplot-*.qzv
└── exported/
    ├── alpha-diversity.tsv
    ├── dada2-stats.tsv
    ├── rel-abundance-{phylum,genus}.tsv
    ├── ancombc-*.tsv
    ├── asv-table.tsv
    └── taxonomy.tsv
```

## Key Parameters

| Parameter | Default | Set in | Description |
|-----------|---------|--------|-------------|
| `PRIMER_F` / `PRIMER_R` | 341F / 805R | `00_config.sh` | V3-V4 primer sequences |
| `TRUNC_F` / `TRUNC_R` | 230 / 215 | `00_config.sh` | DADA2 forward/reverse truncation |
| `RAREFACTION_DEPTH` | 13000 | `00_config.sh` | Even sampling depth for diversity |
| `THREADS` | 4 | `00_config.sh` | CPU threads for parallel steps |
| `GROUP_VARS` | user-defined | `00_config.sh` | Metadata columns for group comparisons |
| `PADJ_METHOD` | BH | `00_config.sh` | Multiple testing correction |
| `PREVALENCE_CUTOFF` | 0.1 | `00_config.sh` | Minimum feature prevalence for ANCOM-BC |

## Idempotent Design

All scripts check for existing output files before running each command. This means:

- **Re-running is safe** — completed steps are automatically skipped.
- **Resuming after failure** — simply re-run the script or use `run_all.sh <step>`.
- **Changing parameters** — delete the relevant output files and re-run.

## Citation

If you use this pipeline, please cite:

- **QIIME 2**: Bolyen E, et al. (2019) Reproducible, interactive, scalable and extensible microbiome data science using QIIME 2. *Nature Biotechnology* 37:852–857.
- **DADA2**: Callahan BJ, et al. (2016) DADA2: High-resolution sample inference from Illumina amplicon data. *Nature Methods* 13:581–583.
- **Silva 138**: Quast C, et al. (2013) The SILVA ribosomal RNA gene database project. *Nucleic Acids Research* 41:D590–D596.
- **ANCOM-BC**: Lin H, Peddada SD (2020) Analysis of compositions of microbiomes with bias correction. *Nature Communications* 11:3514.

## License

MIT
