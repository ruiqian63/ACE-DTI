SUBJ="AGRJ67"
ROOT="/home/gfk8453/Desktop/DTI analysis/Ann_Data/results"

DXX="$ROOT/$SUBJ/04_alps_pre/Dxx.mif"
DYY="$ROOT/$SUBJ/04_alps_pre/Dyy.mif"
DZZ="$ROOT/$SUBJ/04_alps_pre/Dzz.mif"
ROI="$ROOT/$SUBJ/05_roi"

# Right
Dxx_proj_R=$(mrstats "$DXX" -mask "$ROI/proj_R.mif"  -output mean -quiet | tr -d '[:space:]')
Dyy_proj_R=$(mrstats "$DYY" -mask "$ROI/proj_R.mif"  -output mean -quiet | tr -d '[:space:]')
Dxx_assoc_R=$(mrstats "$DXX" -mask "$ROI/assoc_R.mif" -output mean -quiet | tr -d '[:space:]')
Dzz_assoc_R=$(mrstats "$DZZ" -mask "$ROI/assoc_R.mif" -output mean -quiet | tr -d '[:space:]')

# Left
Dxx_proj_L=$(mrstats "$DXX" -mask "$ROI/proj_L.mif"  -output mean -quiet | tr -d '[:space:]')
Dyy_proj_L=$(mrstats "$DYY" -mask "$ROI/proj_L.mif"  -output mean -quiet | tr -d '[:space:]')
Dxx_assoc_L=$(mrstats "$DXX" -mask "$ROI/assoc_L.mif" -output mean -quiet | tr -d '[:space:]')
Dzz_assoc_L=$(mrstats "$DZZ" -mask "$ROI/assoc_L.mif" -output mean -quiet | tr -d '[:space:]')

ALPS_R=$(awk -v a="$Dxx_proj_R" -v b="$Dxx_assoc_R" -v c="$Dyy_proj_R" -v d="$Dzz_assoc_R" \
'BEGIN{printf "%.6f",(a+b)/(c+d)}')

ALPS_L=$(awk -v a="$Dxx_proj_L" -v b="$Dxx_assoc_L" -v c="$Dyy_proj_L" -v d="$Dzz_assoc_L" \
'BEGIN{printf "%.6f",(a+b)/(c+d)}')

ALPS_MEAN=$(awk -v l="$ALPS_L" -v r="$ALPS_R" \
'BEGIN{printf "%.6f",(l+r)/2}')

echo
echo "=============================="
echo "Subject: $SUBJ"
echo "=============================="
echo "ALPS_R    = $ALPS_R"
echo "ALPS_L    = $ALPS_L"
echo "ALPS_mean = $ALPS_MEAN"
echo "=============================="
