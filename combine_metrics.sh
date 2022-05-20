
# Script for summarizing Basespace Dragen output for Novaseq

METRICS_CSV=$1
PICARD_CSV=$2
RUN_DIRECTORY=$3

if [ -z "${METRICS_CSV}" ];then
 echo "error: metrics.csv location not set in parameter 1"
 #exit 0
fi
if [ -z "${PICARD_CSV}" ];then
 echo "error: PICARD_CSV location not set in parameter 2"
 #exit 0
fi
if [ -z "${RUN_DIRECTORY}" ];then
 echo "error: RUN_DIRECTORY location not set in parameter 3"
 #exit 0
fi

exit 1

###############################################################################
#cat metrics_r37.csv|csvtk headers
#cat metrics_headers | awk '{printf("\"%s\",",$0)}'


cat ${METRICS_CSV} | csvtk cut -f"Sample ID","Percent Q30 bases","Fragment length median","Total PF reads","Percent unique aligned reads","Percent duplicate aligned reads","Mean target coverage depth","Uniformity of coverage (Pct > 0.2*mean)","Estimated Sample Contamination","SNVs","SNV Het/Hom ratio","SNV Ts/Tv ratio","Indels","Indel Het/Hom ratio","Insertions","Insertion Het/Hom ratio","Deletions","Deletion Het/Hom ratio","SV Insertions","SV Deletions","SV Tandem Duplications","SV Breakends" > metrics_tmp.csv

###############################################################################
#cat picard_r37.csv|csvtk headers
#cat picard_headers | awk '{printf("\"%s\",",$0)}'

cat ${PICARD_CSV} | csvtk cut -f -"SAMPLE",-"LIBRARY",-"READ_GROUP" | csvtk mutate -f SAMPLE_ID -p "^(.+).HsMetrics.txt" -n sampleID > picard_mod.csv


cat picard_mod.csv | csvtk cut -f"sampleID","TOTAL_READS","PCT_USABLE_BASES_ON_TARGET","FOLD_80_BASE_PENALTY","FOLD_ENRICHMENT","ZERO_CVG_TARGETS_PCT","PCT_TARGET_BASES_2X","PCT_TARGET_BASES_10X","PCT_TARGET_BASES_20X","PCT_TARGET_BASES_30X","PCT_TARGET_BASES_100X","AT_DROPOUT","GC_DROPOUT" > picard_tmp.csv

###############################################################################
csvtk join -f 1 picard_tmp.csv metrics_tmp.csv > combined_metrics.csv

#csvtk csv2xlsx R37_metrics.csv -o R37_metrics.xlsx
###############################################################################


#conda install illumina-interop
#
# This part has to be run on the Novaseq Run output.
interop_summary ${RUN_DIRECTORY} | head -9 | tail -n +3 | sed -e 's/ //g' \
> summaryA.csv


# This part has to be run on the Novaseq Run output.
interop_summary ${RUN_DIRECTORY} | tail -35 | head -32 | sed -e 's/ //g' | grep -v "^Read" \
| csvtk cut -f"Lane","Surface","ClusterPF","%Occupied","LegacyPhasing/PrephasingRate","Phasingslope/offset","Prephasingslope/offset","Reads","ReadsPF","%>=Q30","Yield","Aligned","Error","IntensityC1" \
| csvtk grep -f Surface -p "-" \
| awk '{if(NR==1){printf("Read,%s\n",$0)}
        else if(NR==2||NR==3){printf("1,%s\n",$0)}
        else if(NR==4||NR==5){printf("2,%s\n",$0)}
        else if(NR==6||NR==7){printf("3,%s\n",$0)}
        else if(NR==8||NR==9){printf("4,%s\n",$0)}
        }' \
| csvtk cut -f"Read","Lane","ClusterPF","%Occupied","LegacyPhasing/PrephasingRate","Phasingslope/offset","Prephasingslope/offset","Reads","ReadsPF","%>=Q30","Yield","Aligned","Error","IntensityC1" \
> summaryB.csv
#| csvtk pretty

