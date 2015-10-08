#!/bin/bash

#-----------------------------------------------------------------------------------------
#-----------------------------------------------------------------------------------------
# Author      :  Sudhir Jain
# Date        :  June 29 2015
# Description : Script verifies the ESA datasets for RAW, SLC, GRD and OCN put the
#               verified datasets to RDSI Repository.  This scrips is maintains QA/QC for
#               ESA datasets
# Revision:
#               OCN data transfer has been added to the system. ( 21 JLY  2015 )
#               Datasets are moved to current directory and verification failed
#               datasets are moved to PRODUCT_FAILED directory.
#
# Date         : Aug 18, 2015
# Description  : Checking a file locked in I/O operation
#
#
#-----------------------------------------------------------------------------------------
#-----------------------------------------------------------------------------------------


echo "Starting Script ..."

ds_path="/g/data/v10/sentinel_hub_download/RDSI_CACHE/"
ds_path_failed="/g/data/v10/sentinel_hub_download/PRODUCT_FAILED"
dest_ds_p="/g/data/fj7/SAR/Sentinel-1/"

display_usage() {
   echo "Usage: ./check_valid_ds.sh  text file "
}

if [ $# -eq 0 ]
then
   display_usage
   exit 1
fi

#-----------------------------------------------------------------------------------------
echo "Removing temporary files ........."
#-----------------------------------------------------------------------------------------
for i in RAW GRD SLC OCN
do
   rm -rvf non_processed_ds_$i.txt
   rm -rvf processed_ds_$i.txt
   rm -rvf ds_last_prcoessed_$i.txt
done

#-----------------------------------------------------------------------------------------
#-----------------------------------------------------------------------------------------

is_directory() {
  if [[ -d $1 ]]
     then
       return 0
     else
       return 1
   fi
}

display_counter() {

    echo "Dataset Count                  = $counter"
    echo "Total Dataset Count            = $total_count"
    echo "Total Dataset Record Count     = $rcount"
    echo "------------------------------------------------------------"

    if [ $rcount -ge $total_count ]
       then
         exit 1
    fi
}


#-----------------------------------------------------------------------------------------
#-----------------------------------------------------------------------------------------

counter=0
rcount=0
total_count=`cat $1|wc -l`
while read line
do

        if [[ $line =~ "SLC" ]]
        then
            d_type="SLC"
        elif [[ $line =~ "GRD" ]]
        then
            d_type="GRD"
        elif [[ $line =~ "RAW" ]]
        then
            d_type="RAW"
        elif [[ $line =~ "OCN" ]]
        then
            d_type="OCN"
        fi

        echo "ds_type = $d_type "

        rdsi_folder=${line:17:4}-${line:21:2}
        dest_ds_p_1=$dest_ds_p$d_type/$rdsi_folder

        echo "RDSI folder = $dest_ds_p_1"
        echo "-------------------------------------------"
        rcount=$((rcount+1))

        if [ ! -d $dest_ds_p_1 ]
        then
                echo "Directory $$dest_ds_p_1 not existing "
                exit 1
        fi

#       Checking the file locked in I/O operation

        var=$(/usr/sbin/lsof $ds_path/$line)
        if [ ! -z "$var" ]
        then
            echo "File $line Locked in I/O Operation"
            continue
        fi

        if  [ -f $dest_ds_p_1/$line.zip ]
        then
                echo "File Exist"
                counter=$((counter+1))
                display_counter
                continue
        else
                echo "File not existing "
        fi

        echo $ds_path/$line
#       rsync -aP  $ds_path/$line .

#       Moving the file to current directory

        mv $ds_path/$line .

        echo "UNziping  $line"
        if ! unzip $line &> /dev/null; then
                echo "Invalid dataset file"
                echo "$line" >> non_processed_ds_$d_type.txt
                mv $line $ds_path_failed/
        else
            if [[ $line =~ "SLC" ]] || [[ $line =~ "GRD" ]]
            then
                files=(line.SAFE/measurement/*.tff)
                if [[ "${#files[@]}" -gt 0 ]]
                then

                   counter=$((counter+1))
                   echo "Tiff image exist for $line" >>  processed_ds_$d_type.txt
                   mv $line $dest_ds_p_1/$line.zip
                   chmod 777 $dest_ds_p_1/$line.zip
                   chown -R ssj547:fj7 $dest_ds_p_1/$line.zip
                   echo "$line" > ds_last_prcoessed_$d_type.txt
                else
                   echo "Invalid dataset file $line"
                   echo "$line" >> non_processed_ds_$d_type.txt
                   mv $line $ds_path_failed/
                fi

            fi

# Checking RAW files

            if [[ $line =~ "RAW" ]]
            then
               files=(line.SAFE/*.dat)
               if [[ "${#files[@]}" -gt 0 ]]
                   then
                     counter=$((counter+1))
                     echo "Data exist for $line" >>  processed_ds_$d_type.txt
                     mv $line $dest_ds_p_1/$line.zip
                     chmod 777 $dest_ds_p_1/$line.zip
                     chown -R ssj547:fj7 $dest_ds_p_1/$line.zip
                     echo "$line" > ds_last_prcoessed_$d_type.txt
                   else
                     echo "Unable to unzip $line .... "
                     echo "Invalid dataset file ...."
                     echo "$line" >> non_processed_ds_$d_type.txt
                     mv $line $ds_path_failed/
               fi
            fi

# Checking OCN files

            if [[ $line =~ "OCN" ]]
            then
               files=(line.SAFE/measurement/*.nc)
               if [[ "${#files[@]}" -gt 0 ]]
                   then
                     counter=$((counter+1))
                     echo "Data exist for $line" >>  processed_ds_$d_type.txt
                     mv $line $dest_ds_p_1/$line.zip
                     chmod 777 $dest_ds_p_1/$line.zip
                     chown -R ssj547:fj7 $dest_ds_p_1/$line.zip
                     echo "$line" > ds_last_prcoessed_$d_type.txt
                   else
                     echo "Unable to unzip $line .... "
                     echo "Invalid dataset file ...."
                     echo "$line" >> non_processed_ds_$d_type.txt
                     mv $line $ds_path_failed/
               fi
            fi
        fi

        if [ -f $line ]
        then
           rm -rvf $line
        fi
        rm -rvf $line.SAFE

        display_counter

done < $1
