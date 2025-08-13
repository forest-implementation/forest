#!/usr/bin/env python3
"""
Usage:
  python viz_novelty.py \
    --roc_dir csv/roc_curves \
    --confusion_dir csv/confusion \
    --auc_dir csv/auc \
    --out_dir out/elixir \
    --algo_name elixir \
    --select_by youden

Notes
- Expects per-dataset CSV files:
  * ROC:        csv/roc_curves/<dataset>.csv with header: threshold,fpr,tpr
  * Confusion:  csv/confusion/<dataset>.csv with header: threshold,tp,fp,fn,tn,tpr,fpr,precision,recall,f1
  * AUC:        csv/auc/<dataset>.csv with header: auc (optional; we recompute from ROC anyway)
- Produces per-dataset figures and a summary CSV.
- If later you run this for other algorithms, just change --out_dir and --algo_name.
"""

import argparse
import os
import glob
from typing import Tuple, Dict
import pandas as pd
import numpy as np
import matplotlib.pyplot as plt
from sklearn.metrics import confusion_matrix, ConfusionMatrixDisplay

# -------------------------------
# Helpers
# -------------------------------

def ensure_dir(path: str):
    os.makedirs(path, exist_ok=True)


def load_datasets(roc_dir: str) -> Dict[str, str]:
    """Return mapping dataset_name -> roc_csv_path."""
    paths = glob.glob(os.path.join(roc_dir, '*.csv'))
    datasets = {}
    for p in paths:
        name = os.path.splitext(os.path.basename(p))[0]
        datasets[name] = p
    return dict(sorted(datasets.items(), key=lambda kv: kv[0]))


def compute_auc_from_roc(df_roc: pd.DataFrame) -> float:
    # Ensure sorted by FPR and include (0,0) and (1,1) sentinels if missing
    df = df_roc[['fpr','tpr']].dropna().sort_values('fpr')
    if len(df) == 0:
        return float('nan')
    if df.iloc[0]['fpr'] > 0 or df.iloc[0]['tpr'] > 0:
        df = pd.concat([pd.DataFrame({'fpr':[0.0],'tpr':[0.0]}), df], ignore_index=True)
    if df.iloc[-1]['fpr'] < 1 or df.iloc[-1]['tpr'] < 1:
        df = pd.concat([df, pd.DataFrame({'fpr':[1.0],'tpr':[1.0]})], ignore_index=True)
    fpr = df['fpr'].values
    tpr = df['tpr'].values
    # Trapezoidal rule
    return np.trapz(y=tpr, x=fpr)


def pick_threshold(df_conf: pd.DataFrame, how: str) -> pd.Series:
    """Return row of df_conf for chosen threshold. how in {youden, f1, recall_at_fprXX}
    - youden: maximize TPR - FPR
    - f1: maximize F1
    - recall_at_fprXX: e.g. recall_at_fpr05 means fpr<=0.05 and max recall
    """
    how = how.lower()
    if how == 'youden':
        idx = (df_conf['tpr'] - df_conf['fpr']).astype(float).idxmax()
        return df_conf.loc[idx]
    if how == 'f1':
        idx = df_conf['f1'].astype(float).idxmax()
        return df_conf.loc[idx]
    if how.startswith('recall_at_fpr'):
        # parse XX (percent)
        tail = how.replace('recall_at_fpr', '')
        try:
            max_fpr = float(tail) / 100.0
        except Exception:
            max_fpr = 0.05
        cand = df_conf[df_conf['fpr'].astype(float) <= max_fpr]
        if len(cand) == 0:
            # fallback: minimal fpr
            min_idx = df_conf['fpr'].astype(float).idxmin()
            return df_conf.loc[min_idx]
        idx = cand['tpr'].astype(float).idxmax()
        return df_conf.loc[idx]
    raise ValueError(f"Unknown selection criterion: {how}")


def plot_roc(df_roc: pd.DataFrame, title: str, out_path: str, auc_value: float):
    df = df_roc[['fpr','tpr']].astype(float).sort_values('fpr')
    plt.figure()
    plt.plot(df['fpr'].values, df['tpr'].values, label=f"AUC={auc_value:.3f}")
    plt.plot([0,1],[0,1], linestyle='--')  # diagonal baseline
    plt.xlabel('False Positive Rate')
    plt.ylabel('True Positive Rate (Recall)')
    plt.title(title)
    plt.legend(loc='lower right')
    plt.tight_layout()
    plt.savefig(out_path, dpi=160)
    plt.close()


