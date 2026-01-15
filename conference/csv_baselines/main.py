#!/usr/bin/env python3
# -*- coding: utf-8 -*-

import warnings
from pathlib import Path
from typing import Dict, List, Tuple

import numpy as np
import pandas as pd

from scipy.stats import friedmanchisquare


import matplotlib.pyplot as plt


# -----------------------------
# Helpers
# -----------------------------
def list_algorithms(root: Path) -> List[Path]:
    algs = [p for p in root.iterdir() if p.is_dir()]
    good = []
    for a in algs:
        if (a / "auc").is_dir() and (a / "confusion").is_dir() and (a / "roc_curves").is_dir():
            good.append(a)
    return sorted(good, key=lambda p: p.name)

def list_datasets(alg_dir: Path) -> List[str]:
    auc_files = {p.name for p in (alg_dir / "auc").glob("*.csv")}
    conf_files = {p.name for p in (alg_dir / "confusion").glob("*.csv")}
    # pairing by datasets present in both, ROC handled separately
    return sorted(list(auc_files.intersection(conf_files)))

def read_single_value_auc(path: Path) -> float:
    """
    Handles:
    - "0.5347..."
    - "auc\\n0.5347..."
    - "auc,0.5347..."
    - CSV with a column named 'auc' and one row
    """
    txt = path.read_text(encoding="utf-8", errors="replace").strip()
    if not txt:
        raise ValueError("Empty file")

    # First try: direct float (works for plain numeric)
    try:
        return float(txt)
    except Exception:
        pass

    # Try parsing as CSV with pandas
    try:
        df = pd.read_csv(path)
        # Case 1: column named 'auc'
        for c in df.columns:
            if str(c).strip().lower() == "auc":
                v = df[c].dropna()
                if len(v) >= 1:
                    return float(v.iloc[0])
        # Case 2: single value somewhere
        if df.shape[0] >= 1 and df.shape[1] >= 1:
            v = df.iloc[0, 0]
            return float(v)
    except Exception:
        pass

    # Fallback: scan lines and pick first thing that looks like a float
    for line in txt.splitlines():
        line = line.strip()
        if not line:
            continue
        if line.lower() == "auc":
            continue
        # maybe "auc,0.123"
        if "," in line:
            parts = [p.strip() for p in line.split(",") if p.strip()]
            for p in parts:
                try:
                    return float(p)
                except Exception:
                    continue
        try:
            return float(line)
        except Exception:
            continue

    raise ValueError(f"Could not parse AUC from file: {path}")

def read_roc_curve(roc_dir: Path, dataset_file: str) -> Tuple[np.ndarray, np.ndarray]:
    """
    Prefer *_by_fpr.csv if present, else fallback to base dataset_file in roc_curves.
    Expected columns: threshold,fpr,tpr
    """
    stem = Path(dataset_file).stem
    candidates = [
        roc_dir / f"{stem}_by_fpr.csv",
        roc_dir / f"{stem}.csv",
    ]
    chosen = None
    for c in candidates:
        if c.exists():
            chosen = c
            break
    if chosen is None:
        raise FileNotFoundError(f"ROC curve file not found for {dataset_file} in {roc_dir}")

    df = pd.read_csv(chosen)
    if "fpr" not in df.columns or "tpr" not in df.columns:
        raise ValueError(f"Missing fpr/tpr in {chosen} (columns: {list(df.columns)})")

    fpr = df["fpr"].to_numpy(dtype=float)
    tpr = df["tpr"].to_numpy(dtype=float)

    order = np.argsort(fpr)
    return fpr[order], tpr[order]

def trapezoid(y: np.ndarray, x: np.ndarray) -> float:
    # numpy 2.x prefers trapezoid; some environments might miss trapz alias
    if hasattr(np, "trapezoid"):
        return float(np.trapezoid(y, x))
    # fallback: manual
    dx = np.diff(x)
    return float(np.sum((y[:-1] + y[1:]) * 0.5 * dx))

def read_pr_curve_from_confusion(conf_path: Path) -> Tuple[np.ndarray, np.ndarray, float]:
    """
    confusion CSV contains precision,recall across thresholds.
    PR AUC = trapezoidal integral of precision over recall (approximation).
    """
    df = pd.read_csv(conf_path)
    if "precision" not in df.columns or "recall" not in df.columns:
        raise ValueError(f"Missing precision/recall columns in {conf_path}")

    prec = df["precision"].to_numpy(dtype=float)
    rec = df["recall"].to_numpy(dtype=float)

    m = ~np.isnan(prec) & ~np.isnan(rec)
    prec = prec[m]
    rec = rec[m]

    if rec.size < 2:
        return rec, prec, float("nan")

    order = np.argsort(rec)
    rec = rec[order]
    prec = prec[order]

    # Deduplicate recall: keep max precision at each recall
    rec_u, prec_u = [], []
    i = 0
    while i < len(rec):
        r = rec[i]
        j = i
        pmax = prec[i]
        while j < len(rec) and rec[j] == r:
            pmax = max(pmax, prec[j])
            j += 1
        rec_u.append(r)
        prec_u.append(pmax)
        i = j

    rec_u = np.asarray(rec_u, dtype=float)
    prec_u = np.asarray(prec_u, dtype=float)

    if rec_u.size < 2:
        return rec_u, prec_u, float("nan")

    pr_auc = trapezoid(prec_u, rec_u)
    return rec_u, prec_u, pr_auc

