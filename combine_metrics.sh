# Script for summarizing Basespace Dragen output for Novaseq

METRICS_CSV=$1
PICARD_CSV=$2
RUN_NAME=$3

if [ -z "${METRICS_CSV}" ];then
 echo "error: metrics.csv location not set in parameter 1"
 exit 1
fi
if [ -z "${PICARD_CSV}" ];then
 echo "error: PICARD_CSV location not set in parameter 2"
 exit 1
fi
if [ -z "${RUN_NAME}" ];then
 echo "error: RUN_DIRECTORY location not set in parameter 3"
 exit 1
fi

RUN_DIRECTORY=/mnt/data/Basemount/Basespa/Runs/${RUN_NAME}/Files
###############################################################################
#cat metrics_r37.csv|csvtk headers
#cat metrics_headers | awk '{printf("\"%s\",",$0)}'


cat ${METRICS_CSV} | csvtk cut -f"Sample ID","Percent Q30 bases","Fragment length median","Total PF reads","Percent unique aligned reads","Percent duplicate aligned reads","Mean target coverage depth","Uniformity of coverage (Pct > 0.2*mean)","Estimated Sample Contamination","SNVs","SNV Het/Hom ratio","SNV Ts/Tv ratio","Indels","Indel Het/Hom ratio","Insertions","Insertion Het/Hom ratio","Deletions","Deletion Het/Hom ratio","SV Insertions","SV Deletions","SV Tandem Duplications","SV Breakends" > metrics_tmp.csv

###############################################################################
#cat picard_r37.csv|csvtk headers
#cat picard_headers | awk '{printf("\"%s\",",$0)}'
cat picard.csv | head -1 | cut -d',' -f1-44 > picard_mod1.csv
cat picard.csv | tail -n +2 >> picard_mod1.csv
cat picard_mod1.csv | csvtk mutate -f SAMPLE_ID -p "^(.+).HsMetrics.txt" -n sampleID > picard_mod.csv

#cat ${PICARD_CSV} | csvtk cut -f -"SAMPLE",-"LIBRARY",-"READ_GROUP" | csvtk mutate -f SAMPLE_ID -p "^(.+).HsMetrics.txt" -n sampleID > picard_mod.csv


cat picard_mod.csv \
| csvtk cut -f"sampleID","TOTAL_READS","PCT_USABLE_BASES_ON_TARGET","FOLD_80_BASE_PENALTY","FOLD_ENRICHMENT","ZERO_CVG_TARGETS_PCT","PCT_TARGET_BASES_2X","PCT_TARGET_BASES_10X","PCT_TARGET_BASES_20X","PCT_TARGET_BASES_30X","PCT_TARGET_BASES_100X","AT_DROPOUT","GC_DROPOUT"  \
 > picard_tmp.csv

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

###############################################################################
# Combine CSVs into one xlsx file
#pip install xlsxwriter
#pip install plotly.express
python << EOF
import pandas as pd
import xlsxwriter
import plotly.express as px
workbook=xlsxwriter.Workbook("${RUN_NAME}_metrics.xlsx")
writer=pd.ExcelWriter("${RUN_NAME}_metrics.xlsx",engine='xlsxwriter')
pd.read_csv('combined_metrics.csv').to_excel(writer,'Summary',freeze_panes=[1,1],index=False)
pd.read_csv('summaryA.csv').to_excel(writer,'InteropA',freeze_panes=[1,0],index=False)
pd.read_csv('summaryB.csv').to_excel(writer,'InteropB',freeze_panes=[1,0],index=False)
pd.read_csv('metrics.csv').to_excel(writer,'Dragen_Metrics',freeze_panes=[1,0],index=False)
pd.read_csv('picard.csv').to_excel(writer,'Dragen_Picard',freeze_panes=[1,0],index=False)
writer.save()
EOF

