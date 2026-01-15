#!/usr/bin/env python3
# -*- coding: utf-8 -*-

import math
import warnings
from pathlib import Path

import numpy as np
import pandas as pd
import matplotlib
import matplotlib.pyplot as plt
from scipy.stats import friedmanchisquare

matplotlib.use("pgf")
matplotlib.rcParams.update({
    "pgf.texsystem": "pdflatex",
    'font.family': 'serif',
    'text.usetex': True,
    'pgf.rcfonts': False,
})


try:
    from scipy.stats import studentized_range
except Exception:
    studentized_range = None


# -----------------------
# I/O
# -----------------------

def find_algorithms(root):
    return sorted(
        [p for p in root.iterdir() if (p / "auc").is_dir()],
        key=lambda x: x.name
    )


def common_datasets(algs):
    sets = []
    for a in algs:
        sets.append({f.name for f in (a / "auc").glob("*.csv")})
    return sorted(set.intersection(*sets))


def read_auc(path):
    """
    Reads auc/<dataset>.csv of form:

    auc
    0.512831184378042
    """
    try:
        df = pd.read_csv(path)
    except Exception as e:
        warnings.warn(f"Cannot read {path}: {e}")
        return None

    if df.empty:
        return None

    # prefer column named auc
    for c in df.columns:
        if c.lower() == "auc":
            v = df[c].iloc[0]
            return float(v) if pd.notna(v) else None

    # fallback: first numeric value
    for c in df.columns:
        if pd.api.types.is_numeric_dtype(df[c]):
            v = df[c].iloc[0]
            return float(v) if pd.notna(v) else None

    return None


# -----------------------
# Stats
# -----------------------

def ranks_from_scores(mat):
    # higher AUC = better → rank 1 = best
    return mat.rank(axis=1, ascending=False, method="average")


def friedman(ranks):
    args = [ranks[c].to_numpy() for c in ranks.columns]
    stat, p = friedmanchisquare(*args)
    return float(stat), float(p)


def nemenyi(avg_ranks, N, alpha=0.05):
    if studentized_range is None:
        raise RuntimeError("Install newer SciPy: pip install -U scipy")

    k = len(avg_ranks)
    se = math.sqrt(k * (k + 1) / (6.0 * N))
    q_alpha = float(studentized_range.ppf(1 - alpha, k, np.inf))
    CD = q_alpha * se

    algs = list(avg_ranks.index)
    pmat = pd.DataFrame(1.0, index=algs, columns=algs)

    for i in range(k):
        for j in range(i + 1, k):
            diff = abs(avg_ranks.iloc[i] - avg_ranks.iloc[j])
            q = diff / se
            p = 1.0 - float(studentized_range.cdf(q, k, np.inf))
            pmat.iloc[i, j] = p
            pmat.iloc[j, i] = p

    return pmat, CD


def plot_cd(avg_ranks, CD, title, path):
    s = avg_ranks.sort_values()  # lower = better
    x = s.values
    names = s.index

    plt.figure(figsize=(10, 2.7))
    plt.scatter(x, np.ones_like(x), s=60)
    plt.hlines(1, x.min(), x.max())

    for xi, name in zip(x, names):
        plt.text(xi, 1.03, name, rotation=30, ha="left", va="bottom")

    x1 = x.max()
    x0 = x1 - CD
    plt.hlines(1.18, x0, x1, linewidth=3)
    plt.vlines([x0, x1], 1.16, 1.20, linewidth=2)
    plt.text((x0 + x1) / 2, 1.205, f"CD = {CD:.3f}", ha="center")

    plt.yticks([])
    plt.xlabel("Average rank (lower is better)")
    plt.title(title)
    plt.ylim(0.9, 1.3)
    plt.tight_layout()
    plt.savefig(path, dpi=200)
    plt.close()


# -----------------------
# Main
# -----------------------

root = Path(".")
out = root / "outputs" / "nemenyi"
out.mkdir(parents=True, exist_ok=True)

algs = find_algorithms(root)
names = [a.name for a in algs]
datasets = common_datasets(algs)

if len(datasets) == 0:
    raise SystemExit("No common datasets in auc/ folders")

# score matrix
A = pd.DataFrame(index=datasets, columns=names)

for a in algs:
    for d in datasets:
        A.loc[d, a.name] = read_auc(a / "auc" / d)

A = A.astype(float)
A = A.dropna(axis=0, how="any")

# ranks
R = ranks_from_scores(A)
avg = R.mean(axis=0)

# Friedman
stat, p = friedman(R)

# Nemenyi
pvals, CD = nemenyi(avg.sort_values(), N=A.shape[0])

# Save
A.to_csv(out / "auc_matrix.csv")
R.to_csv(out / "ranks.csv")
avg.sort_values().to_csv(out / "avg_ranks.csv", header=["avg_rank"])
pvals.to_csv(out / "nemenyi_pvalues.csv")

plot_cd(avg, CD,
        f"Nemenyi CD diagram (ROC AUC), N={A.shape[0]}, k={len(names)}, Friedman p={p:.3g}",
        out / "cd.pdf")

print("Done.")
print("Algorithms:", names)
print("Datasets:", A.shape[0])
print("Friedman: stat =", stat, "p =", p)
print("CD =", CD)
print("Outputs in", out)
