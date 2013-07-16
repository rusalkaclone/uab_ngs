#!/bin/sh 
#
# BWA PE Illumna reads vs an un-indexed FASTA genome
# 
# WARNING: !!!!!NOT RE-ENTRANT!!!!!
#
#$ -S /bin/sh
#$ -cwd
#$ -V   # need this for parameter passing from MASTER to SLAVE!
#$ -j y
# email at:  Begining, End, Abort, Suspend
#$ -m beas  
#
# *** DRMAA resources for BWA ALN ****
# worked for 85% of kimbley samples
# -pe smp 4
# -l vf=1.9G -l h_vmem=2G
#
# *** DRMAA resources for BWA SAMPE ONLY ****
# -l vf=3.9G -l h_vmem=4G
#
# ** RUN TIME ** 
#$ -l h_rt=119:00:00
#$ -l s_rt=120:55:00
#
# *** output logs ***
#$ -e jobs/$JOB_NAME.$JOB_ID.err
#$ -o jobs/$JOB_NAME.$JOB_ID.out

CMD_LINE_PARAM_LIST="WORK_DIR SAMPLE_NAME CONTIG_FASTA REF_FASTA BAM_OUT"
DERIVED_VAR_LIST="CMD_LINE HOSTNAME PROJECT_DIR DONE_ONLY QSUB_PE_OVERRIDE"

QSUB_DRMAA="-l vf=1.9G -l h_vmem=2G" 

export DERIVED_VAR_LIST="${DERIVED_VAR_LIST} JOB_DIR"
export DERIVED_VAR_LIST="${DERIVED_VAR_LIST} BWA_VER BWA"
export DERIVED_VAR_LIST="${DERIVED_VAR_LIST} SAMTOOLS_VER SAMTOOLS"

# UTIL function
run_cmd () { # ARGS: stdout_dest_or_- cmd [args]
    TMPSTD=$1; shift  # redirect for stdout
    TMPERR=`mktemp`
    if [[ -z "$TMPSTD" || "-" == "$TMPSTD" ]]; then  
	# stdout to stdout
	echo "# CMD: $*" 
	eval $* 2>$TMPERR
    else
	# stdout to file
	echo "# CMD: $* 1>$TMPSTD" 
	eval $* 2>$TMPERR 1>$TMPSTD
    fi
    RC=$?
    if [ $RC != 0 ]; then 
	echo "ERROR: $*"
	echo "ERROR: "`cat $TMPERR`
	exit 1; 
    fi
    return $RC
}


    
#====================================================================== 
# MASTER: submit-self on a head-node
#====================================================================== 
if [[ -z "$JOB_ID" || "$1" == "-inline" ]]; then
    
    export TASK_NAME=`basename $0 .sh | sed -e 's/^qsub_//'`

    # --------------------------
    # parse parameters
    # --------------------------

    # capture the original CMD_LINE
    if [ -z "$CMD_LINE" ]; then  CMD_LINE="$0 $*"; fi

    # check for debug or no qsub
    QSUB=`which qsub 2>/dev/null`

    #HOSTNAME=DEBUG
    # parse params
    while [[ "$1" == -* ]]; do 
	echo "PARSE FLAG: $1"
	if [[ "-debug" == "$1" || "-inline" == "$1" || $HOSTNAME != cheaha* || -z "$QSUB" ]]; then
	    if [[ "-debug" == "$1" || "-inline" == "$1" ]]; then shift 1; fi
	    export JOB_ID=run_now
	    echo "**** NO QSUB [NSLOTS=$NSLOTS] ****" 
	    continue
	fi
	# check for .done mode
	if [ "-done" == "$1" ]; then
	    export DONE_ONLY=yes
	    echo "**** .DONE MODE ON **** (skip step based ONLY on .done file) " 
	    shift 1
	    continue
	fi
	# check for -bwa  over-ride
	if [ "-bwa" == "$1" ]; then
	    export BWA="$2"
	    echo "**** -BWA OVERRIDE=$BWA **** " 
	    shift 1
	    shift 1
	    continue
	fi
	# check for -index  over-ride
	if [ "-index" == "$1" ]; then
	    export INDEX="$2"
	    echo "**** -INDEX OVERRIDE=$INDEX **** " 
	    shift 1
	    shift 1
	    continue
	fi
	# unknown flag
	echo "ERROR: unknown option: $1"
	exit 1
    done
    # cmd-line params
    for myvar in $CMD_LINE_PARAM_LIST ; do
	eval $myvar=$1
	export $myvar
	echo -n "Z: $myvar	:"; eval echo \$$myvar
	if [ -z "$1" ] ; then
	    echo "$myvar	: MISSING"
	    SCRIPT_NAME=`basename $0`
	    echo ""
	    echo "ERROR: $SCRIPT_NAME [-debug] [-inline] ${CMD_LINE_PARAM_LIST}"
	    echo ""
	    echo "Output files will be named: "
	    echo "so avoid '-'s in your names, stick to underscores and periods!"
	    echo " "
	    echo ""
	    exit 1
	fi
	shift
    done

    # --------------------------
    # job setup
    # --------------------------
    # paths
    # BWA
    if [ -z "$BWA" ]; then export BWA="/share/apps/ngs-ccts/bwa-0.6.2/bwa"; fi
    export BWA_DIR=`dirname $BWA`
    # get BWA abbreviations 
    export BWA_VER=`$BWA 2>&1 | grep "^Version" | cut -d " " -f 2  | sed -e 's/[.-]/_/g;'`
    export SAMTOOLS_VER=`samtools 2>&1 | grep "^Version" | cut -d " " -f 2  | sed -e 's/[.-]/_/g;'`

    # job dirs
    export DIR_LIST=
    export JOB_DIR=${WORK_DIR}/jobs		;export DIR_LIST="$DIR_LIST JOB_DIR"
    #export BWA_OUT_DIR=${WORK_DIR}/bwa		;export DIR_LIST="$DIR_LIST BWA_OUT_DIR"
    for dir in DIR_LIST; do
	MDIR=`eval echo \$$dir`
	if [ ! -e ${MDIR} ]; then 
	    run_cmd - mkdir -p $MDIR
	fi
    done

    # copy script to jobs
    cp $0 $JOB_DIR/`basename $0`.$JOB_NAME.$JOB_ID

    # --------------------------
    # qsub
    # --------------------------
    if [ -z "$JOB_ID" ]; then
	echo -n "${TASK_NAME}:${SAMPLE_NAME}:QSUB:"
	QSUB_NAME=${TASK_NAME}-${SAMPLE_NAME}
	pushd ${WORK_DIR}
	qsub -terse \
	    -N $QSUB_NAME \
	    -M $USER@uab.edu \
	    -e ${JOB_DIR}/${QSUB_NAME}.$$.err.txt \
	    -o ${JOB_DIR}/${QSUB_NAME}.$$.out.txt \
	    $0
	popd
	if [ $? != 0 ]; then echo "ERROR: bad return code from QSUB"; exit 1; fi
	exit 0
    else
	echo "[debug] skipped qsub"
    fi
