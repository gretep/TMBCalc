#!/bin/bash

usage() {
  echo "Usage: $0 [-t/-tumor tumor sample]
  [-n/-normal normal sample ]
  [-tp/-type sample type, can be fastq or bam]
  [-i/-input input folder ]
  [-pr/-paired specify if the samples are paired end or not]
  [-id/-index human index]
  [-ifl/-ifolder index folder]
  [-p/-program program folder]
  [-j/-jv java]
  [-th/-threads number of bowtie2 threads, leave 1 if you are uncertain]
  [-e/-exome exome length in Megabase (Mb)]
  [-a/-annovar annovar folder path]" 1>&2
}

exit_abnormal_code() {
  echo "$1" 1>&2
  exit $2
}

exit_abnormal_usage() {
  echo "$1" 1>&2
  usage
  exit 1
}

exit_abnormal() {
  usage
  exit 1
}

while [ -n "$1" ]; do
  case "$1" in
  -tumor | -t)
    tumor="$2"
    echo "The value provided for tumor sample name is $tumor"
    shift
    ;;
  -normal | -n)
    normal="$2"
    echo "The value provided for normal sample name is $normal"
    shift
    ;;
  -input | -i)
    input="$2"
    echo "The value provided for input folder is $input"
    shift
    ;;
  -index | -id)
    index="$2"
    echo "The value provided for index is $index"
    shift
    ;;
  -ifolder | -ifl)
    ifolder="$2"
    echo "The value provided for index folder is $ifolder"
    shift
    ;;
  -program | -p)
    program="$2"
    echo "The value provided for program is $program"
    shift
    ;;
  -jv | -j)
    jv="$2"
    echo "The value provided for java is $jv"
    shift
    ;;
  -paired | -pr)
    paired="$2"
    echo "The value provided for paired is $paired"
    if ! { [ "$paired" = "yes" ] || [ "$paired" = "no" ]; }; then
      exit_abnormal_usage "Error: paired must be equal to yes or no."
    fi
    shift
    ;;
  -type | -tp)
    type="$2"
    echo "The value provided for type is $type"
    if ! { [ "$type" = "fastq" ] || [ "$type" = "bam" ]; }; then
      exit_abnormal_usage "Error: type must be equal to fastq or bam."
    fi
    shift
    ;;
  -threads | -th)
    threads="$2"
    MAX_PROC=$(nproc)
    echo "The value provided for threads is $threads"
    if ((threads <= 0)); then
      exit_abnormal_usage "Error: Threads must be greater than zero."
    elif ((threads > MAX_PROC)); then
      exit_abnormal_usage "Error: Thread number is greater than the maximum value ($MAX_PROC)."
    fi
    shift
    ;;
  -exome | -e)
    exome="$2"
    re_isanum='^[0-9]+$'
    echo "The value provided for exome length is $exome"
    if ! [[ $exome =~ $re_isanum ]] ; then
      echo "Error: Exome length must be a positive, whole number."
      exit_abnormal
      exit 1
    elif [ $exome -eq "0" ]; then
      echo "Error: Exome length must be greater than zero."
      exit_abnormal
      exit 1
    fi
    shift
    ;;
  -annovar | -a)
      annovar="$2"
      echo "The value provided for Annovar path is $annovar"
      shift
    ;;
  *)
    exit_abnormal_usage "Error: invalid parameter \"$1\"."
    shift
    ;;
  esac
  shift
done


if [[ -z "$input" ]] || [[ -z "$tumor" ]] || [[ -z "$normal" ]] || [[ -z "$index" ]] || [[ -z "$ifolder" ]] || [[ -z "$program" ]] || [[ -z "$type" ]] || [[ -z "$jv" ]] || [[ -z "$threads" ]] || [[ -z "$annovar" ]]; then
  exit_abnormal_usage "All parameters must be passed"
fi


if [[ "$type" == "fastq" ]]; then
  if [[ -z "$paired" ]]; then
    exit_abnormal_usage "All parameters must be passed"
  fi
