#!/bin/bash   
rm controls_spritpreisaut.txt

for file in FHEM/*;
  do
   echo "DEL ./$file" >> controls_spritpreisaut.txt
   out="UPD "$(stat -c %y  $file | cut -d. -f1 | awk '{printf "%s_%s",$1,$2}')" "$(stat -c %s $file)" $file";
   echo ${out} >> controls_spritpreisaut.txt
done

# CHANGED file
echo "FHEM SPRITPREISAUT last changes:" > CHANGED
echo $(date +"%Y-%m-%d") >> CHANGED
echo " - $(git log -1 --pretty=%B)" >> CHANGED

