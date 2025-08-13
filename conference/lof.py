#!/usr/bin/env python3
# run_novelty.py
import argparse, os, glob
import numpy as np, pandas as pd

from sklearn.svm import OneClassSVM
from sklearn.neighbors import LocalOutlierFactor
from sklearn.covariance import EllipticEnvelope

# ---------- IO helpers ----------
def ensure_dirs(root):
    os.makedirs(os.path.join(root, "roc_curves"), exist_ok=True)
    os.makedirs(os.path.join(root, "auc"), exist_ok=True)
    os.makedirs(os.path.join(root, "confusion"), exist_ok=True)

def list_names(data_dir, dataset=None):
    # NATVRDO VYNECHAT TYHLE OBŘÍ DATASETY (stejně jako v Elixiru)
    skip_datasets = {"3_backdoor", "9_census"}
    if dataset:
        return [dataset]
    names = sorted([
        os.path.basename(p).replace("_TTV.csv","")
        for p in glob.glob(os.path.join(data_dir, "*_TTV.csv"))
    ])
    names = [n for n in names if n not in skip_datasets]
    return names

def read_nohdr(path): 
    return pd.read_csv(path, header=None)

def split_cols(df, label_col=-2, split_col=-1):
    X = df.drop(df.columns[[label_col, split_col]], axis=1).astype(float).values
    y = df.iloc[:, label_col].values
    s = df.iloc[:, split_col].astype(str).values
    return X, y, s

def preprocess(data_dir, name):
    """Zrcadlí Elixir preprocess: (regular_train, regular_test, novelty_test, dataset_name)."""
    ttv = read_nohdr(os.path.join(data_dir, f"{name}_TTV.csv"))
    tv  = read_nohdr(os.path.join(data_dir, f"{name}_TV.csv"))
    Xttv, yttv, sttv = split_cols(ttv)
    Xtv,  ytv,  stv  = split_cols(tv)

    # TR = jen regular (label==0, pokud labely existují)
    yttv_num = pd.to_numeric(yttv, errors="coerce")
    tr_mask = (sttv == "TR") & (np.nan_to_num(yttv_num, nan=0.0) == 0.0)
    regular_train = Xttv[tr_mask]

    te_reg_mask = (sttv == "TE") & (np.nan_to_num(yttv_num, nan=0.0) == 0.0)
    regular_test = Xttv[te_reg_mask]

    ytv_num = pd.to_numeric(ytv, errors="coerce")
    te_nov_mask = (stv == "TE") & (np.nan_to_num(ytv_num, nan=1.0) == 1.0)
    novelty_test = Xtv[te_nov_mask]

    return regular_train, regular_test, novelty_test, name

# ---------- Metrics ----------
def auc_from_pairs(pairs):
    if not pairs: 
        return float("nan")
    arr = np.array(sorted(pairs, key=lambda x:x[0]), float)
    # přidej sentinely
    if arr[0,0] > 0 or arr[0,1] > 0: 
        arr = np.vstack([[0.0,0.0], arr])
    if arr[-1,0] < 1 or arr[-1,1] < 1: 
        arr = np.vstack([arr, [1.0,1.0]])
    return np.trapz(arr[:,1], arr[:,0])

def build_counts(scores_r, scores_n, thresholds, direction):
    """direction: 'lt' => novelty if score<th, 'gt' => novelty if score>th"""
    nR, nN = len(scores_r), len(scores_n)
    rows=[]
    if direction=='lt':
        cmp_r = lambda th: int((scores_r < th).sum())
        cmp_n = lambda th: int((scores_n < th).sum())
    else:
        cmp_r = lambda th: int((scores_r > th).sum())
        cmp_n = lambda th: int((scores_n > th).sum())
    for th in thresholds:
        fp = cmp_r(th); tp = cmp_n(th)
        fn = nN - tp;   tn = nR - fp
        rows.append((float(th), fp, tp, fn, tn))
    return rows

def counts_to_roc(counts):
    pts=[]
    for th, fp, tp, fn, tn in counts:
        tpr = tp/(tp+fn) if (tp+fn)>0 else 0.0
        fpr = fp/(fp+tn) if (fp+tn)>0 else 0.0
        pts.append((th, fpr, tpr))
    # odstraň duplicitní sousedy (stejné fpr,tpr)
    out=[]
    for th,fpr,tpr in sorted(pts, key=lambda x:x[1]):
        if not out or (out[-1][1]!=fpr or out[-1][2]!=tpr):
            out.append((th,fpr,tpr))
    return out

