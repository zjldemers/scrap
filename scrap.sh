#!/bin/bash


# Starting with just placing an item in the trash with appropriate metadata
# Will want more operations later though, thus the op variable usage

### CONSTANTS
cOP_SCRAP=0     # scrap a file (place it in the trash with metadata)

cTRASHLOC="$HOME/.local/share/Trash" # overall trash location
cFILELOC="$cTRASHLOC/files/"         # location of scrapped files
cINFOLOC="$cTRASHLOC/info/"          # location of scrapped file metadata files
cINFOEXT=".trashinfo"                # file extension for metadata files

### VARIABLES
op=$cOP_SCRAP   # operation selected to perform
filename=""     # name of file to be operated on

### FUNCTIONS
function GetDate() {
    # return the current date/time in the appropriate format for the .trashinfo file
    echo "$(date '+%Y-%m-%dT%H:%M:%S')"
}
function GetScrapInfo() {
    ret="   Items at top level in scrap:    $(ls -A $cFILELOC | wc -l)\n"
    ret+="   Items including subdirectories: $(find $cFILELOC -mindepth 1 | wc -l)\n"
    total="$(du -ach $cFILELOC | tail -1)"
    ret+="   Total storage used:             ${total%%[[:space:]]*}B\n"
    echo "$ret"
}


### MAIN SCRIPT
# TODO: add more operations dependent upon arguments given

if [ $# == 0 ]; then
    # no arguments given: display info about what's in the scrap (trash)
    printf "$(GetScrapInfo)"
    exit
fi