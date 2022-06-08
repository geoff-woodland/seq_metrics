# Script for summarizing Basespace Dragen output for Novaseq

RUN_NAME=$1

if [ -z "${RUN_NAME}" ];then
 echo "error: RUN_DIRECTORY location not set in parameter 1"
 exit 1
fi

BASEMOUNT_DIR=/mnt/data/Basemount/Basespa
RUN_DIRECTORY=${BASEMOUNT_DIR}/Runs/${RUN_NAME}/Files
PROJ_DIRECTORY=${BASEMOUNT_DIR}/Projects/${RUN_NAME}/AppResults/

METRICS_CSV="metrics.csv"
PICARD_CSV="picard.csv"

###############################################################################
# get sample IDs processed.
# an exception for the first run which was done a little differently
# on Basespace
if [ ${RUN_NAME} == "R37_2022-04-22_A_AH" ]
then
  PROJ_DIRECTORY=/mnt/data/Novaseq/R37_dragen_enrich_3.9.5/links
fi
sampleIDs=( $(ls ${PROJ_DIRECTORY}) )

###############################################################################
#Gather hsMetrics from each sample file
sample=${sampleIDs[0]}
tail -4 ${PROJ_DIRECTORY}/${sample}/Files/"Additional Files"/${sample}.HsMetrics.txt \
  | head -1 \
  | awk -F'\t' '{printf("SAMPLE_ID\t%s\n",$0)}' \
  > picard.tsv
for sample in ${sampleIDs[@]};
do
  tail -3 ${PROJ_DIRECTORY}/${sample}/Files/"Additional Files"/${sample}.HsMetrics.txt \
  | head -1 \
  | awk -F'\t' -v sample=${sample} '{printf("%s\t%s\n",sample,$0)}' \
  | tr '\t' ',' \
  >> picard.tsv
done
cat picard.tsv | tr '\t' ',' \
  > picard.csv

#Gather Dragen metrics from each sample file
sample=${sampleIDs[0]}
tail -n +4 ${PROJ_DIRECTORY}/${sample}/Files/Additional\ Files/${sample}.summary.csv \
  | csvtk transpose | head -1 > metrics.csv
for sample in ${sampleIDs[@]};
do
  tail -n +4 ${PROJ_DIRECTORY}/${sample}/Files/Additional\ Files/${sample}.summary.csv \
  | csvtk transpose | tail -1 >> metrics.csv
done

###############################################################################
# select desired Dragen metrics.
cat ${METRICS_CSV} | csvtk cut -f"Sample ID","Percent Q30 bases","Fragment length median","Total PF reads","Percent unique aligned reads","Percent duplicate aligned reads","Mean target coverage depth","Uniformity of coverage (Pct > 0.2*mean)","Estimated Sample Contamination","SNVs","SNV Het/Hom ratio","SNV Ts/Tv ratio","Indels","Indel Het/Hom ratio","Insertions","Insertion Het/Hom ratio","Deletions","Deletion Het/Hom ratio","SV Insertions","SV Deletions","SV Tandem Duplications","SV Breakends" > metrics_tmp.csv

###############################################################################
# select desired picard metrics
cat picard.csv \
| csvtk cut -f"SAMPLE_ID","TOTAL_READS","PCT_USABLE_BASES_ON_TARGET","FOLD_80_BASE_PENALTY","FOLD_ENRICHMENT","ZERO_CVG_TARGETS_PCT","PCT_TARGET_BASES_2X","PCT_TARGET_BASES_10X","PCT_TARGET_BASES_20X","PCT_TARGET_BASES_30X","PCT_TARGET_BASES_100X","AT_DROPOUT","GC_DROPOUT"  \
 > picard_tmp.csv

###############################################################################
csvtk join -f 1 picard_tmp.csv metrics_tmp.csv > combined_metrics.csv


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

# Do index summary.
interop_index-summary ${RUN_DIRECTORY} | tail -n +2 \
	| awk '{if(match($1,"^Lane")){printf("%s%s ## ## ## ## ##\n",$1,$2)}
        else if(match($1,"Total")){printf("Total_Reads PF_Reads %_Read_Identified_(PF) CV Min Max\n")}
        else if(match($1,"Index")){printf("IndexNumber SampleId Project Index_1_(I7) Index_2_(I5) %_Read_Identified(PF)\n")}
        else {for(i=1;i<NF;i++){printf("%s ",$i)};printf("%s",$NF);printf("\n")}}' \
        | tr -s ' ' | tr ' ' ',' \
> index_summary.csv

###############################################################################
# get versions and options

# get app version
APP_VERSION=$(cat ${PROJ_DIRECTORY}/"${sampleIDs[0]}"/Files/appVersion.log)

echo ${APP_VERSION} > versions.csv
echo "File generation time: $(date)" >> versions.csv

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
pd.read_csv('index_summary.csv').to_excel(writer,'indexes',index=False)
pd.read_csv('versions.csv').to_excel(writer,'versions',index=False)
writer.save()
EOF

