#!/bin/bash

LAB_DIR="/mnt/stressdevlab"
SCRIPT_DIR="${LAB_DIR}/scripts/DTI/SlicerScripts"
#PROJECT_DIR="${LAB_DIR}/SAS_DTI/"
PROJECT_DIR="${LAB_DIR}/beip/DTI"
VENDOR="SIEMENS"

Subject=$1

SUBJECT_DIR="${PROJECT_DIR}/${Subject}"
#DWI="${SUBJECT_DIR}/dtiQC/nounwarp/mc_dtiQC/mc_DTI60.nii.gz"
#BVECS="${SUBJECT_DIR}/dtiQC/nounwarp/mc_dtiQC/bvec_mc.txt"
#BVALS="${SUBJECT_DIR}/dtiQC/DTI60.bvals"
DWI="${SUBJECT_DIR}/dti1/nounwarp/mc_dti/mc_DTI1.nii.gz"
BVECS="${SUBJECT_DIR}/dti1/nounwarp/mc_dti/bvec_mc.txt"
BVALS="${SUBJECT_DIR}/dti1/DTI1.bval"
DWINAME=`basename ${DWI} .nii.gz`

mkdir -p "${SUBJECT_DIR}/tractography"
cd "${SUBJECT_DIR}/tractography"

echo "Transposing bvals for compatability with DTIPrep ..."
1dtranspose ${BVALS} > bval.txt

#Transpose b-vectors, flip y gradient b/c Siemens...
echo "Transposing b-vectors for compatibility with DTIPrep ..."
if [[ ${VENDOR} == *SIEMENS* ]]; then
	echo "Flipping y gradient for Siemens data ..."
	1dDW_Grad_o_Mat -in_grad_rows ${BVECS} -out_grad_cols bvec.txt -flip_y -keep_b0s
else
	1dtranspose ${BVECS} > bvec.txt
fi

#Convert DWI image data from NIFTI to NRRD
echo "Converting DWI image data from NIFTI -> NRRD ..."
/usr/local/Slicer-4.5.0-1-linux-amd64/Slicer --launch DWIConvert --inputVolume ${DWI} --inputBVectors bvec.txt --inputBValues bval.txt --conversionMode FSLToNrrd -o "${DWINAME}.nrrd"

#Skull-strip DWI image
/usr/local/Slicer-4.5.0-1-linux-amd64/Slicer --launch DiffusionWeightedVolumeMasking --otsuomegathreshold 0.5 --removeislands "${DWINAME}.nrrd" "${DWINAME}_baseline.nrrd" "${DWINAME}_brain.nrrd"

#Convert motion and eddy corrected DWI image from NRRD --> NIFTI
echo "Making ColorFA image ..."
/usr/local/Slicer-4.5.0-1-linux-amd64/Slicer --launch DWIToDTIEstimation "${DWINAME}.nrrd" ${DWINAME}_ColorFA.nrrd ${DWINAME}_baseline.nrrd -m "${DWINAME}_brain.nrrd"
