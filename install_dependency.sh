#Before launching the install dependency install Annovar!
#Va bene perchi ha i sudo sennò cercare i corrispettivi di anaconda e creare una divisione tra sudo e anaconda come paramentro
#Parametro per CrossMap
#Path per dove creare index e programmi
#Creareindex si o no? dipende dall'utente, magari li ha
#Prima installare sudo apt install -y openjdk-8-jre oppure
# https://download.java.net/openjdk/jdk8u41/ri/openjdk-8u41-b04-linux-x64-14_jan_2020.tar.gz
#tar xzf openjdk-8u41-b04-linux-x64-14_jan_2020.tar.gz
#cd java-se-8u41-ri/bin/java
#Se java 8 installato con sudo mettere in path java solo java
#tar xzf annovar.latest.tar.gz
#if per hg19/hg38/both

#!/bin/bash

PROJ_PATH=$path
PATH_PROGRAM=$PROJ_PATH/program
PATH_INDEX=$PROJ_PATH/index
PATH_JAVA=$jv
PATH_ANNOVAR=$annovar

mkdir $PATH_INDEX
mkdir $PATH_PROGRAM


if [ $perm == "yes" ];
then #Controlla se ho scritto l'if giusto
  sudo apt install -y samtools
  sudo apt install -y bowtie2
  sudo apt install -y cutadapt
  sudo apt install -y fastqc
  sudo apt install -y python3-pip
  sudo apt install -y unzip
  sudo pip3 install CrossMap
else
  conda install -c bioconda samtools
  conda install -c bioconda bowtie2
  conda install -c bioconda trim-galore
  conda install -c bioconda fastqc
  conda install -c conda-forge unzip
  conda install -c bioconda crossmap
  #installazioni conda - inserire nella guida da dove si installa anaconda e di installare un ambiente python3
fi

cd $PATH_PROGRAM
curl -fsSL https://github.com/FelixKrueger/TrimGalore/archive/0.6.6.tar.gz -o trim_galore.tar.gz
tar xvzf trim_galore.tar.gz
wget https://github.com/broadinstitute/picard/releases/download/2.26.2/picard.jar
wget https://github.com/broadinstitute/gatk/releases/download/4.1.0.0/gatk-4.1.0.0.zip
unzip gatk-4.1.0.0.zip
mv gatk-4.1.0.0/gatk-package-4.1.0.0-local.jar ./
wget https://github.com/dkoboldt/varscan/archive/refs/heads/master.zip
unzip master.zip
mv varscan-master/VarScan.v2.4.3.jar ./
cd
cd $PATH_INDEX
wget https://genome-idx.s3.amazonaws.com/bt/GRCh38_noalt_as.zip
unzip GRCh38_noalt_as.zip
mv GRCh38_noalt_as hg38 #Cambia il nome interno
wget https://genome-idx.s3.amazonaws.com/bt/hg19.zip
unzip hg19.zip
wget https://hgdownload.soe.ucsc.edu/goldenPath/hg38/bigZips/hg38.fa.gz
gunzip hg38.fa.gz
samtools faidx hg38.fa
wget http://hgdownload.cse.ucsc.edu/goldenpath/hg19/bigZips/hg19.fa.gz
gunzip hg19.fa.gz
samtools faidx hg19.fa
$PATH_JAVA -jar $PATH_PROGRAM/picard.jar CreateSequenceDictionary R=hg19.fa O=hg19.dict
$PATH_JAVA -jar $PATH_PROGRAM/picard.jar CreateSequenceDictionary R=hg38.fa O=hg38.dict
wget http://hgdownload.soe.ucsc.edu/goldenPath/hg19/liftOver/hg19ToHg38.over.chain.gz
cd


cd $PATH_ANNOVAR
perl annotate_variation.pl -downdb -webfrom annovar 1000g2015aug humandb -buildver $index
perl annotate_variation.pl -downdb -webfrom annovar refgene humandb -buildver $index
perl annotate_variation.pl -downdb -webfrom annovar esp6500siv2_all humandb -buildver $index

#Inserire scaricamento dbsnp e cosmic