fi

PATH_OUTPUT=$input/output
PATH_TRIM=$PATH_OUTPUT/trim
PATH_SAM_TUMOR=$PATH_OUTPUT/sam_tumor
PATH_SAM_NORMAL=$PATH_OUTPUT/sam_normal
PATH_BAM_TUMOR=$PATH_OUTPUT/bam_tumor
PATH_BAM_NORMAL=$PATH_OUTPUT/bam_normal
PATH_VCF=$PATH_OUTPUT/vcf
PATH_TXT=$PATH_OUTPUT/txt
PATH_INDEX=$ifolder
PATH_PROGRAM=$program
PATH_JAVA=$jv
PATH_PICARD=$PATH_PROGRAM/picard.jar
PATH_GATK=$PATH_PROGRAM/gatk-package-4.1.0.0-local.jar
PATH_VARSCAN=$PATH_PROGRAM/VarScan.v2.4.3.jar
PATH_ANNOVAR=$annovar

[[ ! -d $PATH_OUTPUT ]] && mkdir "$PATH_OUTPUT"
[[ ! -d $PATH_TRIM ]] && mkdir "$PATH_TRIM"
[[ ! -d $PATH_SAM_TUMOR ]] && mkdir "$PATH_SAM_TUMOR"
[[ ! -d $PATH_SAM_NORMAL ]] && mkdir "$PATH_SAM_NORMAL"
[[ ! -d $PATH_BAM_TUMOR ]] && mkdir "$PATH_BAM_TUMOR"
[[ ! -d $PATH_BAM_NORMAL ]] && mkdir "$PATH_BAM_NORMAL"
[[ ! -d $PATH_VCF ]] && mkdir "$PATH_VCF"
[[ ! -d $PATH_TXT ]] && mkdir "$PATH_TXT"

if (($threads > 7)); then
  RT=6
else
  RT=$threads
fi

if [[ "$type" == "fastq" ]]; then
  TUMOR_NAME=$tumor
  NORMAL_NAME=$normal
  if [[ "$paired" == "yes" ]]; then
    echo "Trimming"
    echo "Tumor trimming"
    $PATH_PROGRAM/TrimGalore-0.6.6/trim_galore -j "$RT" -o $PATH_TRIM --dont_gzip --paired "$input/${TUMOR_NAME}_1.fastq" "$input/${TUMOR_NAME}_2.fastq" || exit_abnormal_code "Unable to trim input file" 101
    echo "Normal trimming"
    $PATH_PROGRAM/TrimGalore-0.6.6/trim_galore -j "$RT" -o $PATH_TRIM --dont_gzip --paired "$input/${NORMAL_NAME}_1.fastq" "$input/${NORMAL_NAME}_2.fastq" || exit_abnormal_code "Unable to trim input file" 101
    echo "Tumor Alignment"
    bowtie2 -x $ifolder/${index}/$index -p $RT -1 $PATH_TRIM/${TUMOR_NAME}_val_1.fq -2 $PATH_TRIM/${TUMOR_NAME}_val_2.fq -S $PATH_SAM_TUMOR/${TUMOR_NAME}.sam || exit_abnormal_code "Unable to align input file" 102
    echo "Normal alignment"
    bowtie2 -x $ifolder/${index}/$index -p $RT -1 $PATH_TRIM/${NORMAL_NAME}_val_1.fq -2 $PATH_TRIM/${NORMAL_NAME}_val_2.fq -S $PATH_SAM_NORMAL/${NORMAL_NAME}.sam || exit_abnormal_code "Unable to align input file" 102
  elif [[ "$paired" == "no" ]]; then
    echo "Tumor trimming"
    $PATH_PROGRAM/TrimGalore-0.6.6/trim_galore -j "$RT" -o $PATH_TRIM --dont_gzip "$input/${TUMOR_NAME}.fastq" || exit_abnormal_code "Unable to trim input file" 101
    echo "Normal trimming"
    $PATH_PROGRAM/TrimGalore-0.6.6/trim_galore -j "$RT" -o $PATH_TRIM --dont_gzip "$input/${NORMAL_NAME}.fastq" || exit_abnormal_code "Unable to trim input file" 101
    echo "Tumor Alignment"
    bowtie2 -p "$RT" -x "$ifolder/${index}/$index" -U "$PATH_TRIM/${TUMOR_NAME}_trimmed.fq" -S "$PATH_SAM_TUMOR/${TUMOR_NAME}.sam" || exit_abnormal_code "Unable to align input file" 102
    echo "Normal Alignment"
    bowtie2 -p "$RT" -x "$ifolder/${index}/$index" -U "$PATH_TRIM/${NORMAL_NAME}_trimmed.fq" -S "$PATH_SAM_NORMAL/${NORMAL_NAME}.sam" || exit_abnormal_code "Unable to align input file" 102
  fi
    echo "Add or Replace Read Groups on Tumor"
    $PATH_JAVA -jar $PATH_PICARD AddOrReplaceReadGroups I=$PATH_SAM_TUMOR/${TUMOR_NAME}.sam O=$PATH_BAM_TUMOR/${TUMOR_NAME}_annotate.bam RGID=0 RGLB=lib1 RGPL=illumina RGPU=SN166 RGSM=$TUMOR_NAME CREATE_INDEX=TRUE || exit_abnormal_code "Unable to Add or Replace Read Groups on Tumor" 103
    echo "Add or Replace Read Groups on Normal"
    $PATH_JAVA -jar $PATH_PICARD AddOrReplaceReadGroups I=$PATH_SAM_NORMAL/${NORMAL_NAME}.sam O=$PATH_BAM_NORMAL/${NORMAL_NAME}_annotate.bam RGID=0 RGLB=lib1 RGPL=illumina RGPU=SN166 RGSM=$NORMAL_NAME CREATE_INDEX=TRUE || exit_abnormal_code "Unable to Add or Replace Read Groups on Normal" 103
