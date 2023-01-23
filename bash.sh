#!/bin/bash
if [[ $(($1+$2)) -ge 100 ]]
then echo "more_or_equal_than_100"
else
echo "less_than_100"
fi
