#!/bin/bash
#
# convert from sample list to directory structure for ROSS project
#
echo "doit.bwa_dirs.sh: $0 $*"
SCRATCH_DIR=/scratch/user/curtish/ross/vicuna3filt
export VICUNA_DIR=/share/apps/ngs-ccts/VICUNA_v1.3
#export VICUNA_EXE=/share/apps/ngs-ccts/VICUNA_v1.2
DEBUG=
while [[ "$1" = -* ]]; do
    if [[ "$1" = "-debug" ]]; then
	DEBUG="$DEBUG $1"
	shift
	echo "SHIFT(1): $DEBUG"
	continue
    fi
    if [[ "$1" = "-pe" ]]; then
	DEBUG="$DEBUG $1 $2 $3"
	shift 3
	echo "SHIFT(3): $DEBUG"
	continue
    fi
    # most have 1 arg
    DEBUG="$DEBUG $1 $2"
    shift 2
    echo "SHIFT(2): $DEBUG"
done

NAME=$1
REF=/home/curtish/ics/consults/ross/ics63/ref_genomes/$2
FASTQ1=$SCRATCH_DIR/../fastq/$3
FASTQ2=`echo $FASTQ1 | sed -e 's/_R1_/_R2_/'`
VICUNA_MSA_FILE=$REF

nohup \
    ~/ics/consults/ross/hcmv/vicuna/qsub_vicunaF.sh \
    $DEBUG \
    $SCRATCH_DIR/$NAME \
    $NAME \
    $REF \
    $FASTQ1 \
    $FASTQ2 \
    $VICUNA_MSA_FILE \
    2>&1 \
    | tee $SCRATCH_DIR/$NAME/jobs/$NAME.$$.out
