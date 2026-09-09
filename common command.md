# DTI-ALPS Analysis – Command Cheatsheet

---

## 1. 手动画 ALPS ROI

批量进入 ROI 工作流，每个 subject 默认打开 `z=46`：

```bash
bash "/home/gfk8453/Desktop/DTI analysis/Ann_Data/code/draw_alps_roi.sh"
```

每个 subject 保存：

```text
proj_R.mif
assoc_R.mif
proj_L.mif
assoc_L.mif
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

只需要修改第一行：

```bash
sub="AGRJ67"

mrview "/home/gfk8453/Desktop/DTI analysis/Ann_Data/results/$sub/04_alps_pre/DEC.mif" \
-voxel 65,65,46
```

---

## 3. 查看 DEC + 4 个 ROI

```bash
sub="AGRJ67"

mrview "/home/gfk8453/Desktop/DTI analysis/Ann_Data/results/$sub/04_alps_pre/DEC.mif" \
-roi.load "/home/gfk8453/Desktop/DTI analysis/Ann_Data/results/$sub/05_roi/proj_R.mif" \
-roi.load "/home/gfk8453/Desktop/DTI analysis/Ann_Data/results/$sub/05_roi/assoc_R.mif" \
-roi.load "/home/gfk8453/Desktop/DTI analysis/Ann_Data/results/$sub/05_roi/proj_L.mif" \
-roi.load "/home/gfk8453/Desktop/DTI analysis/Ann_Data/results/$sub/05_roi/assoc_L.mif"
```

---

## 4. 查看单个 ROI voxel 数

### proj_R

```bash
sub="AGRJ67"

mrstats "/home/gfk8453/Desktop/DTI analysis/Ann_Data/results/$sub/05_roi/proj_R.mif" \
-mask "/home/gfk8453/Desktop/DTI analysis/Ann_Data/results/$sub/05_roi/proj_R.mif" \
-output count
```

### assoc_R

```bash
sub="AGRJ67"

mrstats "/home/gfk8453/Desktop/DTI analysis/Ann_Data/results/$sub/05_roi/assoc_R.mif" \
-mask "/home/gfk8453/Desktop/DTI analysis/Ann_Data/results/$sub/05_roi/assoc_R.mif" \
-output count
```

### proj_L

```bash
sub="AGRJ67"

mrstats "/home/gfk8453/Desktop/DTI analysis/Ann_Data/results/$sub/05_roi/proj_L.mif" \
-mask "/home/gfk8453/Desktop/DTI analysis/Ann_Data/results/$sub/05_roi/proj_L.mif" \
-output count
```

### assoc_L

```bash
sub="AGRJ67"

mrstats "/home/gfk8453/Desktop/DTI analysis/Ann_Data/results/$sub/05_roi/assoc_L.mif" \
-mask "/home/gfk8453/Desktop/DTI analysis/Ann_Data/results/$sub/05_roi/assoc_L.mif" \
-output count
```

---

## 5. 查看某个 ROI 的 Dxx / Dyy / Dzz

### Projection Right

```bash
sub="AGRJ67"
roi="proj_R"

for m in Dxx Dyy Dzz; do
    echo -n "$m = "
    mrstats "/home/gfk8453/Desktop/DTI analysis/Ann_Data/results/$sub/04_alps_pre/${m}.mif" \
    -mask "/home/gfk8453/Desktop/DTI analysis/Ann_Data/results/$sub/05_roi/${roi}.mif" \
    -output mean
done
```

应满足：

```text
Dzz > Dxx
Dzz > Dyy
```

### Association Right

```bash
sub="AGRJ67"
roi="assoc_R"

for m in Dxx Dyy Dzz; do
    echo -n "$m = "
    mrstats "/home/gfk8453/Desktop/DTI analysis/Ann_Data/results/$sub/04_alps_pre/${m}.mif" \
    -mask "/home/gfk8453/Desktop/DTI analysis/Ann_Data/results/$sub/05_roi/${roi}.mif" \
    -output mean
done
```

应满足：

```text
Dyy > Dxx
Dyy > Dzz
```

### Projection Left

```bash
sub="AGRJ67"
roi="proj_L"

for m in Dxx Dyy Dzz; do
    echo -n "$m = "
    mrstats "/home/gfk8453/Desktop/DTI analysis/Ann_Data/results/$sub/04_alps_pre/${m}.mif" \
    -mask "/home/gfk8453/Desktop/DTI analysis/Ann_Data/results/$sub/05_roi/${roi}.mif" \
    -output mean
done
```

应满足：

```text
Dzz > Dxx
Dzz > Dyy
```

### Association Left

```bash
sub="AGRJ67"
roi="assoc_L"

