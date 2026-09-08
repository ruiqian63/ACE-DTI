可以，下面这版就是 **GitHub README 风格**，你可以整段复制到 `README.md`。

````markdown
# DTI-ALPS Analysis – Command Cheatsheet

项目路径：

```bash
ROOT="/home/gfk8453/Desktop/DTI analysis/Ann_Data/results"
CODE="/home/gfk8453/Desktop/DTI analysis/Ann_Data/code"
````

---

## 1. 手动画 ALPS ROI

批量进入 ROI 工作流，每个 subject 默认打开 `z=46`：

```bash
bash "$CODE/draw_alps_roi_final_z46.sh"
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
results/<SUBJECT>/05_roi/
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

例如：

```bash
SUBJ="AGUE80"

mrview "$ROOT/$SUBJ/04_alps_pre/DEC.mif" \
-voxel 65,65,46
```

---

## 3. 查看 DEC + 4 个 ROI

```bash
SUBJ="AGUE80"

mrview "$ROOT/$SUBJ/04_alps_pre/DEC.mif" \
-roi.load "$ROOT/$SUBJ/05_roi/proj_R.mif" \
-roi.load "$ROOT/$SUBJ/05_roi/assoc_R.mif" \
-roi.load "$ROOT/$SUBJ/05_roi/proj_L.mif" \
-roi.load "$ROOT/$SUBJ/05_roi/assoc_L.mif"
```

---

## 4. 查看单个 ROI voxel 数

```bash
SUBJ="AGUE80"
ROI="proj_R"

mrstats "$ROOT/$SUBJ/05_roi/${ROI}.mif" \
-mask "$ROOT/$SUBJ/05_roi/${ROI}.mif" \
-output count
```

---

## 5. 查看某个 ROI 的 Dxx / Dyy / Dzz

例如检查 `proj_R`：

```bash
SUBJ="AGUE80"
ROI="proj_R"

for m in Dxx Dyy Dzz; do
    echo -n "$m = "
    mrstats "$ROOT/$SUBJ/04_alps_pre/${m}.mif" \
    -mask "$ROOT/$SUBJ/05_roi/${ROI}.mif" \
    -output mean
done
```

Projection 应满足：

```text
Dzz 最大
```

Association 应满足：

```text
Dyy 最大
```

---

## 6. 批量 ROI QC

运行最新版 QC：

```bash
python3 "$CODE/01_qc_alps_rois_v3_spatial_geometry.py"
```

输出：

```text
results/alps_roi_qc.csv
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

ROI 左右位置中心坐标应满足：

```text
assoc_L < proj_L < proj_R < assoc_R
```

MRView radiological display 中屏幕从左到右则是：

```text
assoc_R → proj_R → proj_L → assoc_L
```

---

## 7. 查看 QC 结果

打开 CSV：

```bash
xdg-open "$ROOT/alps_roi_qc.csv"
```

命令行查看：

```bash
column -s, -t < "$ROOT/alps_roi_qc.csv" | less -S
```

退出：

```text
q
```

查找 FAIL：

```bash
grep ",FAIL," "$ROOT/alps_roi_qc.csv"
```

---

## 8. 批量计算 ALPS + 写入 Excel

先运行 QC，再运行：

```bash
python3 "$CODE/02_calculate_alps_to_excel.py"
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
results/ACE study groups demos.xlsx
```

详细结果：

```text
results/alps_results_detailed.csv
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

## 9. HIV vs NC ALPS 比较

TIME 1 和 TIME 2 分开分析：

```bash
python3 "$CODE/03_compare_hiv_nc_alps.py"
```

输出目录：

```text
results/ALPS_HIV_vs_NC/
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
xdg-open "$ROOT/ALPS_HIV_vs_NC"
```

---

## 10. 查看常规 DTI maps

```bash
SUBJ="AGUE80"

mrview "$ROOT/$SUBJ/03_metrics/FA.mif"
mrview "$ROOT/$SUBJ/03_metrics/MD.mif"
mrview "$ROOT/$SUBJ/03_metrics/AD.mif"
mrview "$ROOT/$SUBJ/03_metrics/RD.mif"
```

---

## 11. 查看 Dxx / Dyy / Dzz

```bash
SUBJ="AGUE80"

mrview "$ROOT/$SUBJ/04_alps_pre/Dxx.mif"
mrview "$ROOT/$SUBJ/04_alps_pre/Dyy.mif"
mrview "$ROOT/$SUBJ/04_alps_pre/Dzz.mif"
```

方向定义：

```text
Dxx = Left–Right
Dyy = Anterior–Posterior
Dzz = Superior–Inferior
```

DEC：

```text
Red   = x = LR
Green = y = AP
Blue  = z = SI
```

---

## 12. 查看 mean b0

```bash
SUBJ="AGUE80"

mrview "$ROOT/$SUBJ/01_preproc/mean_b0.mif"
```

mean b0 + mask：

```bash
mrview "$ROOT/$SUBJ/01_preproc/mean_b0.mif" \
-overlay.load "$ROOT/$SUBJ/01_preproc/mask.mif"
```

---

## 13. 查看结果 Excel

```bash
xdg-open "$ROOT/ACE study groups demos.xlsx"
```

---

## 14. 查看详细 ALPS CSV

```bash
xdg-open "$ROOT/alps_results_detailed.csv"
```

---

# Recommended Workflow

```text
DTI preprocessing
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

核心运行顺序：

```bash
# 1. Draw ROI
bash "$CODE/draw_alps_roi_final_z46.sh"

# 2. QC
python3 "$CODE/01_qc_alps_rois_v3_spatial_geometry.py"

# 3. Calculate ALPS + update Excel
python3 "$CODE/02_calculate_alps_to_excel.py"

# 4. HIV vs NC analysis + figures
python3 "$CODE/03_compare_hiv_nc_alps.py"
```

```
```
