# DTI-ALPS Analysis – Command Cheatsheet

## 1. 手动画 ALPS ROI

批量进入 ROI 工作流，每个 subject 默认打开 `z=46`：

```bash
bash "/home/gfk8453/Desktop/DTI analysis/Ann_Data/code/draw_alps_roi_final_z46.sh"
```

每个 subject 保存 4 个 ROI：

```text
proj_R.mif
assoc_R.mif
proj_L.mif
assoc_L.mif
```

保存位置：

```text
/home/gfk8453/Desktop/DTI analysis/Ann_Data/results/<SUBJECT>/05_roi/
```

ROI 方向原则：

```text
Projection ROI:
Dzz > Dxx and Dzz > Dyy

Association ROI:
Dyy > Dxx and Dyy > Dzz
```

---

## 2. 查看某个 subject 的 DEC

例如 `AGUE80`：

```bash
mrview "/home/gfk8453/Desktop/DTI analysis/Ann_Data/results/AGUE80/04_alps_pre/DEC.mif" \
-voxel 65,65,46
```

例如 `AGRJ67`：

```bash
mrview "/home/gfk8453/Desktop/DTI analysis/Ann_Data/results/AGRJ67/04_alps_pre/DEC.mif" \
-voxel 65,65,46
```

---

## 3. 查看 DEC + 4 个 ROI

例如 `AGRJ67`：

```bash
mrview "/home/gfk8453/Desktop/DTI analysis/Ann_Data/results/AGRJ67/04_alps_pre/DEC.mif" \
-roi.load "/home/gfk8453/Desktop/DTI analysis/Ann_Data/results/AGRJ67/05_roi/proj_R.mif" \
-roi.load "/home/gfk8453/Desktop/DTI analysis/Ann_Data/results/AGRJ67/05_roi/assoc_R.mif" \
-roi.load "/home/gfk8453/Desktop/DTI analysis/Ann_Data/results/AGRJ67/05_roi/proj_L.mif" \
-roi.load "/home/gfk8453/Desktop/DTI analysis/Ann_Data/results/AGRJ67/05_roi/assoc_L.mif"
```

---

## 4. 查看单个 ROI voxel 数

例如 `AGRJ67` 的 `proj_R`：

```bash
mrstats "/home/gfk8453/Desktop/DTI analysis/Ann_Data/results/AGRJ67/05_roi/proj_R.mif" \
-mask "/home/gfk8453/Desktop/DTI analysis/Ann_Data/results/AGRJ67/05_roi/proj_R.mif" \
-output count
```

例如查看 `assoc_R`：

```bash
mrstats "/home/gfk8453/Desktop/DTI analysis/Ann_Data/results/AGRJ67/05_roi/assoc_R.mif" \
-mask "/home/gfk8453/Desktop/DTI analysis/Ann_Data/results/AGRJ67/05_roi/assoc_R.mif" \
-output count
```

---

## 5. 查看某个 ROI 的 Dxx / Dyy / Dzz

例如检查 `AGRJ67` 的 `proj_R`：

```bash
for m in Dxx Dyy Dzz; do
    echo -n "$m = "
    mrstats "/home/gfk8453/Desktop/DTI analysis/Ann_Data/results/AGRJ67/04_alps_pre/${m}.mif" \
    -mask "/home/gfk8453/Desktop/DTI analysis/Ann_Data/results/AGRJ67/05_roi/proj_R.mif" \
    -output mean
done
```

Projection 应满足：

```text
Dzz > Dxx
Dzz > Dyy
```

检查 `assoc_R`：

```bash
for m in Dxx Dyy Dzz; do
    echo -n "$m = "
    mrstats "/home/gfk8453/Desktop/DTI analysis/Ann_Data/results/AGRJ67/04_alps_pre/${m}.mif" \
    -mask "/home/gfk8453/Desktop/DTI analysis/Ann_Data/results/AGRJ67/05_roi/assoc_R.mif" \
    -output mean
done
```

Association 应满足：

```text
Dyy > Dxx
Dyy > Dzz
```

---

## 6. 批量 ROI QC

运行最新版 QC：

```bash
python3 "/home/gfk8453/Desktop/DTI analysis/Ann_Data/code/01_qc_alps_rois_v3_spatial_geometry.py"
```

输出：

```text
/home/gfk8453/Desktop/DTI analysis/Ann_Data/results/alps_roi_qc.csv
```

QC 包括：

```text
geometry_qc
same_slice_qc
roi_overlap_qc
position_qc
value_qc
direction_qc
overall_qc
```

ROI 中心坐标沿 MRtrix x 轴应满足：

```text
assoc_L < proj_L < proj_R < assoc_R
```

MRView radiological display 中，屏幕从左到右则是：

```text
assoc_R → proj_R → proj_L → assoc_L
```

---

## 7. 查看 QC 结果

直接打开 QC CSV：

```bash
xdg-open "/home/gfk8453/Desktop/DTI analysis/Ann_Data/results/alps_roi_qc.csv"
```

命令行查看：