for m in Dxx Dyy Dzz; do
    echo -n "$m = "
    mrstats "/home/gfk8453/Desktop/DTI analysis/Ann_Data/results/$sub/04_alps_pre/${m}.mif" \
    -mask "/home/gfk8453/Desktop/DTI analysis/Ann_Data/results/$sub/05_roi/${roi}.mif" \
    -output mean
done
```

应满足：

```text
Dyy > Dxx
Dyy > Dzz
```

---

## 6. 批量 ROI QC

```bash
python3 "/home/gfk8453/Desktop/DTI analysis/Ann_Data/code/01_qc_alps_rois_v3_spatial_geometry.py"
```

输出：

```text
/home/gfk8453/Desktop/DTI analysis/Ann_Data/results/alps_roi_qc.csv
```

QC：

```text
geometry_qc
same_slice_qc
roi_overlap_qc
position_qc
value_qc
direction_qc
overall_qc
```

ROI x 坐标顺序：

```text
assoc_L < proj_L < proj_R < assoc_R
```

MRView radiological display 屏幕从左到右：

```text
assoc_R → proj_R → proj_L → assoc_L
```

---

## 7. 查看 QC 结果

```bash
xdg-open "/home/gfk8453/Desktop/DTI analysis/Ann_Data/results/alps_roi_qc.csv"
```

命令行查看：

```bash
column -s, -t < "/home/gfk8453/Desktop/DTI analysis/Ann_Data/results/alps_roi_qc.csv" | less -S
```

查找 FAIL：

```bash
grep ",FAIL," "/home/gfk8453/Desktop/DTI analysis/Ann_Data/results/alps_roi_qc.csv"
```

---

## 8. 批量计算 ALPS + 写入 Excel

先 QC：

```bash
python3 "/home/gfk8453/Desktop/DTI analysis/Ann_Data/code/01_qc_alps_rois_v3_spatial_geometry.py"
```

再计算：

```bash
python3 "/home/gfk8453/Desktop/DTI analysis/Ann_Data/code/02_calculate_alps_to_excel.py"
```

公式：

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

Excel：

```text
/home/gfk8453/Desktop/DTI analysis/Ann_Data/results/ACE study groups demos.xlsx
```

详细结果：

```text
/home/gfk8453/Desktop/DTI analysis/Ann_Data/results/alps_results_detailed.csv
```

---

## 9. 单独计算一个 subject 的 ALPS

只改第一行：

```bash
sub="AGRJ67"

DXX="/home/gfk8453/Desktop/DTI analysis/Ann_Data/results/$sub/04_alps_pre/Dxx.mif"
DYY="/home/gfk8453/Desktop/DTI analysis/Ann_Data/results/$sub/04_alps_pre/Dyy.mif"
DZZ="/home/gfk8453/Desktop/DTI analysis/Ann_Data/results/$sub/04_alps_pre/Dzz.mif"
ROI="/home/gfk8453/Desktop/DTI analysis/Ann_Data/results/$sub/05_roi"

Dxx_proj_R=$(mrstats "$DXX" -mask "$ROI/proj_R.mif" -output mean -quiet | tr -d '[:space:]')
Dyy_proj_R=$(mrstats "$DYY" -mask "$ROI/proj_R.mif" -output mean -quiet | tr -d '[:space:]')
Dxx_assoc_R=$(mrstats "$DXX" -mask "$ROI/assoc_R.mif" -output mean -quiet | tr -d '[:space:]')
Dzz_assoc_R=$(mrstats "$DZZ" -mask "$ROI/assoc_R.mif" -output mean -quiet | tr -d '[:space:]')

Dxx_proj_L=$(mrstats "$DXX" -mask "$ROI/proj_L.mif" -output mean -quiet | tr -d '[:space:]')
Dyy_proj_L=$(mrstats "$DYY" -mask "$ROI/proj_L.mif" -output mean -quiet | tr -d '[:space:]')
Dxx_assoc_L=$(mrstats "$DXX" -mask "$ROI/assoc_L.mif" -output mean -quiet | tr -d '[:space:]')
Dzz_assoc_L=$(mrstats "$DZZ" -mask "$ROI/assoc_L.mif" -output mean -quiet | tr -d '[:space:]')

ALPS_R=$(awk \
-v a="$Dxx_proj_R" \
-v b="$Dxx_assoc_R" \
-v c="$Dyy_proj_R" \
-v d="$Dzz_assoc_R" \
'BEGIN{printf "%.6f",(a+b)/(c+d)}')

ALPS_L=$(awk \
-v a="$Dxx_proj_L" \
-v b="$Dxx_assoc_L" \
-v c="$Dyy_proj_L" \
-v d="$Dzz_assoc_L" \
'BEGIN{printf "%.6f",(a+b)/(c+d)}')

ALPS_MEAN=$(awk \
-v l="$ALPS_L" \
-v r="$ALPS_R" \
'BEGIN{printf "%.6f",(l+r)/2}')

