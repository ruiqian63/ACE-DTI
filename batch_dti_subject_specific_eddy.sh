#!/usr/bin/env bash
set -uo pipefail

# ============================================================
# Batch DTI -> FA/MD/AD/RD + ALPS prerequisites
#
# Dataset layout example:
#   /home/gfk8453/Desktop/DTI analysis/Ann_Data/ACE/
#     AGRJ67/AGRJ67/scans/3-DTI/resources/DICOM/
#
# Output:
#   /home/gfk8453/Desktop/DTI analysis/Ann_Data/results/<SUBJECT>/
#
# Per-subject workflow:
#   DICOM
#     -> dcm2niix
#     -> read JSON metadata per subject
#     -> import NIfTI+bvec+bval into MRtrix
#     -> dwidenoise
#     -> mrdegibbs
#     -> dwifslpreproc (eddy + motion correction; rpe_none)
#     -> dwi2mask
#     -> dwi2tensor
#     -> FA / MD / AD / RD
#     -> Dxx / Dyy / Dzz
#     -> principal eigenvector
#     -> DEC / color-FA prerequisite
#
# IMPORTANT
# ----------
# 1) This script uses each subject's own:
#      PhaseEncodingDirection
#      TotalReadoutTime
#      EchoTime
#      RepetitionTime
#    from the dcm2niix JSON sidecar.
#
# 2) EchoTime and RepetitionTime are stored for QC/documentation.
#    They are NOT direct inputs to FSL eddy.
#
# 3) With only one PE direction and no reverse-PE b0,
#    dwifslpreproc -rpe_none performs eddy-current + motion
#    correction, but NOT topup-based susceptibility correction.
#
# 4) If reverse-PE b0 data are later identified, this pipeline
#    should be upgraded to -rpe_pair / -se_epi for topup.
# ============================================================

INPUT_ROOT="/home/gfk8453/Desktop/DTI analysis/Ann_Data/ACE"
OUTPUT_ROOT="/home/gfk8453/Desktop/DTI analysis/Ann_Data/results"

#mkdir -p "$OUTPUT_ROOT"
export FSLDIR=/opt/fsl
export PATH="$FSLDIR/bin:$PATH"
# ------------------------------------------------------------
# Dependency checks
# ------------------------------------------------------------

required=(
  dcm2niix
  mrconvert
  mrinfo
  dwidenoise
  mrdegibbs
  dwifslpreproc
  dwi2mask
  dwi2tensor
  tensor2metric
  dwiextract
  mrmath
  mrcalc
  mrstats
  python3
)

for cmd in "${required[@]}"; do
    if ! command -v "$cmd" >/dev/null 2>&1; then
        echo "ERROR: required command not found: $cmd"
        exit 1
    fi
done

# FSL eddy executable naming differs across installations.
if ! command -v eddy >/dev/null 2>&1 && \
   ! command -v eddy_openmp >/dev/null 2>&1 && \
   ! compgen -c | grep -q '^eddy_cuda'; then
    echo "ERROR: FSL eddy executable not found."
    echo "Check your FSL installation / PATH."
    exit 1
fi

echo "============================================================"
echo "Batch DTI processing"
echo "Input : $INPUT_ROOT"
echo "Output: $OUTPUT_ROOT"
echo "============================================================"

processed=0
failed=0
skipped=0

# ------------------------------------------------------------
# Subject loop
# ------------------------------------------------------------