elif [[ "$type" == "bam" ]]; then
  "bam analysis"
  TUMOR_NAME=$tumor
  NORMAL_NAME=$normal
  echo "Add or Replace Read Groups on Tumor"
  $PATH_JAVA -jar $PATH_PICARD AddOrReplaceReadGroups I=$input/${TUMOR_NAME}.bam O=$PATH_BAM_TUMOR/${TUMOR_NAME}_annotate.bam RGID=0 RGLB=lib1 RGPL=illumina RGPU=SN166 RGSM=$TUMOR_NAME CREATE_INDEX=TRUE || exit_abnormal_code "Unable to Add or Replace Read Groups on Tumor" 103
  echo "Add or Replace Read Groups on Normal"
  $PATH_JAVA -jar $PATH_PICARD AddOrReplaceReadGroups I=$input/${NORMAL_NAME}.bam O=$PATH_BAM_NORMAL/${NORMAL_NAME}_annotate.bam RGID=0 RGLB=lib1 RGPL=illumina RGPU=SN166 RGSM=$NORMAL_NAME CREATE_INDEX=TRUE || exit_abnormal_code "Unable to Add or Replace Read Groups on Normal" 103
fi


echo "Tumor analysis"
echo "BAM sorting"
$PATH_JAVA -jar $PATH_PICARD SortSam I=$PATH_BAM_TUMOR/${TUMOR_NAME}_annotate.bam O=$PATH_BAM_TUMOR/${TUMOR_NAME}_sorted.bam SORT_ORDER=coordinate || exit_abnormal_code "Unable to sort Tumor sample" 104
rm -r $PATH_SAM_TUMOR
echo "BAM ordering"
$PATH_JAVA -jar $PATH_PICARD ReorderSam I=$PATH_BAM_TUMOR/${TUMOR_NAME}_sorted.bam O=$PATH_BAM_TUMOR/${TUMOR_NAME}_ordered.bam SEQUENCE_DICTIONARY=$ifolder/${index}.dict CREATE_INDEX=TRUE || exit_abnormal_code "Unable to reorder Tumor sample" 105
echo "Duplicates elimination"
$PATH_JAVA -jar $PATH_PICARD MarkDuplicates I=$PATH_BAM_TUMOR/${TUMOR_NAME}_ordered.bam REMOVE_DUPLICATES=TRUE O=$PATH_BAM_TUMOR/${TUMOR_NAME}_nodup.bam CREATE_INDEX=TRUE M=$PATH_BAM_TUMOR/${TUMOR_NAME}_file.txt || exit_abnormal_code "Unable to delete duplicates in Tumor sample" 106
echo "tumor tmp remove"
rm $PATH_BAM_TUMOR/${TUMOR_NAME}_annotate.bam
rm $PATH_BAM_TUMOR/${TUMOR_NAME}_sorted.bam
rm $PATH_BAM_TUMOR/${TUMOR_NAME}_ordered.bam

