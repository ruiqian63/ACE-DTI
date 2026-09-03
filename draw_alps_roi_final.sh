#!/usr/bin/env bash
set -u

# ============================================================
# DTI-ALPS manual ROI workflow
#
# - Opens each subject's DEC image
# - Creates/loads 4 ROI masks
# - Manual ROI drawing in MRView
# - Checks that all four ROI masks are non-empty
# - ROI size is flexible (NOT restricted to 9 voxels)
# - Skips subjects already completed successfully
# - Writes progress to CSV
# ============================================================


# ------------------------------------------------------------
# Configuration
# ------------------------------------------------------------

ROOT="/home/gfk8453/Desktop/DTI analysis/Ann_Data/results"

PROGRESS_CSV="$ROOT/roi_progress.csv"

ROI_OPACITY=0.65


# ROI names
ROI_NAMES=(
    "proj_R.mif"
    "assoc_R.mif"
    "proj_L.mif"
    "assoc_L.mif"
)


# ------------------------------------------------------------
# Colours
#
# Projection = blue
# Association = orange
# ------------------------------------------------------------

PROJ_COLOR="0,0.45,1"
ASSOC_COLOR="1,0.45,0"


# ------------------------------------------------------------
# Helper functions
# ------------------------------------------------------------

timestamp() {
    date '+%Y-%m-%d %H:%M:%S'
}


# Count non-zero ROI voxels.
#
# The ROI itself is used as the mask, so this returns the number
# of voxels with non-zero ROI values.
#
roi_voxel_count() {

    local roi="$1"

    if [ ! -f "$roi" ]; then
        echo "0"
        return
    fi

    local count

    count=$(mrstats "$roi" \
        -mask "$roi" \
        -output count \
        -quiet 2>/dev/null)

    if [ -z "$count" ]; then
        count=0
    fi

    # mrstats may return floating-point formatting
    printf "%.0f\n" "$count"
}


# Check whether all four ROI masks exist and are non-empty.
#
# Returns:
#   0 = complete
#   1 = incomplete
#
subject_roi_complete() {

    local roidir="$1"

    local roi
    local count

    for roi in "${ROI_NAMES[@]}"; do

        if [ ! -f "$roidir/$roi" ]; then
            return 1
        fi

        count=$(roi_voxel_count "$roidir/$roi")

        if [ "$count" -le 0 ]; then
            return 1
        fi

    done

    return 0
}


# Append one line to progress CSV
write_progress() {

    local subject="$1"
    local status="$2"
    local proj_r="$3"
    local assoc_r="$4"
    local proj_l="$5"
    local assoc_l="$6"
    local note="$7"

    printf '"%s","%s","%s","%s","%s","%s","%s","%s"\n' \
        "$(timestamp)" \
        "$subject" \
        "$status" \
        "$proj_r" \
        "$assoc_r" \
        "$proj_l" \
        "$assoc_l" \
        "$note" \
        >> "$PROGRESS_CSV"
}


# ------------------------------------------------------------
# Initialize progress CSV
# ------------------------------------------------------------

if [ ! -f "$PROGRESS_CSV" ]; then

    echo '"timestamp","subject","status","proj_R_vox","assoc_R_vox","proj_L_vox","assoc_L_vox","note"' \
        > "$PROGRESS_CSV"

fi


# ------------------------------------------------------------
# Pre-flight checks
# ------------------------------------------------------------

for cmd in mrview mrcalc mrstats; do

    if ! command -v "$cmd" >/dev/null 2>&1; then

        echo
        echo "ERROR: $cmd not found in PATH."
        echo

        exit 1

    fi

done


if [ ! -d "$ROOT" ]; then

    echo "ERROR: Results directory not found:"
    echo "$ROOT"

    exit 1

fi


# ------------------------------------------------------------
# Build subject list
# ------------------------------------------------------------

mapfile -t SUBJECT_DIRS < <(
    find "$ROOT" \
        -mindepth 1 \
        -maxdepth 1 \
        -type d \
        | sort
)