for SUBJECT_DIR in "$INPUT_ROOT"/*; do
    [ -d "$SUBJECT_DIR" ] || continue

    SUBJECT="$(basename "$SUBJECT_DIR")"

    # Example:
    # AGRJ67/AGRJ67/scans/3-DTI/resources/DICOM
    DICOM_DIR="$(find "$SUBJECT_DIR" \
        -type d \
        -path "*/scans/*-DTI/resources/DICOM" \
        -print -quit 2>/dev/null)"

    if [ -z "$DICOM_DIR" ]; then
        echo "[SKIP] $SUBJECT : no *-DTI/resources/DICOM found"
        skipped=$((skipped + 1))
        continue
    fi

    OUT="$OUTPUT_ROOT/$SUBJECT"
    CONV="$OUT/00_dcm2niix"
    PRE="$OUT/01_preproc"
    TEN="$OUT/02_tensor"
    MET="$OUT/03_metrics"
    ALPS="$OUT/04_alps_pre"
    ROI="$OUT/05_roi"
    QC="$OUT/qc"

    mkdir -p "$CONV" "$PRE" "$TEN" "$MET" "$ALPS" "$ROI" "$QC"

    LOG="$QC/pipeline.log"
    : > "$LOG"

    echo
    echo "------------------------------------------------------------"
    echo "SUBJECT: $SUBJECT"
    echo "DICOM  : $DICOM_DIR"
    echo "OUTPUT : $OUT"
    echo "------------------------------------------------------------"

    (
        set -e

        # ====================================================
        # 1. DICOM -> NIfTI / JSON / bvec / bval
        # ====================================================

        echo "[1/14] dcm2niix conversion"

        rm -f "$CONV"/*

        dcm2niix \
            -b y \
            -ba y \
            -z y \
            -f "${SUBJECT}_DTI" \
            -o "$CONV" \
            "$DICOM_DIR"

        # Locate one diffusion conversion set.
        mapfile -t BVALS < <(find "$CONV" -maxdepth 1 -type f -name "*.bval" | sort)

        if [ "${#BVALS[@]}" -ne 1 ]; then
            echo "ERROR: expected exactly 1 .bval file, found ${#BVALS[@]}"
            printf '%s\n' "${BVALS[@]}"
            exit 1
        fi

        BVAL="${BVALS[0]}"
        STEM="${BVAL%.bval}"

        BVEC="${STEM}.bvec"
        JSON="${STEM}.json"

        if [ -f "${STEM}.nii.gz" ]; then
            NII="${STEM}.nii.gz"
        elif [ -f "${STEM}.nii" ]; then
            NII="${STEM}.nii"
        else
            echo "ERROR: matching NIfTI not found for $BVAL"
            exit 1
        fi

        for f in "$BVEC" "$JSON" "$NII"; do
            if [ ! -f "$f" ]; then
                echo "ERROR: missing converted file: $f"
                exit 1
            fi
        done

        # ====================================================
        # 2. Parse subject-specific metadata
        # ====================================================

        echo "[2/14] Read subject-specific DICOM metadata"

        META_TSV="$QC/acquisition_metadata.tsv"

        python3 - "$JSON" "$META_TSV" <<'PY'
import json
import sys

json_file, out_file = sys.argv[1], sys.argv[2]

with open(json_file, "r") as f:
    d = json.load(f)

keys = [
    "PhaseEncodingDirection",
    "TotalReadoutTime",
    "EffectiveEchoSpacing",
    "EchoTime",
    "RepetitionTime",
    "MagneticFieldStrength",
    "Manufacturer",
    "ManufacturersModelName",
    "SeriesDescription",
    "ProtocolName",
]

with open(out_file, "w") as f:
    f.write("Field\tValue\n")
    for k in keys:
        f.write(f"{k}\t{d.get(k, '')}\n")

required = ["PhaseEncodingDirection", "TotalReadoutTime"]
missing = [k for k in required if d.get(k) in (None, "")]

if missing:
    raise SystemExit(
        "Missing required JSON metadata: " + ", ".join(missing)
    )

pe = str(d["PhaseEncodingDirection"])
tro = float(d["TotalReadoutTime"])
te = d.get("EchoTime", "")
tr = d.get("RepetitionTime", "")

print(pe)
print(tro)
print(te)
print(tr)
PY

        mapfile -t META_VALUES < <(
            python3 - "$JSON" <<'PY'
import json, sys
with open(sys.argv[1]) as f:
    d = json.load(f)

print(d["PhaseEncodingDirection"])
print(d["TotalReadoutTime"])
print(d.get("EchoTime", "NA"))
print(d.get("RepetitionTime", "NA"))
PY
        )

        PE_DIR="${META_VALUES[0]}"
        READOUT="${META_VALUES[1]}"
        ECHO_TIME="${META_VALUES[2]}"
        REP_TIME="${META_VALUES[3]}"

        echo "PhaseEncodingDirection = $PE_DIR"
        echo "TotalReadoutTime       = $READOUT"
        echo "EchoTime               = $ECHO_TIME"
        echo "RepetitionTime         = $REP_TIME"

        # Basic validation of PE direction accepted by MRtrix.
        case "$PE_DIR" in
            i|i-|j|j-|k|k-) ;;
            *)
                echo "ERROR: unexpected PhaseEncodingDirection: $PE_DIR"
                exit 1
                ;;
        esac

        # ====================================================
        # 3. Validate gradient table
        # ====================================================

        echo "[3/14] Validate volumes / b-values / gradients"

        N_BVAL="$(wc -w < "$BVAL" | tr -d ' ')"

        # FSL bvec normally has 3 rows; count values in first row.
        N_BVEC="$(awk 'NR==1 {print NF}' "$BVEC")"

        N_VOL="$(mrinfo "$NII" -size | awk '{print $4}')"

        {
            echo "NIfTI volumes: $N_VOL"
            echo "b-values     : $N_BVAL"
            echo "b-vectors    : $N_BVEC"
        } > "$QC/gradient_count.txt"

        if [ "$N_VOL" != "$N_BVAL" ] || [ "$N_VOL" != "$N_BVEC" ]; then
            echo "ERROR: volume / bval / bvec counts do not match"
            cat "$QC/gradient_count.txt"
            exit 1
        fi

        # ====================================================
        # 4. Import into MRtrix
        # ====================================================

        echo "[4/14] Import NIfTI + gradients + JSON into MRtrix"

        mrconvert \
            "$NII" \
            "$PRE/dti_raw.mif" \
            -fslgrad "$BVEC" "$BVAL" \
            -json_import "$JSON" \
            -force

        mrinfo "$PRE/dti_raw.mif" > "$QC/mrinfo_raw.txt"
        mrinfo "$PRE/dti_raw.mif" -dwgrad > "$QC/gradients_mrtrix.txt"

        # ====================================================
        # 5. Denoising
        # ====================================================

        echo "[5/14] MP-PCA denoising"

        dwidenoise \
            "$PRE/dti_raw.mif" \
            "$PRE/dti_denoised.mif" \
            -noise "$PRE/noise.mif" \
            -force

        # ====================================================
        # 6. Gibbs ringing correction
        # ====================================================

        echo "[6/14] Gibbs ringing correction"

        mrdegibbs \
            "$PRE/dti_denoised.mif" \
            "$PRE/dti_degibbs.mif" \
            -force

        # ====================================================
        # 7. Eddy-current + motion correction
        # ====================================================

        echo "[7/14] Eddy-current + motion correction"
        echo "        PE direction : $PE_DIR"
        echo "        Readout time : $READOUT"

        dwifslpreproc \
            "$PRE/dti_degibbs.mif" \
            "$PRE/dti_preproc.mif" \
            -rpe_none \
            -pe_dir "$PE_DIR" \
            -readout_time "$READOUT" \
            -eddyqc_all "$QC/eddy_qc" \
            -force

        mrinfo "$PRE/dti_preproc.mif" > "$QC/mrinfo_preproc.txt"

        # ====================================================
        # 8. Brain mask + mean b0
        # ====================================================

        echo "[8/14] Brain mask + mean b0"

        dwi2mask \
            "$PRE/dti_preproc.mif" \
            "$PRE/mask.mif" \
            -force

        dwiextract \
            "$PRE/dti_preproc.mif" \
            -bzero - | \
        mrmath \
            - mean \
            "$PRE/mean_b0.mif" \
            -axis 3 \
            -force

        # ====================================================
        # 9. Tensor fit
        # ====================================================

        echo "[9/14] Diffusion tensor fitting"

        dwi2tensor \
            "$PRE/dti_preproc.mif" \
            "$TEN/tensor.mif" \
            -mask "$PRE/mask.mif" \
            -force

        # ====================================================
        # 10. Conventional DTI metrics
        # ====================================================

        echo "[10/14] FA / MD / AD / RD"

        tensor2metric \
            "$TEN/tensor.mif" \
            -fa  "$MET/FA.mif" \
            -adc "$MET/MD.mif" \
            -ad  "$MET/AD.mif" \
            -rd  "$MET/RD.mif" \
            -force

        # ====================================================
        # 11. ALPS diagonal tensor components
        # ====================================================

        echo "[11/14] Dxx / Dyy / Dzz"

        # MRtrix tensor storage:
        #   vol 0 = Dxx
        #   vol 1 = Dyy
        #   vol 2 = Dzz
        #   vol 3 = Dxy
        #   vol 4 = Dxz
        #   vol 5 = Dyz

        mrconvert "$TEN/tensor.mif" -coord 3 0 "$ALPS/Dxx.mif" -force
        mrconvert "$TEN/tensor.mif" -coord 3 1 "$ALPS/Dyy.mif" -force
        mrconvert "$TEN/tensor.mif" -coord 3 2 "$ALPS/Dzz.mif" -force

        # ====================================================
        # 12. Principal eigenvector + DEC map
        # ====================================================

        echo "[12/14] Principal eigenvector + DEC map"

        tensor2metric \
            "$TEN/tensor.mif" \
            -vector "$TEN/v1.mif" \
            -num 1 \
            -modulate none \
            -force

        # DEC channels:
        #   R = |Vx| * FA
        #   G = |Vy| * FA
        #   B = |Vz| * FA
        mrcalc \
            "$TEN/v1.mif" \
            -abs \
            "$MET/FA.mif" \
            -mult \
            "$ALPS/DEC.mif" \
            -force

        # ====================================================
        # 13. Export convenient NIfTI files
        # ====================================================

        echo "[13/14] Export NIfTI files"

        mrconvert "$PRE/mask.mif" \
            "$PRE/mask.nii.gz" \
            -datatype uint8 \
            -force

        mrconvert "$PRE/mean_b0.mif" \
            "$PRE/mean_b0.nii.gz" \
            -force

        for metric in FA MD AD RD; do
            mrconvert \
                "$MET/${metric}.mif" \
                "$MET/${metric}.nii.gz" \
                -force
        done

        for img in Dxx Dyy Dzz DEC; do
            mrconvert \
                "$ALPS/${img}.mif" \
                "$ALPS/${img}.nii.gz" \
                -force
        done

        # ====================================================
        # 14. QC summary + ROI instructions
        # ====================================================

        echo "[14/14] QC summary"

        {
            echo "Subject: $SUBJECT"
            echo "DICOM: $DICOM_DIR"
            echo
            echo "PhaseEncodingDirection: $PE_DIR"
            echo "TotalReadoutTime:       $READOUT"
            echo "EchoTime:               $ECHO_TIME"
            echo "RepetitionTime:         $REP_TIME"
            echo
            echo "FA"
            mrstats "$MET/FA.mif" -mask "$PRE/mask.mif"
            echo
            echo "MD"
            mrstats "$MET/MD.mif" -mask "$PRE/mask.mif"
            echo
            echo "AD"
            mrstats "$MET/AD.mif" -mask "$PRE/mask.mif"
            echo
            echo "RD"
            mrstats "$MET/RD.mif" -mask "$PRE/mask.mif"
            echo
            echo "Dxx"
            mrstats "$ALPS/Dxx.mif" -mask "$PRE/mask.mif"
            echo
            echo "Dyy"
            mrstats "$ALPS/Dyy.mif" -mask "$PRE/mask.mif"
            echo
            echo "Dzz"
            mrstats "$ALPS/Dzz.mif" -mask "$PRE/mask.mif"
        } > "$QC/metric_stats.txt"

        cat > "$ROI/README_ROI.txt" <<EOF
Subject: $SUBJECT

Use:
  $ALPS/DEC.mif

Draw and save:
  $ROI/proj_R.mif
  $ROI/assoc_R.mif
  $ROI/proj_L.mif
  $ROI/assoc_L.mif

ALPS tensor component maps:
  $ALPS/Dxx.mif
  $ALPS/Dyy.mif
  $ALPS/Dzz.mif

Directional QC after drawing:
  Projection ROI:
      Dzz should be the dominant diagonal component.

  Association ROI:
      Dyy should be the dominant diagonal component.

Important:
  This pipeline used dwifslpreproc -rpe_none because only the
  primary DTI PE direction was provided. This corrects motion
  and eddy-current effects, but does not perform topup-based
  susceptibility correction.

Subject acquisition metadata:
  PhaseEncodingDirection = $PE_DIR
  TotalReadoutTime       = $READOUT
  EchoTime               = $ECHO_TIME
  RepetitionTime         = $REP_TIME
EOF

        touch "$QC/PROCESSING_COMPLETE"

        echo
        echo "DONE: $SUBJECT"
        echo "ROI background:"
        echo "  $ALPS/DEC.mif"
        echo

    ) 2>&1 | tee -a "$LOG"

    status=${PIPESTATUS[0]}

    if [ "$status" -eq 0 ]; then
        processed=$((processed + 1))
    else
        failed=$((failed + 1))
        rm -f "$QC/PROCESSING_COMPLETE"
        touch "$QC/PROCESSING_FAILED"
        echo "[FAILED] $SUBJECT -- see $LOG"
    fi
done

echo
echo "============================================================"
echo "Batch finished"
echo "Successful: $processed"
echo "Failed    : $failed"
echo "Skipped   : $skipped"
echo "Results   : $OUTPUT_ROOT"
echo "============================================================"
