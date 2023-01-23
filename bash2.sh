#!/bin/bash


if [[ $1==fire && $2==water ]];
then echo "it's_not_very_effective"
elif [[ $1==fire &&  $2==grass ]];
then echo "it's_very_effective"
elif [[ $1==water &&  $2==fire ]];
then echo "it's_very_effective"
elif [[ $1==grass &&  $2==water ]];
then echo "it's_very_effective"
elif [[ $1==grass &&  $2==fire ]];
then echo "it's_not_very_effective"
elif [[ $1==water &&  $2==grass ]];
then echo "it's_not_very_effective"
fi