fi

#====================================================================== 
# UTIL FUNCTIONS
#====================================================================== 
run_step () { # ARGS: sample_name target_file step_name cmd_out cmd [cmd_args]
    # args
    RS_SAMPLE_NAME=$1; shift 1
    RS_TARGET=$1; shift 1
    RS_NAME=$1; shift 1
    RS_STDOUT=$1; shift 1       # redirect for stdout

    # log start/skip
    if [[ ( -e "${RS_TARGET}" || -n "$DONE_ONLY" ) && ( -e "${RS_TARGET}.done" ) ]]; then
	echo;echo `date`"	TS	SKIP ${RS_NAME}	${RS_SAMPLE_NAME}"; 
    else
	echo;echo `date`"	TS	START ${RS_NAME}	${RS_SAMPLE_NAME}"; 
	
	# run the cmd
	RS_TMPERR=`mktemp`
	if [[ -z "$RS_STDOUT" || "-" == "$RS_STDOUT" ]]; then  
	    # stdout to stdout
	    echo "# CMD: $*" 
	    $* 2>$RS_TMPERR
	else
    	    # stdout to file
	    echo "# CMD: $* 1>$RS_STDOUT" 
	    $* 2>$RS_TMPERR 1>$RS_STDOUT
	fi
    fi
    #  handle errors
    RC=$?
    if [ $RC != 0 ]; then 
	echo "ERROR: $*"
	echo "ERROR: "`cat $RS_TMPERR`
	echo;echo `date`"	TS	ERROR ${RS_NAME}	${RS_SAMPLE_NAME}"
	exit $RC
    fi
    # handle success
    touch ${RS_TARGET}.done
    echo;echo `date`"	TS	DONE ${RS_NAME}	${RS_SAMPLE_NAME}"; 
    
    return $RC
}