echo "Normal analysis"
echo "BAM sorting"
$PATH_JAVA -jar $PATH_PICARD SortSam I=$PATH_BAM_NORMAL/${NORMAL_NAME}_annotate.bam O=$PATH_BAM_NORMAL/${NORMAL_NAME}_sorted.bam SORT_ORDER=coordinate || exit_abnormal_code "Unable to sort Normal sample" 104
rm -r $PATH_SAM_NORMAL/${NORMAL_NAME}.sam
echo "BAM ordering"
$PATH_JAVA -jar $PATH_PICARD ReorderSam I=$PATH_BAM_NORMAL/${NORMAL_NAME}_sorted.bam O=$PATH_BAM_NORMAL/${NORMAL_NAME}_ordered.bam SEQUENCE_DICTIONARY=$ifolder/${index}.dict CREATE_INDEX=TRUE || exit_abnormal_code "Unable to reorder Normal sample" 105
echo "Duplicates elimination"
$PATH_JAVA -jar $PATH_PICARD MarkDuplicates I=$PATH_BAM_NORMAL/${NORMAL_NAME}_ordered.bam REMOVE_DUPLICATES=TRUE O=$PATH_BAM_NORMAL/${NORMAL_NAME}_nodup.bam CREATE_INDEX=TRUE M=$PATH_BAM_NORMAL/${NORMAL_NAME}_file.txt || exit_abnormal_code "Unable to delete duplicates in Normal sample" 106
echo "normal tmp remove"
rm $PATH_BAM_NORMAL/${NORMAL_NAME}_annotate.bam
rm $PATH_BAM_NORMAL/${NORMAL_NAME}_sorted.bam
rm $PATH_BAM_NORMAL/${NORMAL_NAME}_ordered.bam


echo "Variant calling with GATK"

$PATH_JAVA -jar $PATH_GATK Mutect2 -R $ifolder/${index}.fa -I $PATH_BAM_TUMOR/${TUMOR_NAME}_nodup.bam -tumor $TUMOR_NAME -I $PATH_BAM_NORMAL/${NORMAL_NAME}_nodup.bam -normal $NORMAL_NAME -O $PATH_VCF/${TUMOR_NAME}.vcf -mbq 25 || exit_abnormal_code "Unable to call variants with Mutect2" 107
echo "VCF filtering"
$PATH_JAVA -jar $PATH_GATK FilterMutectCalls -V $PATH_VCF/${TUMOR_NAME}.vcf -O $PATH_VCF/${TUMOR_NAME}_filtered.vcf || exit_abnormal_code "Unable to filter Mutect variants" 108
echo "VCF pass"
awk -F '\t' '{if($0 ~ /\#/) print; else if($7 == "PASS") print}' $PATH_VCF/${TUMOR_NAME}_filtered.vcf > $PATH_VCF/${TUMOR_NAME}_pass.vcf


echo "Variant calling with VarScan"

