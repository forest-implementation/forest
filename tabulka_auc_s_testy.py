#!/usr/bin/env python3
# -*- coding: utf-8 -*-

"""
Compute ROC AUCs from generated CSVs and run:
1) Friedman test (global difference across 3 methods)
2) Nemenyi post-hoc test (pairwise, family-wise controlled)

Input expected (as produced by your pipeline):
csv/
  adjusted/
    <dataset>_<run>.csv
  mad/
    <dataset>_<run>.csv
  zscore_more_trees/
    <dataset>_<run>.csv

Each CSV: two columns, no header: FPR,TPR

Outputs:
outputs_auc_stats/
  auc_long.csv
  auc_wide.csv
  ranks_long.csv
  ranks_mean.csv
  nemenyi_pvalues.csv
  report.txt
"""

from pathlib import Path
import math
import numpy as np
import pandas as pd

from scipy.stats import friedmanchisquare, rankdata

# studentized_range is available in newer SciPy; if missing we will fall back gracefully.
try:
    from scipy.stats import studentized_range  # type: ignore
    _HAS_STUDENTIZED_RANGE = True
except Exception:
    _HAS_STUDENTIZED_RANGE = False


# -------------------------------------------------------------------
# Config
# -------------------------------------------------------------------
CSV_FOLDERS = {
    "adjusted": Path("csv/adjusted"),
    "mad": Path("csv/mad"),
    "zscore_more_trees": Path("csv/zscore_more_trees"),
}
OUT_DIR = Path("outputs_auc_stats")
ALPHA = 0.05

# -------------------------------------------------------------------
# Helpers
# -------------------------------------------------------------------
def parse_dataset_and_run(filename: str) -> tuple[str, str]:
    """
    Expects <dataset>_<run>.csv where dataset itself may contain underscores.
    Example: 8_celeba_r07.csv -> dataset=8_celeba, run=r07
    Example: 19_landsat_t100.csv -> dataset=19_landsat, run=t100
    """
    stem = Path(filename).stem
    if "_" not in stem:
        return stem, ""
    parts = stem.split("_")
    dataset = "_".join(parts[:-1])
    run = parts[-1]
    return dataset, run

def read_fpr_tpr_csv(path: Path) -> tuple[np.ndarray, np.ndarray]:
    df = pd.read_csv(path, header=None, names=["fpr", "tpr"])
    fpr = df["fpr"].to_numpy(dtype=float)
    tpr = df["tpr"].to_numpy(dtype=float)

    m = np.isfinite(fpr) & np.isfinite(tpr)
    fpr, tpr = fpr[m], tpr[m]

    if fpr.size == 0:
        return fpr, tpr

    # sort by FPR for trapezoid integral
    order = np.argsort(fpr)
    fpr, tpr = fpr[order], tpr[order]

    # clip just in case
    fpr = np.clip(fpr, 0.0, 1.0)
    tpr = np.clip(tpr, 0.0, 1.0)

    # ensure endpoints (0,0) and (1,1) exist (harmless if already present)
    if not (np.isclose(fpr[0], 0.0) and np.isclose(tpr[0], 0.0)):
        fpr = np.r_[0.0, fpr]
        tpr = np.r_[0.0, tpr]
    if not (np.isclose(fpr[-1], 1.0) and np.isclose(tpr[-1], 1.0)):
        fpr = np.r_[fpr, 1.0]
        tpr = np.r_[tpr, 1.0]

    return fpr, tpr

def auc_trapezoid(fpr: np.ndarray, tpr: np.ndarray) -> float:
    if fpr.size < 2:
        return float("nan")
    # numpy 2.x: trapezoid; older: trapz
    if hasattr(np, "trapezoid"):
        return float(np.trapezoid(tpr, fpr))
    return float(np.trapz(tpr, fpr))

def compute_block_ranks(wide: pd.DataFrame) -> pd.DataFrame:
    """
    Compute within-block ranks across methods.
    Higher AUC = better => rank 1 is best (descending).
    wide: index=(dataset, run), columns=methods, values=AUC
    """
    methods = list(wide.columns)
    X = wide.to_numpy(dtype=float)

    # Rank per row: we want best=1, so rank(-auc)
    ranks = np.apply_along_axis(lambda row: rankdata(-row, method="average"), 1, X)
    ranks_df = pd.DataFrame(ranks, index=wide.index, columns=methods)
    return ranks_df

def nemenyi_pvalues(mean_ranks: pd.Series, k: int, N: int) -> pd.DataFrame:
    """
    Pairwise Nemenyi p-values using Studentized range distribution.
    mean_ranks: average ranks per method (lower = better)
    k: number of methods
    N: number of blocks (paired observations)
    """
    methods = list(mean_ranks.index)
    se = math.sqrt(k * (k + 1) / (6.0 * N))

    P = pd.DataFrame(np.ones((k, k), dtype=float), index=methods, columns=methods)

    for i in range(k):
        for j in range(i + 1, k):
            q = abs(mean_ranks.iloc[i] - mean_ranks.iloc[j]) / se

            if _HAS_STUDENTIZED_RANGE:
                # Nemenyi: p = P(Q >= q) where Q ~ studentized range, using sqrt(2) scaling
                p = float(studentized_range.sf(q * math.sqrt(2.0), k, np.inf))
            else:
                # Fallback (if SciPy lacks studentized_range): conservative normal approx
                # This is NOT exact Nemenyi; kept only to avoid crashing.
                # Users should upgrade SciPy to get exact p-values.
                from scipy.stats import norm
                p = float(2.0 * norm.sf(q))  # two-sided approx

            P.iloc[i, j] = p
            P.iloc[j, i] = p

    return P