```bash
column -s, -t < "/home/gfk8453/Desktop/DTI analysis/Ann_Data/results/alps_roi_qc.csv" | less -S
```

退出：

```text
q
```

查找所有包含 FAIL 的记录：

```bash
grep ",FAIL," "/home/gfk8453/Desktop/DTI analysis/Ann_Data/results/alps_roi_qc.csv"
```

---

## 8. 批量计算 ALPS + 写入 Excel

先运行 ROI QC：

```bash
python3 "/home/gfk8453/Desktop/DTI analysis/Ann_Data/code/01_qc_alps_rois_v3_spatial_geometry.py"
```

然后计算 ALPS 并写入 Excel：

```bash
python3 "/home/gfk8453/Desktop/DTI analysis/Ann_Data/code/02_calculate_alps_to_excel.py"
```

ALPS 公式：

```text
ALPS_R =
(Dxx_proj_R + Dxx_assoc_R) /
(Dyy_proj_R + Dzz_assoc_R)

ALPS_L =
(Dxx_proj_L + Dxx_assoc_L) /
(Dyy_proj_L + Dzz_assoc_L)

ALPS_mean =
(ALPS_R + ALPS_L) / 2
```

结果写入：

```text
/home/gfk8453/Desktop/DTI analysis/Ann_Data/results/ACE study groups demos.xlsx
```

详细左右 ALPS 结果：

```text
/home/gfk8453/Desktop/DTI analysis/Ann_Data/results/alps_results_detailed.csv
```

扫描对应关系：

```text
SUBJECT      → TIME 1
SUBJECT_1    → TIME 1
SUBJECT_2    → TIME 2
```

例如：

```text
AGRJ67   → TIME 1 / AGRJ67
AGRJ67_2 → TIME 2 / AGRJ67
```

---

## 9. 单独计算一个 subject 的 ALPS

例如 `AGRJ67`：

```bash
SUBJ="AGRJ67"
ROOT="/home/gfk8453/Desktop/DTI analysis/Ann_Data/results"

DXX="$ROOT/$SUBJ/04_alps_pre/Dxx.mif"
DYY="$ROOT/$SUBJ/04_alps_pre/Dyy.mif"
DZZ="$ROOT/$SUBJ/04_alps_pre/Dzz.mif"
ROI="$ROOT/$SUBJ/05_roi"

Dxx_proj_R=$(mrstats "$DXX" -mask "$ROI/proj_R.mif" -output mean -quiet | tr -d '[:space:]')
Dyy_proj_R=$(mrstats "$DYY" -mask "$ROI/proj_R.mif" -output mean -quiet | tr -d '[:space:]')
Dxx_assoc_R=$(mrstats "$DXX" -mask "$ROI/assoc_R.mif" -output mean -quiet | tr -d '[:space:]')
Dzz_assoc_R=$(mrstats "$DZZ" -mask "$ROI/assoc_R.mif" -output mean -quiet | tr -d '[:space:]')

Dxx_proj_L=$(mrstats "$DXX" -mask "$ROI/proj_L.mif" -output mean -quiet | tr -d '[:space:]')
Dyy_proj_L=$(mrstats "$DYY" -mask "$ROI/proj_L.mif" -output mean -quiet | tr -d '[:space:]')
Dxx_assoc_L=$(mrstats "$DXX" -mask "$ROI/assoc_L.mif" -output mean -quiet | tr -d '[:space:]')
Dzz_assoc_L=$(mrstats "$DZZ" -mask "$ROI/assoc_L.mif" -output mean -quiet | tr -d '[:space:]')

ALPS_R=$(awk -v a="$Dxx_proj_R" -v b="$Dxx_assoc_R" -v c="$Dyy_proj_R" -v d="$Dzz_assoc_R" \
'BEGIN{printf "%.6f",(a+b)/(c+d)}')

ALPS_L=$(awk -v a="$Dxx_proj_L" -v b="$Dxx_assoc_L" -v c="$Dyy_proj_L" -v d="$Dzz_assoc_L" \
'BEGIN{printf "%.6f",(a+b)/(c+d)}')

ALPS_MEAN=$(awk -v l="$ALPS_L" -v r="$ALPS_R" \
'BEGIN{printf "%.6f",(l+r)/2}')

echo "ALPS_R    = $ALPS_R"
echo "ALPS_L    = $ALPS_L"
echo "ALPS_mean = $ALPS_MEAN"
```

---

## 10. HIV vs NC ALPS 比较

TIME 1 和 TIME 2 分开分析：

```bash
python3 "/home/gfk8453/Desktop/DTI analysis/Ann_Data/code/03_compare_hiv_nc_alps.py"
```

输出目录：

```text
/home/gfk8453/Desktop/DTI analysis/Ann_Data/results/ALPS_HIV_vs_NC/
```

包含：

```text
TIME1_ALPS_HIV_vs_NC.png
TIME1_ALPS_HIV_vs_NC.svg

TIME2_ALPS_HIV_vs_NC.png
TIME2_ALPS_HIV_vs_NC.svg

ALPS_HIV_vs_NC_stats.csv
```

打开结果目录：

