#!/bin/bash

: '
Description:
Reads a multiline variable line-by-line to and returns it as an array of strings.

Parameters:
$1: VAR_NAME_TO_READ: Variable to read, that its value is a multiline string.

Example Of Use:
```
var=$(readVar VAR_NAME_TO_READ)
for line in $var; do
    echo $line
done
```
'
readVar(){
    var="$($1)"
    local lineList=()
    while IFS= read -r line || [[ -n "$line" ]]; do
        [ "${line:0:1}" = "#" ] && continue  # Skip all lines that begin with '#'
        lineList+=("$line")
        echo DEBUG: line: $line
    done <<< "$var"
    echo "${lineList[@]}"
}


: '
Description:
Reads a file line-by-line to and returns it as an array of strings.

Parameters:
$1: FILE_NAME_TO_READ: Path of the file to read.

Example Of Use:
```
file=$(readFile FILE_NAME_TO_READ)
for line in $file; do
    echo $line
done
```
'
readFile(){
    local lineList=()
    while IFS= read -r line || [[ -n "$line" ]]; do
        [ "${line:0:1}" = "#" ] && continue  # Skip all lines that begin with '#'
        lineList+=("$line")
    done < "$1"
    echo "${lineList[@]}"
}