def save_outputs(name, root, roc_pts, auc_val, counts):
    roc_by_th = sorted(roc_pts, key=lambda x:x[0])   # th, fpr, tpr
    roc_by_fpr= sorted(roc_pts, key=lambda x:x[1])   # fpr
    def dump(path, rows):
        with open(path,"w",encoding="utf-8") as f:
            f.write("threshold,fpr,tpr\n")
            for th,fpr,tpr in rows: 
                f.write(f"{th},{fpr},{tpr}\n")
    dump(os.path.join(root,"roc_curves",f"{name}_by_threshold.csv"), roc_by_th)
    dump(os.path.join(root,"roc_curves",f"{name}_by_fpr.csv"), roc_by_fpr)
    dump(os.path.join(root,"roc_curves",f"{name}.csv"), roc_by_fpr)  # alias pro viz skript

    with open(os.path.join(root,"auc",f"{name}.csv"),"w",encoding="utf-8") as f:
        f.write("auc\n"); f.write(f"{auc_val}\n")

    with open(os.path.join(root,"confusion",f"{name}.csv"),"w",encoding="utf-8") as f:
        f.write("threshold,tp,fp,fn,tn,tpr,fpr,precision,recall,f1\n")
        for th,fp,tp,fn,tn in counts:
            tpr = tp/(tp+fn) if (tp+fn)>0 else 0.0
            fpr = fp/(fp+tn) if (fp+tn)>0 else 0.0
            prec= tp/(tp+fp) if (tp+fp)>0 else 0.0
            rec = tpr
            f1  = (2*prec*rec/(prec+rec)) if (prec+rec)>0 else 0.0
            f.write(f"{th},{tp},{fp},{fn},{tn},{tpr},{fpr},{prec},{rec},{f1}\n")

# ---------- Models ----------
def score_with(method, Xtr, Xr, Xn):
    if method=='ocsvm':
        model = OneClassSVM(kernel='rbf', gamma='scale', nu=0.1)
        model.fit(Xtr)
        # vyšší decision_function => „normálnější“
        return model.decision_function(Xr), model.decision_function(Xn)
    if method=='lof':
        model = LocalOutlierFactor(n_neighbors=35, novelty=True)  # novelty=True je klíčové
        model.fit(Xtr)
        # score_samples: větší ~ normálnější (sklearn to posouvá)
        return model.score_samples(Xr), model.score_samples(Xn)
    if method=='elliptic':
        model = EllipticEnvelope(store_precision=False, support_fraction=None)
        model.fit(Xtr)
        return model.decision_function(Xr), model.decision_function(Xn)
    raise ValueError("Unknown method")

def unique_thresholds(scores_r, scores_n):
    return np.unique(np.concatenate([scores_r, scores_n]))

# ---------- Main experiment ----------
def run_one(method, data_dir, name, out_root):
    Xtr, Xr, Xn, ds = preprocess(data_dir, name)
    if len(Xtr)==0 or len(Xr)==0 or len(Xn)==0:
        print(f"[{name}] WARNING: empty TR/TE split. Skipping.")
        return
    sr, sn = score_with(method, Xtr, Xr, Xn)
    ths = unique_thresholds(sr, sn)

    # obě orientace skóre -> vyber lepší
    counts_lt = build_counts(sr, sn, ths, 'lt')   # novelty if score<th
    roc_lt    = counts_to_roc(counts_lt)
    auc_lt    = auc_from_pairs([(fpr,tpr) for _,fpr,tpr in roc_lt])
 
    counts, roc_pts, auc_val, direction = counts_lt, roc_lt, auc_lt, "score < th"

    print(f"[{method}] {name}: {direction} | AUC={auc_val:.4f} | ths={len(ths)}")
    save_outputs(name, out_root, roc_pts, auc_val, counts)

def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--data_dir", required=True)
    ap.add_argument("--dataset", default=None)
    ap.add_argument("--out_root", default="csv_novelty")
    ap.add_argument("--method", choices=["ocsvm","lof","elliptic"], default="ocsvm")
    args = ap.parse_args()

    # oddělíme výstupy per-metoda: out_root/<method>/
    out_root = os.path.join(args.out_root, args.method)
    ensure_dirs(out_root)

    for name in list_names(args.data_dir, args.dataset):
        run_one(args.method, args.data_dir, name, out_root)

if __name__ == "__main__":
    main()