#====================================================================== 
# actual slave work
#====================================================================== 
if [ -n "$JOB_ID"  ]; then
    # backup script/cmd-line
    export SCRIPT_BAK=jobs/$JOB_NAME.$JOB_ID.qsub_${TASK_NAME}.sh
    cp $0 ${SCRIPT_BAK}
    export SCRIPT_DOIT=jobs/$JOB_NAME.$JOB_ID.doit.sh
    echo "$PWD/${SCRIPT_BAK} ${CMD_ARGS}" > ${SCRIPT_DOIT}
    
    echo "-- environment --"
    echo "JOB_NAME: $JOB_NAME"
    echo "JOB_ID: $JOB_ID"
    echo "NSLOTS=$NSLOTS"
    echo "-- cmd line params -- "
    for myvar in $CMD_LINE_PARAM_LIST ; do
	echo -n "$myvar	:"; eval echo \$$myvar
    done
    echo "-- derrived values line params -- "
    for myvar in $DERIVED_VAR_LIST ; do
	echo -n "$myvar	:"; eval echo \$$myvar
    done
    
    echo "I'm a qsub slave: "
    #echo "cd $OUT_DIR"
    cd ${WORK_DIR}

    # wordwrap of the reference
    REF_FASTA_WRAPPED="${REF_FASTA}.w60.fa"
    run_step $SAMPLE_NAME $REF_FASTA_WRAPPED "FASTA_formatter(60)" - \
	fasta_formatter -i $REF_FASTA -w 60 -o $REF_FASTA_WRAPPED

    # BWA Index of Reference
    export BWA_REF_INDEXED=${REF_FASTA_WRAPPED}.bwa${BWA_VER}
    if [ ! -e "${BWA_REF_INDEXED}.bwt" ]; then
	# decide which indexing option
	REF_SIZE=`wc -c ${REF_FASTA} | cut -d " " -f 1`
	export BWA_INDEX_TYPE='is'
	BWA_MAX_IS=$(( 2**30 ))
	if [ $REF_SIZE -gt $BWA_MAX_IS ]; then
	    export BWA_INDEX_TYPE='bwtsw'
	fi
	echo "REF_SIZE_=$REF_SIZE"
	echo "BWA_MAX_IS=$BWA_MAX_IS"
	echo "BWA_INDEX_TYPE=$BWA_INDEX_TYPE"
    fi
    echo "BWA_REF_INDEXED=$BWA_REF_INDEXED"
    run_step $SAMPLE_NAME $BWA_REF_INDEXED.bwt BWA_index_ref_fasta - \
	bwa index -a $BWA_INDEX_TYPE -p $BWA_REF_INDEXED $REF_FASTA    

    # BWA SW alignment
    SAM_ALIGN=$BAM_OUT.aligned.unsorted.sam
    # -r $RG_NAME  (skip RG for now)
    run_step $SAMPLE_NAME $SAM_ALIGN BWA_sw - \
	bwa bwasw \
	-f $SAM_ALIGN \
	$BWA_REF_INDEXED \
	$CONTIG_FASTA

    # SAMTOOLS view, sort, index
    BAM_USORT=$BAM_OUT.aligned.unsorted.bam
    run_step $SAMPLE_NAME $BAM_USORT SAMTOOLS_view - \
	samtools view -bS \
	-o ${BAM_USORT} \
	${SAM_ALIGN}
    BAM_OUT_BASE=`echo $BAM_OUT | sed -e 's/.bam$//'`
    run_step $SAMPLE_NAME $BAM_OUT SAMTOOLS_sort - \
	samtools sort \
	${BAM_USORT} \
	${BAM_OUT_BASE}
    BAI_OUT=`echo $BAM_OUT | sed -e 's/bam$/bai/'`
    run_step $SAMPLE_NAME $BAI_OUT SAMTOOLS_index - \
	samtools index \
	${BAM_OUT} \
	${BAI_OUT}

    # Flagstat of alignment
    FLAGSTAT_OUT=${BAM_OUT}.flagstat
    run_step $SAMPLE_NAME $FLAGSTAT_OUT SAMTOOLS_flagstat $FLAGSTAT_OUT \
	samtools flagstat $BAM_OUT

    # SAMTOOLs PILEUP -> VCF
    SAMTOOLS_REF_INDEXED=${REF_FASTA}.fai
    run_step $SAMPLE_NAME $SAMTOOLS_REF_INDEXED SAMTOOLS_index_contigs -  \
	samtools faidx ${REF_FASTA_WRAPPED}
    BCF_RAW=${BAM_OUT}.raw.bcf
    run_step $SAMPLE_NAME $BCF_RAW SAMTOOLS_mpileup_vcf $BCF_RAW  \
	samtools mpileup -C50 -g -f ${REF_FASTA_WRAPPED} $BAM_OUT 
    VCF_OUT=${BAM_OUT}.vcf
    run_step $SAMPLE_NAME $VCF_OUT SAMTOOLS_mpileup_vcf $VCF_OUT  \
	bcftools view -cv $BCF_RAW
    
    exit 0
fi