```bash
xdg-open "/home/gfk8453/Desktop/DTI analysis/Ann_Data/results/ALPS_HIV_vs_NC"
```

---

## 11. 查看常规 DTI maps

### FA

```bash
mrview "/home/gfk8453/Desktop/DTI analysis/Ann_Data/results/AGUE80/03_metrics/FA.mif"
```

### MD

```bash
mrview "/home/gfk8453/Desktop/DTI analysis/Ann_Data/results/AGUE80/03_metrics/MD.mif"
```

### AD

```bash
mrview "/home/gfk8453/Desktop/DTI analysis/Ann_Data/results/AGUE80/03_metrics/AD.mif"
```

### RD

```bash
mrview "/home/gfk8453/Desktop/DTI analysis/Ann_Data/results/AGUE80/03_metrics/RD.mif"
```

---

## 12. 查看 Dxx / Dyy / Dzz

### Dxx

```bash
mrview "/home/gfk8453/Desktop/DTI analysis/Ann_Data/results/AGUE80/04_alps_pre/Dxx.mif"
```

### Dyy

```bash
mrview "/home/gfk8453/Desktop/DTI analysis/Ann_Data/results/AGUE80/04_alps_pre/Dyy.mif"
```

### Dzz

```bash
mrview "/home/gfk8453/Desktop/DTI analysis/Ann_Data/results/AGUE80/04_alps_pre/Dzz.mif"
```

方向定义：

```text
Dxx = Left–Right
Dyy = Anterior–Posterior
Dzz = Superior–Inferior
```

DEC 颜色：

```text
Red   = x = LR
Green = y = AP
Blue  = z = SI
```

---

## 13. 查看 mean b0

```bash
mrview "/home/gfk8453/Desktop/DTI analysis/Ann_Data/results/AGUE80/01_preproc/mean_b0.mif"
```

mean b0 + brain mask：

```bash
mrview "/home/gfk8453/Desktop/DTI analysis/Ann_Data/results/AGUE80/01_preproc/mean_b0.mif" \
-overlay.load "/home/gfk8453/Desktop/DTI analysis/Ann_Data/results/AGUE80/01_preproc/mask.mif"
```

---

## 14. 查看结果 Excel

```bash
xdg-open "/home/gfk8453/Desktop/DTI analysis/Ann_Data/results/ACE study groups demos.xlsx"
```

---

## 15. 查看详细 ALPS CSV

```bash
xdg-open "/home/gfk8453/Desktop/DTI analysis/Ann_Data/results/alps_results_detailed.csv"
```

---

## 16. 查看当前已经完成 ROI 的 subject 数量

```bash
for d in "/home/gfk8453/Desktop/DTI analysis/Ann_Data/results"/*; do
    [ -d "$d" ] || continue
    ok=1
    for r in proj_R assoc_R proj_L assoc_L; do
        f="$d/05_roi/${r}.mif"
        [ -f "$f" ] || { ok=0; break; }
        n=$(mrstats "$f" -mask "$f" -output count -quiet 2>/dev/null | tr -d '[:space:]')
        [ -n "$n" ] && [ "${n%.*}" -gt 0 ] || { ok=0; break; }
    done
    [ "$ok" -eq 1 ] && basename "$d"
done
```

只统计人数：

```bash
for d in "/home/gfk8453/Desktop/DTI analysis/Ann_Data/results"/*; do
    [ -d "$d" ] || continue
    ok=1
    for r in proj_R assoc_R proj_L assoc_L; do
        f="$d/05_roi/${r}.mif"
        [ -f "$f" ] || { ok=0; break; }
        n=$(mrstats "$f" -mask "$f" -output count -quiet 2>/dev/null | tr -d '[:space:]')
        [ -n "$n" ] && [ "${n%.*}" -gt 0 ] || { ok=0; break; }
    done
    [ "$ok" -eq 1 ] && basename "$d"
done | wc -l
```

---

# Recommended Workflow

```text
Raw DTI
   ↓
Preprocessing
   ↓
Tensor fitting
   ↓
FA / MD / AD / RD
   ↓
Dxx / Dyy / Dzz
   ↓
DEC
   ↓
Manual ROI drawing
   ↓
ROI QC
   ↓
ALPS calculation
   ↓
Write Excel
   ↓
HIV vs NC analysis
```

## 核心运行顺序

### 1. Draw ROI

```bash
bash "/home/gfk8453/Desktop/DTI analysis/Ann_Data/code/draw_alps_roi_final_z46.sh"
```

### 2. ROI QC

```bash
python3 "/home/gfk8453/Desktop/DTI analysis/Ann_Data/code/01_qc_alps_rois_v3_spatial_geometry.py"
```

### 3. Calculate ALPS + update Excel

```bash
python3 "/home/gfk8453/Desktop/DTI analysis/Ann_Data/code/02_calculate_alps_to_excel.py"
```

### 4. HIV vs NC analysis + figures

```bash
python3 "/home/gfk8453/Desktop/DTI analysis/Ann_Data/code/03_compare_hiv_nc_alps.py"
```