TOTAL=${#SUBJECT_DIRS[@]}


echo
echo "============================================================"
echo "DTI-ALPS ROI DRAWING WORKFLOW"
echo "============================================================"
echo
echo "Results root       : $ROOT"
echo "Subjects found     : $TOTAL"
echo "ROI size           : flexible"
echo "Progress CSV       : $PROGRESS_CSV"
echo
echo "ROI convention:"
echo
echo "  proj_R  = Right projection fibers"
echo "  assoc_R = Right association fibers"
echo "  proj_L  = Left projection fibers"
echo "  assoc_L = Left association fibers"
echo
echo "Projection ROI  : BLUE"
echo "Association ROI : ORANGE"
echo
echo "IMPORTANT:"
echo "  Save ROI edits inside MRView before closing the window."
echo "  ROI size is NOT restricted to a fixed voxel count."
echo "  Keep placement anatomically appropriate and reasonably consistent."
echo
echo "============================================================"
echo


# ------------------------------------------------------------
# Counters
# ------------------------------------------------------------

INDEX=0
DONE=0
FAILED=0
SKIPPED=0


# ------------------------------------------------------------
# Main loop
# ------------------------------------------------------------

for SUBJDIR in "${SUBJECT_DIRS[@]}"; do

    INDEX=$((INDEX + 1))

    SUBJECT=$(basename "$SUBJDIR")

    ROIDIR="$SUBJDIR/05_roi"

    # DEC can be uppercase or lowercase depending on pipeline
    DEC="$SUBJDIR/04_alps_pre/DEC.mif"

    if [ ! -f "$DEC" ]; then
        DEC="$SUBJDIR/04_alps_pre/dec.mif"
    fi


    echo
    echo
    echo "============================================================"
    echo "[$INDEX / $TOTAL] Subject: $SUBJECT"
    echo "============================================================"


    # --------------------------------------------------------
    # No DEC -> skip
    # --------------------------------------------------------

    if [ ! -f "$DEC" ]; then

        echo
        echo "SKIP: DEC image not found."
        echo

        write_progress \
            "$SUBJECT" \
            "SKIPPED" \
            "NA" \
            "NA" \
            "NA" \
            "NA" \
            "DEC not found"

        SKIPPED=$((SKIPPED + 1))

        continue

    fi


    mkdir -p "$ROIDIR"


    # --------------------------------------------------------
    # Already completed?
    # --------------------------------------------------------

    if subject_roi_complete "$ROIDIR"; then

        PR=$(roi_voxel_count "$ROIDIR/proj_R.mif")
        AR=$(roi_voxel_count "$ROIDIR/assoc_R.mif")
        PL=$(roi_voxel_count "$ROIDIR/proj_L.mif")
        AL=$(roi_voxel_count "$ROIDIR/assoc_L.mif")

        echo
        echo "Already completed — skipping."
        echo
        echo "  proj_R  : $PR voxels"
        echo "  assoc_R : $AR voxels"
        echo "  proj_L  : $PL voxels"
        echo "  assoc_L : $AL voxels"

        SKIPPED=$((SKIPPED + 1))

        continue

    fi


    # --------------------------------------------------------
    # Create empty ROI masks if they do not already exist
    #
    # Existing incomplete ROIs are preserved so you can resume.
    # --------------------------------------------------------

    for ROI_NAME in "${ROI_NAMES[@]}"; do

        ROI="$ROIDIR/$ROI_NAME"

        if [ ! -f "$ROI" ]; then

            echo "Creating empty ROI:"
            echo "  $ROI_NAME"

            mrcalc "$DEC" \
                0 \
                -mult \
                "$ROI" \
                -force \
                -quiet

        fi

    done


    # --------------------------------------------------------
    # Display current voxel counts before opening MRView
    # --------------------------------------------------------

    PR=$(roi_voxel_count "$ROIDIR/proj_R.mif")
    AR=$(roi_voxel_count "$ROIDIR/assoc_R.mif")
    PL=$(roi_voxel_count "$ROIDIR/proj_L.mif")
    AL=$(roi_voxel_count "$ROIDIR/assoc_L.mif")


    echo
    echo "Current ROI voxel counts:"
    echo
    printf "  %-10s : %s\n" "proj_R" "$PR"
    printf "  %-10s : %s\n" "assoc_R" "$AR"
    printf "  %-10s : %s\n" "proj_L" "$PL"
    printf "  %-10s : %s\n" "assoc_L" "$AL"

    echo
    echo "ROI size is flexible."
    echo "Please keep placement anatomically appropriate and reasonably consistent."
    echo
    echo "Open MRView..."
    echo
    echo "Draw / correct:"
    echo
    echo "  BLUE:"
    echo "      proj_R"
    echo "      proj_L"
    echo
    echo "  ORANGE:"
    echo "      assoc_R"
    echo "      assoc_L"
    echo
    echo "SAVE the ROIs, then close MRView."
    echo


    # --------------------------------------------------------
    # Open DEC + ROI editor
    # --------------------------------------------------------

    mrview "$DEC" \
        -roi.load "$ROIDIR/proj_R.mif" \
        -roi.colour "$PROJ_COLOR" \
        -roi.opacity "$ROI_OPACITY" \
        -roi.load "$ROIDIR/assoc_R.mif" \
        -roi.colour "$ASSOC_COLOR" \
        -roi.opacity "$ROI_OPACITY" \
        -roi.load "$ROIDIR/proj_L.mif" \
        -roi.colour "$PROJ_COLOR" \
        -roi.opacity "$ROI_OPACITY" \
        -roi.load "$ROIDIR/assoc_L.mif" \
        -roi.colour "$ASSOC_COLOR" \
        -roi.opacity "$ROI_OPACITY"


    # --------------------------------------------------------
    # User has closed MRView.
    # Re-check all ROI masks.
    # --------------------------------------------------------

    echo
    echo "MRView closed."
    echo
    echo "Checking ROI masks..."


    PR=$(roi_voxel_count "$ROIDIR/proj_R.mif")
    AR=$(roi_voxel_count "$ROIDIR/assoc_R.mif")
    PL=$(roi_voxel_count "$ROIDIR/proj_L.mif")
    AL=$(roi_voxel_count "$ROIDIR/assoc_L.mif")


    echo
    printf "  %-10s : %s voxels\n" "proj_R" "$PR"
    printf "  %-10s : %s voxels\n" "assoc_R" "$AR"
    printf "  %-10s : %s voxels\n" "proj_L" "$PL"
    printf "  %-10s : %s voxels\n" "assoc_L" "$AL"
    echo


    # --------------------------------------------------------
    # Validate: all four must be non-empty
    # --------------------------------------------------------

    if \
        [ "$PR" -gt 0 ] && \
        [ "$AR" -gt 0 ] && \
        [ "$PL" -gt 0 ] && \
        [ "$AL" -gt 0 ]
    then

        echo "--------------------------------------------"
        echo "PASS: $SUBJECT"
        echo "All four ROIs are non-empty."
        echo
        echo "ROI voxel counts:"
        echo "  proj_R  : $PR"
        echo "  assoc_R : $AR"
        echo "  proj_L  : $PL"
        echo "  assoc_L : $AL"
        echo "--------------------------------------------"

        write_progress \
            "$SUBJECT" \
            "PASS" \
            "$PR" \
            "$AR" \
            "$PL" \
            "$AL" \
            "ROI drawing complete"

        DONE=$((DONE + 1))

    else

        echo
        echo "!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!"
        echo "ROI CHECK FAILED: $SUBJECT"
        echo "!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!"
        echo
        echo "At least one ROI is empty."
        echo
        echo "  proj_R  : $PR"
        echo "  assoc_R : $AR"
        echo "  proj_L  : $PL"
        echo "  assoc_L : $AL"
        echo
        echo "This subject will NOT be marked complete."
        echo "It will automatically appear again the next"
        echo "time this script is run."
        echo

        write_progress \
            "$SUBJECT" \
            "FAIL" \
            "$PR" \
            "$AR" \
            "$PL" \
            "$AL" \
            "One or more ROI masks are empty"

        FAILED=$((FAILED + 1))

    fi


    # --------------------------------------------------------
    # Optional pause before next subject
    # --------------------------------------------------------

    echo
    read -r -p "Press ENTER to open the next subject, or type q to stop: " ANSWER

    if [[ "$ANSWER" =~ ^[Qq]$ ]]; then

        echo
        echo "Stopping ROI session."
        break

    fi

done


# ------------------------------------------------------------
# Summary
# ------------------------------------------------------------

echo
echo
echo "============================================================"
echo "ROI SESSION FINISHED"
echo "============================================================"
echo
echo "Completed this session : $DONE"
echo "Failed ROI check       : $FAILED"
echo "Skipped                : $SKIPPED"
echo
echo "Progress log:"
echo
echo "$PROGRESS_CSV"
echo
echo "============================================================"