# -------------------------------------------------------------------
# Main
# -------------------------------------------------------------------
def main():
    OUT_DIR.mkdir(parents=True, exist_ok=True)

    # 1) Load AUCs (long)
    rows = []
    for method, folder in CSV_FOLDERS.items():
        if not folder.exists():
            print(f"[WARN] Missing folder: {folder}")
            continue

        for path in sorted(folder.glob("*.csv")):
            dataset, run = parse_dataset_and_run(path.name)
            fpr, tpr = read_fpr_tpr_csv(path)
            auc = auc_trapezoid(fpr, tpr)
            rows.append({
                "dataset": dataset,
                "run": run,
                "method": method,
                "auc": auc,
                "file": str(path),
                "n_points": int(len(fpr)),
            })

    auc_long = pd.DataFrame(rows)
    if auc_long.empty:
        raise SystemExit("No CSV files found. Check csv/<method>/ folders and filenames.")

    # 2) Wide table for paired tests: index=(dataset, run) columns=method
    auc_wide = (
        auc_long
        .pivot_table(index=["dataset", "run"], columns="method", values="auc", aggfunc="mean")
        .sort_index()
    )

    # Drop incomplete blocks (missing any method)
    auc_wide_clean = auc_wide.dropna()
    dropped = auc_wide.shape[0] - auc_wide_clean.shape[0]

    methods = list(auc_wide_clean.columns)
    k = len(methods)
    N = auc_wide_clean.shape[0]

    if k < 3:
        raise SystemExit(f"Need 3 methods for your setup; found {k}: {methods}")
    if N < 2:
        raise SystemExit(f"Insufficient paired observations after dropna(): N={N}")

    # 3) Friedman test (global)
    stat, p_friedman = friedmanchisquare(*[auc_wide_clean[m].to_numpy() for m in methods])

    # 4) Ranks + Nemenyi
    ranks_df = compute_block_ranks(auc_wide_clean)
    mean_ranks = ranks_df.mean(axis=0).sort_values()  # lower = better

    p_nemenyi = nemenyi_pvalues(mean_ranks, k=k, N=N)

    # 5) Save outputs
    auc_long.sort_values(["dataset", "run", "method"]).to_csv(OUT_DIR / "auc_long.csv", index=False)
    auc_wide.to_csv(OUT_DIR / "auc_wide.csv")  # includes NaNs, useful for debugging
    ranks_df.reset_index().to_csv(OUT_DIR / "ranks_long.csv", index=False)
    mean_ranks.rename("mean_rank").to_frame().to_csv(OUT_DIR / "ranks_mean.csv")
    p_nemenyi.to_csv(OUT_DIR / "nemenyi_pvalues.csv")

    # 6) Human-readable report
    lines = []
    lines.append("AUC statistics report")
    lines.append("=" * 72)
    lines.append(f"Methods: {methods}")
    lines.append(f"Blocks (paired observations): N = {N}")
    if dropped > 0:
        lines.append(f"Dropped incomplete blocks due to missing method data: {dropped}")
    lines.append("")
    lines.append("Friedman test (global difference across methods)")
    lines.append("-" * 72)
    lines.append(f"Statistic (chi-square): {stat:.6f}")
    lines.append(f"p-value: {p_friedman:.6g}")
    lines.append(f"alpha: {ALPHA}")
    lines.append(f"Decision: {'REJECT H0' if p_friedman < ALPHA else 'FAIL TO REJECT H0'}")
    lines.append("")
    lines.append("Mean ranks (lower is better; rank 1 = best per block)")
    lines.append("-" * 72)
    for m, r in mean_ranks.items():
        lines.append(f"{m:20s}  {r:.6f}")
    lines.append("")
    lines.append("Nemenyi post-hoc pairwise p-values (family-wise controlled)")
    lines.append("-" * 72)
    if not _HAS_STUDENTIZED_RANGE:
        lines.append("[WARN] scipy.stats.studentized_range not available; using conservative normal approximation.")
        lines.append("       Upgrade SciPy to get exact Nemenyi p-values.")
        lines.append("")
    lines.append(p_nemenyi.to_string(float_format=lambda x: f"{x:.6g}"))
    lines.append("")
    lines.append(f"Significant pairs at alpha={ALPHA}:")
    sig_pairs = []
    for i in range(k):
        for j in range(i + 1, k):
            mi, mj = methods[i], methods[j]
            p = p_nemenyi.loc[mi, mj]
            if p < ALPHA:
                sig_pairs.append((mi, mj, p))
    if sig_pairs:
        for mi, mj, p in sorted(sig_pairs, key=lambda t: t[2]):
            lines.append(f"- {mi} vs {mj}: p={p:.6g}")
    else:
        lines.append("- none")

    (OUT_DIR / "report.txt").write_text("\n".join(lines), encoding="utf-8")

    # 7) Console summary
    print("\n".join(lines[:25]))
    print(f"\nSaved outputs to: {OUT_DIR.resolve()}")

if __name__ == "__main__":
    main()