echo
echo "============================"
echo "Subject   = $sub"
echo "ALPS_R    = $ALPS_R"
echo "ALPS_L    = $ALPS_L"
echo "ALPS_mean = $ALPS_MEAN"
echo "============================"
```

---

## 10. HIV vs NC ALPS 比较

```bash
python3 "/home/gfk8453/Desktop/DTI analysis/Ann_Data/code/03_compare_hiv_nc_alps.py"
```

打开结果：

```bash
xdg-open "/home/gfk8453/Desktop/DTI analysis/Ann_Data/results/ALPS_HIV_vs_NC"
```

---

## 11. 查看 FA

```bash
sub="AGRJ67"

mrview "/home/gfk8453/Desktop/DTI analysis/Ann_Data/results/$sub/03_metrics/FA.mif"
```

---

## 12. 查看 MD

```bash
sub="AGRJ67"

mrview "/home/gfk8453/Desktop/DTI analysis/Ann_Data/results/$sub/03_metrics/MD.mif"
```

---

## 13. 查看 AD

```bash
sub="AGRJ67"

mrview "/home/gfk8453/Desktop/DTI analysis/Ann_Data/results/$sub/03_metrics/AD.mif"
```

---

## 14. 查看 RD

```bash
sub="AGRJ67"

mrview "/home/gfk8453/Desktop/DTI analysis/Ann_Data/results/$sub/03_metrics/RD.mif"
```

---

## 15. 查看 Dxx

```bash
sub="AGRJ67"

mrview "/home/gfk8453/Desktop/DTI analysis/Ann_Data/results/$sub/04_alps_pre/Dxx.mif"
```

---

## 16. 查看 Dyy

```bash
sub="AGRJ67"

mrview "/home/gfk8453/Desktop/DTI analysis/Ann_Data/results/$sub/04_alps_pre/Dyy.mif"
```

---

## 17. 查看 Dzz

```bash
sub="AGRJ67"

mrview "/home/gfk8453/Desktop/DTI analysis/Ann_Data/results/$sub/04_alps_pre/Dzz.mif"
```

方向：

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

## 18. 查看 mean b0

```bash
sub="AGRJ67"

mrview "/home/gfk8453/Desktop/DTI analysis/Ann_Data/results/$sub/01_preproc/mean_b0.mif"
```

---

## 19. 查看 mean b0 + mask

```bash
sub="AGRJ67"

mrview "/home/gfk8453/Desktop/DTI analysis/Ann_Data/results/$sub/01_preproc/mean_b0.mif" \
-overlay.load "/home/gfk8453/Desktop/DTI analysis/Ann_Data/results/$sub/01_preproc/mask.mif"
```

---

## 20. 查看某个 subject 的文件

```bash
sub="AGRJ67"

ls -lh "/home/gfk8453/Desktop/DTI analysis/Ann_Data/results/$sub/"
```

查看 preprocessing：

```bash
sub="AGRJ67"

ls -lh "/home/gfk8453/Desktop/DTI analysis/Ann_Data/results/$sub/01_preproc/"
```

查看 metrics：

```bash
sub="AGRJ67"

ls -lh "/home/gfk8453/Desktop/DTI analysis/Ann_Data/results/$sub/03_metrics/"
```

查看 ALPS maps：

```bash
sub="AGRJ67"

ls -lh "/home/gfk8453/Desktop/DTI analysis/Ann_Data/results/$sub/04_alps_pre/"
```

查看 ROI：

```bash
sub="AGRJ67"

ls -lh "/home/gfk8453/Desktop/DTI analysis/Ann_Data/results/$sub/05_roi/"
```

---

## 21. 打开某个 subject 的结果文件夹

```bash
sub="AGRJ67"

xdg-open "/home/gfk8453/Desktop/DTI analysis/Ann_Data/results/$sub"
```

---

## 22. 查看结果 Excel

```bash
xdg-open "/home/gfk8453/Desktop/DTI analysis/Ann_Data/results/ACE study groups demos.xlsx"
```

---

## 23. 查看 ALPS detailed CSV

```bash
xdg-open "/home/gfk8453/Desktop/DTI analysis/Ann_Data/results/alps_results_detailed.csv"
```

---

# Core Workflow

## 1. Draw ROI

```bash
bash "/home/gfk8453/Desktop/DTI analysis/Ann_Data/code/draw_alps_roi_final_z46.sh"
```

## 2. QC

```bash
python3 "/home/gfk8453/Desktop/DTI analysis/Ann_Data/code/01_qc_alps_rois_v3_spatial_geometry.py"
```

## 3. Calculate ALPS + update Excel

```bash
python3 "/home/gfk8453/Desktop/DTI analysis/Ann_Data/code/02_calculate_alps_to_excel.py"
```

## 4. HIV vs NC analysis

```bash
python3 "/home/gfk8453/Desktop/DTI analysis/Ann_Data/code/03_compare_hiv_nc_alps.py"
```
