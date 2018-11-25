#!/bin/bash
## snapshot.csh  <snapshot_name> 
##
## Create a new snapshot directory and copy this hardcoded list of files inside
##

## Files to copy


files='../src/z80tube.v ../src/z80tube.ucf ../xilinx/z80tube.rpt ../xilinx/z80tube.syr ../xilinx/z80tube.tim ../xilinx/z80tube.jed'

snapshot_name=$1
if [ -d $snapshot_name ] ; then
    echo "WARNING: directory $snapshot_name already exists, overwrite ? 
(Y/N)"
    read YESNO
    shopt -s nocasematch    
    case "$YESNO" in 
    "Y" ) echo "ok" ;;
    *) return 1;;
    esac
    rm -rf $snapshot_name
fi
mkdir $snapshot_name


for i in $files ; do
   cp $i $snapshot_name
done

