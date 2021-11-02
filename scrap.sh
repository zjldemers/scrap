#!/bin/bash


# Starting with just placing an item in the trash with appropriate metadata
# Will want more operations later though, thus the op variable usage

### CONSTANTS
# Operations
cOP_SCRAP=0     # scrap a file (place it in the trash with metadata)
cOP_ERROR=99    # display error messages

# Paths
cTRASHLOC="$HOME/.local/share/Trash" # overall trash location
cFILELOC="$cTRASHLOC/files/"         # location of scrapped files
cINFOLOC="$cTRASHLOC/info/"          # location of scrapped file metadata files
cINFOEXT=".trashinfo"                # file extension for metadata files

### VARIABLES
op=$cOP_SCRAP   # operation selected to perform
filename=""     # name of file to be operated on
err="scrap:"    # error message to be appended as it goes

### FUNCTIONS
function GetDate() {
    # return the current date/time in the appropriate format for the .trashinfo file
    echo "$(date '+%Y-%m-%dT%H:%M:%S')"
}
function GetScrapInfo() {
    # return information about the scrap pile such as number of files and storage used
    ret="   Items at top level in scrap:    $(ls -A $cFILELOC | wc -l)\n"
    ret+="   Items including subdirectories: $(find $cFILELOC -mindepth 1 | wc -l)\n"
    total="$(du -ach $cFILELOC | tail -1)"
    ret+="   Total storage used:             ${total%%[[:space:]]*}B\n"
    echo "$ret"
}


### MAIN SCRIPT
if [ $# == 0 ]; then
    # no arguments given: display info about what's in the scrap (trash)
    printf "$(GetScrapInfo)"
    exit # no need to process anything further, quit the script
fi

# TODO: add more operations dependent upon arguments given
for arg in "$@"; do
    case arg in

    # TODO: add more cases for other input args

    *) # argument is not a flag/option; likely a filename
        inputarg=${arg%/} # remove any '/' characters if it was a directory for metadata use
        filename="$(basename "$inputarg")"          # name of file
        relapath="$(echo ${inputarg%"$filename"})"  # relative path, if specified
        if [ "${relapath:0:1}" == "/" ]; then       # starts with a '/', assume absolute path given
            filepath=$relapath$filename             # absolute path
        else
            filepath="$PWD/$relapath$filename"      # relative path
        fi

        if ! [ -e $filepath ]; then
            err+="\n  no file '$filename' exists at '$filepath'"
            op=$cOP_ERROR
        fi

    esac
done

if [ -z $filename ]; then # filename is an empty string
    # if we made it this far, we should have a file specified
    err+="\n  missing file operand"
    op=$cOP_ERROR
fi
if [ $op == $cOP_ERROR ]; then
    # TODO: create help context
    printf "$err\n  Help context menu in development\n"
    exit # no need to process anything further, quit the script
fi

case $op in
    $cOP_SCRAP) # scrap a file, placing it in the trash along with relevant metadata
        infofile="$cINFOLOC$filename$cINFOEXT" # file to store metadata in
        filenum=0                              # helps with duplicate names in trash directory
        while [[ -f $infofile ]]; do 
            # file already exists, increment filenum and append it to the file name to try that
            ((filenum=filenum+1))
            infofile=$cINFOLOC$filename$filenum$cINFOEXT
        done
        if [ $filenum -gt 0 ]; then # a file number was needed to avoid overwriting
            filename+=$filenum
        fi

        # Write the necessary metadata into the new file
        printf "[Trash Info]\nPath=$filepath\nDeletionDate=$(GetDate)\n" > $infofile
        mv $filepath $cFILELOC$filename # move the file to be scrapped into the trash
        printf "Successfully scrapped the file $filename\n" # report results to the user
        ;;
esac