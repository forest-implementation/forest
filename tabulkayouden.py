import pandas as pd
import os

summary_folder = "csv/youdens"
rows = []

# Načti všechny summary_* CSV soubory
for file in os.listdir(summary_folder):
    if file.startswith("summary_") and file.endswith(".csv"):
        path = os.path.join(summary_folder, file)
        
        # Opravné načtení jednoho řádku bez hlavičky
        with open(path, "r") as f:
            line = f.readline().strip()
            if line:
                parts = line.split(",")
                if len(parts) == 5:
                    dataset = parts[0]
                    best_threshold = float(parts[1])
                    best_youden = float(parts[2])
                    fixed_threshold = float(parts[3])
                    fixed_youden = float(parts[4])
                    rows.append({
                        "Dataset": dataset,
                        "Best Threshold": best_threshold,
                        "Youden (Best)": best_youden,
                        "Threshold (Fixed)": fixed_threshold,
                        "Youden (Fixed)": fixed_youden
                    })

# Vytvoř DataFrame
df = pd.DataFrame(rows)

# Uložení a zobrazení
df.to_csv("csv/youdens/summary_table.csv", index=False)
print(df)