def mean_curve(curves: List[Tuple[np.ndarray, np.ndarray]], x_grid: np.ndarray) -> Tuple[np.ndarray, np.ndarray]:
    ys = []
    for x, y in curves:
        if len(x) < 2:
            continue
        y_i = np.interp(x_grid, x, y, left=y[0], right=y[-1])
        ys.append(y_i)
    if not ys:
        return np.full_like(x_grid, np.nan), np.full_like(x_grid, np.nan)
    Y = np.vstack(ys)
    return Y.mean(axis=0), Y.std(axis=0)

def save_plot(path: Path, title: str, xlabel: str, ylabel: str):
    plt.title(title)
    plt.xlabel(xlabel)
    plt.ylabel(ylabel)
    plt.tight_layout()
    plt.savefig(path, dpi=200)
    plt.close()


# -----------------------------
# Main
# -----------------------------
def main():
    root = Path(".").resolve()
    out = root / "outputs"
    out.mkdir(parents=True, exist_ok=True)
    (out / "per_dataset").mkdir(parents=True, exist_ok=True)

    alg_dirs = list_algorithms(root)
    if len(alg_dirs) < 2:
        raise SystemExit("Nenalezl jsem alespoň 2 algoritmické složky s auc/confusion/roc_curves.")

    alg_names = [a.name for a in alg_dirs]

    # Common datasets across all algorithms (based on auc∩confusion)
    sets = [set(list_datasets(a)) for a in alg_dirs]
    common_datasets = sorted(list(set.intersection(*sets))) if sets else []
    if not common_datasets:
        raise SystemExit("Nenalezl jsem společné datasety napříč algoritmy (podle auc/*.csv ∩ confusion/*.csv).")

    per_rows = []
    roc_auc_mat = []
    pr_auc_mat = []

    roc_curves_by_alg: Dict[str, List[Tuple[np.ndarray, np.ndarray]]] = {n: [] for n in alg_names}
    pr_curves_by_alg: Dict[str, List[Tuple[np.ndarray, np.ndarray]]] = {n: [] for n in alg_names}

    fpr_grid = np.linspace(0.0, 1.0, 1001)
    rec_grid = np.linspace(0.0, 1.0, 1001)

    for ds_file in common_datasets:
        roc_row = []
        pr_row = []

        # Per-dataset ROC plot
        plt.figure()
        for alg_dir in alg_dirs:
            alg = alg_dir.name

            # ROC AUC
            auc_path = alg_dir / "auc" / ds_file
            try:
                roc_auc = read_single_value_auc(auc_path)
            except Exception as e:
                warnings.warn(f"[{alg}] Cannot read AUC from {auc_path}: {e}")
                roc_auc = float("nan")

            # ROC curve
            try:
                fpr, tpr = read_roc_curve(alg_dir / "roc_curves", ds_file)
                roc_curves_by_alg[alg].append((fpr, tpr))
                plt.plot(fpr, tpr, label=f"{alg} (AUC={roc_auc:.4f})")
            except Exception as e:
                warnings.warn(f"[{alg}] Cannot read ROC curve for {ds_file}: {e}")

            roc_row.append(roc_auc)

            # PR curve + PR AUC (from confusion sweep)
            conf_path = alg_dir / "confusion" / ds_file
            try:
                rec, prec, pr_auc = read_pr_curve_from_confusion(conf_path)
                pr_curves_by_alg[alg].append((rec, prec))
            except Exception as e:
                warnings.warn(f"[{alg}] Cannot read PR curve from {conf_path}: {e}")
                pr_auc = float("nan")

            pr_row.append(pr_auc)

            per_rows.append({
                "dataset_file": ds_file,
                "dataset": Path(ds_file).stem,
                "algorithm": alg,
                "roc_auc": roc_auc,
                "pr_auc_trapz_from_confusion": pr_auc,
            })

        plt.plot([0, 1], [0, 1], linestyle="--", linewidth=1)
        plt.xlim([0.0, 1.0])
        plt.ylim([0.0, 1.0])
        plt.legend(loc="lower right", frameon=True)
        save_plot(
            out / "per_dataset" / f"ROC_{Path(ds_file).stem}.pdf",
            title=f"ROC comparison: {Path(ds_file).stem}",
            xlabel="False Positive Rate",
            ylabel="True Positive Rate",
        )

        # Per-dataset PR plot
        plt.figure()
        for alg_dir in alg_dirs:
            alg = alg_dir.name
            conf_path = alg_dir / "confusion" / ds_file
            try:
                rec, prec, pr_auc = read_pr_curve_from_confusion(conf_path)
                plt.plot(rec, prec, label=f"{alg} (PR AUC≈{pr_auc:.4f})")
            except Exception as e:
                warnings.warn(f"[{alg}] Cannot plot PR for {ds_file}: {e}")

        plt.xlim([0.0, 1.0])
        plt.ylim([0.0, 1.0])
        plt.legend(loc="lower right", frameon=True)
        save_plot(
            out / "per_dataset" / f"PR_{Path(ds_file).stem}.pdf",
            title=f"PR comparison: {Path(ds_file).stem}",
            xlabel="Recall",
            ylabel="Precision",
        )

        roc_auc_mat.append(roc_row)
        pr_auc_mat.append(pr_row)

    per_df = pd.DataFrame(per_rows)
    per_df.to_csv(out / "per_dataset_metrics.csv", index=False)

    roc_auc_mat = np.asarray(roc_auc_mat, dtype=float)
    pr_auc_mat = np.asarray(pr_auc_mat, dtype=float)

    # Keep only datasets without NaNs for each test
    keep_roc = ~np.any(np.isnan(roc_auc_mat), axis=1)
    keep_pr = ~np.any(np.isnan(pr_auc_mat), axis=1)

    roc_auc_mat_f = roc_auc_mat[keep_roc]
    pr_auc_mat_f = pr_auc_mat[keep_pr]

    datasets_roc = [d for d, k in zip(common_datasets, keep_roc) if k]
    datasets_pr = [d for d, k in zip(common_datasets, keep_pr) if k]

    def friedman(mat: np.ndarray, datasets_used: List[str]):
        if mat.shape[0] < 2 or mat.shape[1] < 2:
            return {"status": "insufficient_data", "n_datasets": int(mat.shape[0]), "n_algorithms": int(mat.shape[1])}
        args = [mat[:, j] for j in range(mat.shape[1])]
        stat, p = friedmanchisquare(*args)
        return {
            "status": "ok",
            "n_datasets": int(mat.shape[0]),
            "datasets_used_example": datasets_used[:10],
            "algorithms": alg_names,
            "statistic": float(stat),
            "p_value": float(p),
        }

    friedman_report = {
        "roc_auc": friedman(roc_auc_mat_f, datasets_roc),
        "pr_auc": friedman(pr_auc_mat_f, datasets_pr),
    }
    (out / "friedman_report.json").write_text(
        pd.Series(friedman_report).to_json(force_ascii=False, indent=2),
        encoding="utf-8"
    )

    # Wide exports (safe; no .loc that can explode)
    wide_roc = per_df.pivot_table(index="dataset_file", columns="algorithm", values="roc_auc", aggfunc="mean")
    wide_pr = per_df.pivot_table(index="dataset_file", columns="algorithm", values="pr_auc_trapz_from_confusion", aggfunc="mean")
    wide_roc.to_csv(out / "roc_auc_wide.csv")
    wide_pr.to_csv(out / "pr_auc_wide.csv")

    # Aggregate mean ROC plot
    plt.figure()
    for alg in alg_names:
        curves = roc_curves_by_alg.get(alg, [])
        mean_tpr, std_tpr = mean_curve(curves, fpr_grid)
        auc_mean = float(per_df.loc[per_df["algorithm"] == alg, "roc_auc"].mean())
        plt.plot(fpr_grid, mean_tpr, label=f"{alg} (mean AUC={auc_mean:.4f})")
        plt.fill_between(fpr_grid, np.clip(mean_tpr - std_tpr, 0, 1), np.clip(mean_tpr + std_tpr, 0, 1), alpha=0.2)
    plt.plot([0, 1], [0, 1], linestyle="--", linewidth=1)
    plt.xlim([0.0, 1.0])
    plt.ylim([0.0, 1.0])
    plt.legend(loc="lower right", frameon=True)
    save_plot(out / "ROC_mean_comparison.pdf", "ROC curves (mean ± 1 SD over datasets)", "False Positive Rate", "True Positive Rate")

    # Aggregate mean PR plot
    plt.figure()
    for alg in alg_names:
        curves = pr_curves_by_alg.get(alg, [])
        mean_prec, std_prec = mean_curve(curves, rec_grid)
        pr_mean = float(per_df.loc[per_df["algorithm"] == alg, "pr_auc_trapz_from_confusion"].mean())
        plt.plot(rec_grid, mean_prec, label=f"{alg} (mean PR AUC≈{pr_mean:.4f})")
        plt.fill_between(rec_grid, np.clip(mean_prec - std_prec, 0, 1), np.clip(mean_prec + std_prec, 0, 1), alpha=0.2)
    plt.xlim([0.0, 1.0])
    plt.ylim([0.0, 1.0])
    plt.legend(loc="lower right", frameon=True)
    save_plot(out / "PR_mean_comparison.pdf", "Precision-Recall curves (mean ± 1 SD over datasets)", "Recall", "Precision")

    print("Done.")
    print(f"Algorithms: {', '.join(alg_names)}")
    print(f"Common datasets: {len(common_datasets)}")
    print(f"Outputs: {out}")
    print("Friedman:")
    print(f"- ROC AUC: {friedman_report['roc_auc']}")
    print(f"- PR AUC:  {friedman_report['pr_auc']}")


if __name__ == "__main__":
    main()