samtools mpileup -B -f $ifolder/${index}.fa -Q 25 -L 250 -d 250 $PATH_BAM_NORMAL/${NORMAL_NAME}_nodup.bam $PATH_BAM_TUMOR/${TUMOR_NAME}_nodup.bam | $PATH_JAVA -jar $PATH_VARSCAN somatic -mpileup $PATH_VCF/${TUMOR_NAME}_somatic.vcf --min-var-freq 0.10 --strand-filter 1 --output-vcf 1 || exit_abnormal_code "Unable to call variants with Varscan" 109
$PATH_JAVA -jar $PATH_VARSCAN processSomatic $PATH_VCF/${TUMOR_NAME}_somatic.vcf.indel || exit_abnormal_code "Unable to process somatic indel variants" 110
$PATH_JAVA -jar $PATH_VARSCAN processSomatic $PATH_VCF/${TUMOR_NAME}_somatic.vcf.snp || exit_abnormal_code "Unable to process somatic snp variants" 111
$PATH_JAVA -jar $PATH_VARSCAN somaticFilter $PATH_VCF/${TUMOR_NAME}_somatic.vcf.snp.Somatic.hc -min-var-freq 0.10 -indel-file $PATH_VCF/${TUMOR_NAME}_somatic.vcf.indel -output-file $PATH_VCF/${TUMOR_NAME}_somatic.vcf.snp.Somatic.hc.filter || exit_abnormal_code "Unable to filter somatic varscan variants" 112
$PATH_JAVA -jar $PATH_VARSCAN compare $PATH_VCF/${TUMOR_NAME}_somatic.vcf.indel.Somatic.hc $PATH_VCF/${TUMOR_NAME}_somatic.vcf.snp.Somatic.hc.filter merge $PATH_VCF/${TUMOR_NAME}_somatic_merge.vcf || exit_abnormal_code "Unable to merge varscan variants" 113
$PATH_JAVA -jar $PATH_VARSCAN compare $PATH_VCF/${TUMOR_NAME}_somatic_merge.vcf $PATH_VCF/${TUMOR_NAME}_pass.vcf intersect $PATH_VCF/${TUMOR_NAME}_intersect.vcf || exit_abnormal_code "Unable to compare and intersect vcf" 114

echo "VCF final creation"
perl $PATH_ANNOVAR/convert2annovar.pl -format vcf4old $PATH_VCF/${TUMOR_NAME}_intersect.vcf -outfile $PATH_VCF/${TUMOR_NAME}_final.vcf -includeinfo

echo "Annovar annotation"
cd $PATH_ANNOVAR

perl annotate_variation.pl $PATH_VCF/${TUMOR_NAME}_final.vcf ./ -vcfdbfile humandb/snp151_$index.vcf -buildver $index -filter -dbtype vcf
perl annotate_variation.pl -filter -dbtype cosmic70 -buildver $index -out $PATH_TXT/${TUMOR_NAME} $PATH_VCF/${TUMOR_NAME}_final.vcf.${index}_vcf_filtered humandb/
perl annotate_variation.pl -filter -dbtype esp6500siv2_all -buildver $index -out $PATH_TXT/${TUMOR_NAME} $PATH_TXT/${TUMOR_NAME}.${index}_cosmic70_filtered humandb/
perl annotate_variation.pl -filter -dbtype 1000g2015aug_all -buildver $index -out $PATH_TXT/$TUMOR_NAME $PATH_TXT/${TUMOR_NAME}.${index}_esp6500siv2_all_filtered humandb/
perl annotate_variation.pl -dbtype refGene -buildver $index -out $PATH_TXT/${TUMOR_NAME} $PATH_TXT/${TUMOR_NAME}.${index}_ALL.sites.2015_08_filtered -otherinfo humandb/

sed '/^[[:blank:]]*$/d' $PATH_TXT/*.${index}_ALL.sites.2015_08_filtered | wc -l >  $PATH_TXT/${TUMOR_NAME}.txt

Rscript TMB_calculation.R $tumor $PATH_TXT $exome

rm -r $PATH_BAM_NORMAL
rm -r $PATH_BAM_TUMOR
