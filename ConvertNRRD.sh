#!/bin/bash
#Prepares SIEMENS DTI data for dtiprep
#Modification of script from CogNeuroStats blog: http://blog.cogneurostats.com/?p=607

if [ $# -lt 3 ]; then
 echo "Usage: ./ConvertNRRD.sh <nifti_file> <bvecs> <bvals>"
 echo "Usage: ./ConvertNRRD.sh myfile.nii.gz myfile.bvec myfile.bval"
 exit;
fi
if [ ! -e $1 ]; then
 echo "$1 does not exist. Use a real file."
 exit;
fi
if [ ! -e $2 ]; then
 echo "$2 does not exist. Use a real file."
 exit;
fi
if [ ! -e $3 ]; then
 echo "$3 does not exist. Use a real file."
 exit;
fi

LAB_DIR="/mnt/stressdevlab"

if [[ ${1} == *new_memory* ]]; then
	PROJECT="new_memory_pipeline"
	PROJECT_DIR="${LAB_DIR}/${PROJECT}/DTI"
else
	PROJECT=`echo ${1} | awk -F "stressdevlab/" '{print $2}' | awk -F "/" '{print $1}'`
	PROJECT_DIR="${LAB_DIR}/${PROJECT}"
fi
	TMP_DIR=`mktemp -d /tmp/dtiprepXXXX`

echo "PROJECT: ${PROJECT}"
echo "PROJECT_DIR: ${PROJECT_DIR}"

#Path to subject directory is slightly different across projects 
if [[ ${PROJECT} == *new_memory* ]] || [[ ${PROJECT} == *dep_threat* ]] || [[ ${PROJECT} == *SAS_DTI* ]] ; then
	SUBJECT=`echo ${1} | awk -F "/" '{print $5}'`
	SUBJECT_DIR=${PROJECT_DIR}/${SUBJECT}
elif [[ ${PROJECT} == *fear_pipeline* ]] || [[ ${PROJECT} == *stress_pipeline* ]] || [[ ${PROJECT} == *beip* ]]; then
	SUBJECT=`echo ${1} | awk -F "/" '{print $6}'`
	PRESUB=`echo ${1} | awk -F "${SUBJECT}" '{print $1}'`
	SUBJECT_DIR=${PRESUB}/${SUBJECT}
else
	echo "ERROR: Could not determine subject ID number."
	exit
fi

#All Philips DTI data comes from directories with pipeline in name
if [[ ${PROJECT} == *pipeline* ]]; then
	VENDOR="PHILIPS"
else
	VENDOR="SIEMENS"
fi

DTINAME=`basename $1 .nii.gz`
if [[ ${DTINAME} == *mc* ]]; then
	MCDTINAME=${DTINAME}
	DTINAME=`echo ${MCDTINAME} | awk -F "_" '{print $2}'`
fi

echo "Files found, proceeding with quality check ..."

#Create a temporary working space with date & time
foldername=`date +"%m%d%y_%T" | sed 's/://g'`
mkdir ${TMP_DIR}
echo "Creating temporary folder at ${TMP_DIR} ..."

#Copy over DWI image data and transpose bvals
echo "Copying DWI image data to ${TMP_DIR} ..."
echo "Transposing bvals for compatability with DTIPrep ..."
3dcopy $1 ${TMP_DIR}/${DTINAME}.nii
1dtranspose $3 > ${TMP_DIR}/bval.txt

#Transpose b-vectors, flip y gradient b/c Siemens...
echo "Transposing b-vectors..."
if [[ ${VENDOR} == *SIEMENS* ]]; then
echo "Flipping y gradient for Siemens data ..."
	1dDW_Grad_o_Mat -in_grad_rows $2 -out_grad_cols ${TMP_DIR}/bvec.txt -flip_y -keep_b0s
else
	1dtranspose $2 > ${TMP_DIR}/bvec.txt
fi


#Move into temporary working directory
cd ${TMP_DIR}

#Convert DWI image data from NIFTI to NRRD
echo "Converting DWI image data from NIFTI -> NRRD ..."
/usr/local/Slicer-4.5.0-1-linux-amd64/Slicer --launch DWIConvert --inputVolume ${DTINAME}.nii --inputBVectors bvec.txt --inputBValues bval.txt --conversionMode FSLToNrrd -o ${DTINAME}.nrrd

mkdir -p ${SUBJECT_DIR}/tractography
mv ${DTINAME}.nrrd ${SUBJECT_DIR}/tractography/${DTINAME}.nrrd
mv bvec.txt ${SUBJECT_DIR}/tractography/bvec.txt
mv bval.txt ${SUBJECT_DIR}/tractography/bval.txt

