#!/bin/bash
scortotal=0
start=0
for (( i = $start ; i < $1 ; i++ )); do
echo "lancer numéro $i"
c1=$(($RANDOM%20+1))
c2=$(($RANDOM%20+1))
echo "lancer1 : $c1, lancer2 : $c2"
if [[ $c1 -eq $c2 ]]; then
echo "your_number_is_0"
scoretotal=0
break
fi
scoretotal=$((scoretotal+c1+c2))
echo score total actuel : $scoretotal
echo --------------------
done
echo "votre score total est : $scoretotal"
