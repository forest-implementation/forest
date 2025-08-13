v csv_baselines jsou csvcka pomoci kterych se daji delat confusion matrices a roc/auc


pro elixir, ten vygeneruje data pomoci:

```
MIX_ENV=example mix run example/adbench_roc_conference.ex
```

python generuje data ze skriptu lof.py (ale ten umi ruzne algoritmy, tak nejak): 

```
python conference/lof.py --data_dir example/data/adbench/csv --method elliptic --out_root conference/csv_baselines
```

no a pak grafy:

python summarize.py   --roc_dir conference/csv_our2/roc_curves   --confusion_dir conference/csv_our2/confusion   --auc_dir conference/csv_our2/auc   --out_dir conference/out/elixir   --algo_name elixir   --select_by youden

pres noc jsem dal spustit csv_baselines generovani csv dat pro ocsvm, kdy to dobehlo tak by to melo byt ve slozce conference/csvbaselines/ocsvm