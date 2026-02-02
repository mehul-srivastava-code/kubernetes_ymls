#!/bin/bash
target="basic_k8s_file"
mkdir -p "$target"
files=(*.yml)
shopt -s nullglob
if [${#files[@]} -eq 0]
then
   :
else
    mv  "${files[@]}"  "$target"
fi  