def plot_confusion(tp: int, fp: int, fn: int, tn: int, title: str, out_path: str):
    # Construct explicit matrix [[TN, FP],[FN, TP]] per sklearn expectation
    cm = np.array([[tn, fp], [fn, tp]], dtype=int)
    disp = ConfusionMatrixDisplay(confusion_matrix=cm, display_labels=['Regular','Novelty'])
    fig, ax = plt.subplots()
    disp.plot(ax=ax, colorbar=False)
    ax.set_title(title)
    plt.tight_layout()
    plt.savefig(out_path, dpi=160)
    plt.close()


# -------------------------------
# Main
# -------------------------------

def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('--roc_dir', required=True)
    ap.add_argument('--confusion_dir', required=True)
    ap.add_argument('--auc_dir', required=False)
    ap.add_argument('--out_dir', required=True)
    ap.add_argument('--algo_name', default='algo')
    ap.add_argument('--select_by', default='youden',
                    help='youden | f1 | recall_at_fpr05 (or another XX)')
    args = ap.parse_args()

    ensure_dir(args.out_dir)
    roc_out = os.path.join(args.out_dir, 'roc')
    cm_out  = os.path.join(args.out_dir, 'confusion')
    ensure_dir(roc_out)
    ensure_dir(cm_out)

    datasets = load_datasets(args.roc_dir)
    summary_rows = []

    for ds, roc_csv in datasets.items():
        # --- Load ROC ---
        df_roc = pd.read_csv(roc_csv)
        if not {'fpr','tpr'}.issubset(df_roc.columns):
            raise RuntimeError(f"ROC CSV {roc_csv} must contain columns 'fpr','tpr'")
        auc_val = compute_auc_from_roc(df_roc)

        # Plot ROC
        plot_roc(df_roc, title=f"ROC — {args.algo_name} — {ds}",
                 out_path=os.path.join(roc_out, f"{ds}.png"), auc_value=auc_val)

        # --- Load confusion per threshold ---
        conf_csv = os.path.join(args.confusion_dir, f"{ds}.csv")
        if os.path.exists(conf_csv):
            df_conf = pd.read_csv(conf_csv)
            required = {'threshold','tp','fp','fn','tn','tpr','fpr','precision','recall','f1'}
            if not required.issubset(df_conf.columns):
                raise RuntimeError(f"Confusion CSV {conf_csv} missing required columns: {required - set(df_conf.columns)}")
            row = pick_threshold(df_conf, args.select_by)
            tp, fp, fn, tn = int(row['tp']), int(row['fp']), int(row['fn']), int(row['tn'])
            thr = float(row['threshold'])
            f1  = float(row['f1'])
            tpr = float(row['tpr'])
            fpr = float(row['fpr'])

            # Plot confusion matrix
            plot_confusion(tp, fp, fn, tn,
                           title=f"Confusion @ {args.select_by} (thr={thr:.4f}) — {args.algo_name} — {ds}",
                           out_path=os.path.join(cm_out, f"{ds}.png"))

            summary_rows.append({
                'dataset': ds,
                'algo': args.algo_name,
                'auc': auc_val,
                'selected_by': args.select_by,
                'threshold': thr,
                'tp': tp, 'fp': fp, 'fn': fn, 'tn': tn,
                'tpr': tpr, 'fpr': fpr,
                'precision': float(row['precision']),
                'recall': float(row['recall']),
                'f1': f1,
            })
        else:
            # No confusion CSV; still add summary with AUC only
            summary_rows.append({
                'dataset': ds,
                'algo': args.algo_name,
                'auc': auc_val,
                'selected_by': args.select_by,
                'threshold': np.nan,
                'tp': np.nan, 'fp': np.nan, 'fn': np.nan, 'tn': np.nan,
                'tpr': np.nan, 'fpr': np.nan,
                'precision': np.nan,
                'recall': np.nan,
                'f1': np.nan,
            })

    # Save summary CSV (sorted by dataset)
    df_sum = pd.DataFrame(summary_rows).sort_values(['dataset'])
    df_sum.to_csv(os.path.join(args.out_dir, 'summary.csv'), index=False)

    print(f"Done. Wrote ROC plots to: {roc_out}")
    print(f"Confusion plots to: {cm_out}")
    print(f"Summary CSV: {os.path.join(args.out_dir, 'summary.csv')}")


if __name__ == '__main__':
    main()
