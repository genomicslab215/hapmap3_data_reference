#!/bin/bash

# Exit immediately if a command exits with a non-zero status
set -e

# Define directories and file paths
refdir='~/reference'
qcdir='~/qc'
mkdir -p $qcdir/plink_log

# Step 1: Download and unzip Hapmap phase III data
cd $refdir
ftp_url="ftp://ftp.ncbi.nlm.nih.gov/hapmap/genotypes/2009-01_phaseIII/plink_format/"
prefix="hapmap3_r2_b36_fwd.consensus.qc.poly"

echo "Downloading HapMap phase III data..."
wget -q ${ftp_url}${prefix}.map.bz2
bunzip2 ${prefix}.map.bz2
wget -q ${ftp_url}${prefix}.ped.bz2
bunzip2 ${prefix}.ped.bz2
wget -q ${ftp_url}relationships_w_pops_121708.txt

# Step 2: Convert PLINK text files to binary format
echo "Converting PLINK files to binary format..."
plink --file $refdir/$prefix --make-bed --out $refdir/HapMapIII_b37
mv $refdir/HapMapIII_b37.log $qcdir/plink_log

# Step 3: Update annotation using UCSC liftOver tool
echo "Updating genome build using liftOver..."
wget -q https://genome.ucsc.edu/cgi-bin/hgLiftOver -O liftOver
chmod +x liftOver
wget -q http://hgdownload.soe.ucsc.edu/goldenPath/hg19/liftOver/hg18ToHg19.over.chain.gz
gunzip hg18ToHg19.over.chain.gz

# Convert .bim to UCSC bed format with zero-based positions
echo "Converting .bim file to UCSC bed format..."
awk '{print "chr" $1, $4 - 1, $4, $2}' $refdir/HapMapIII_b37.bim | \
sed 's/chr23/chrX/' | sed 's/chr24/chrY/' > $refdir/HapMapIII_b37_toLift.bed

# Perform liftOver
./liftOver $refdir/HapMapIII_b37_toLift.bed hg18ToHg19.over.chain $refdir/HapMapIII_b37_lifted.bed $refdir/HapMapIII_b37_unMapped.bed

# Extract mappable variants and their updated positions
echo "Extracting mapped variants and updated positions..."
awk '{print $4}' $refdir/HapMapIII_b37_lifted.bed > $refdir/HapMapIII_b37_mapped_snps.txt
awk '{print $4, $3}' $refdir/HapMapIII_b37_lifted.bed > $refdir/HapMapIII_b37_updated_positions.txt

# Step 4: Update the reference data with new positions
echo "Updating reference data with new positions..."
plink --bfile $refdir/HapMapIII_b37 \
      --extract $refdir/HapMapIII_b37_mapped_snps.txt \
      --update-map $refdir/HapMapIII_b37_updated_positions.txt \
      --make-bed \
      --out $refdir/HapMapIII_b37_gc
mv $refdir/HapMapIII_b37_gc.log $qcdir/plink_log

echo "Update complete. The HapMap III dataset is now in build GRCh37."
