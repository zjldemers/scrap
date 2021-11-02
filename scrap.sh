#!/bin/bash
# Licensed under the terms of the GPL v3. See LICENSE.

# Broader TODO list (in no particular order):
# - Empty the entire trash bin
# - List contents of Trash/files as a tree, with options
# - Display a help menu
# - Allow for option concatenation (e.g. -r [f1] -s[f2]...)
# --- also consider something like -abc (if there's a combination that would be reasonable)
# - Handle duplicates better (search for files via .trashinfo Path data rather than their stored filenames)



### CONSTANTS
# Operations
i=0 # used to increment op codes below
cOP_SCRAP=$((i=i+1))   # scrap a file (place it in the trash with metadata)
cOP_RESTORE=$((i=i+1)) # restore a specfied file to its original location
cOP_SHRED=$((i=i+1))   # permanently and securely delete a scrapped file
cOP_META=$((i=i+1))    # view metadata associated with a given file
cOP_ERROR=$((i=i+1))   # display error messages

# Paths
cTRASHLOC="$HOME/.local/share/Trash" # overall trash location
cFILELOC="$cTRASHLOC/files/"         # location of scrapped files
cINFOLOC="$cTRASHLOC/info/"          # location of scrapped file metadata files
cINFOEXT=".trashinfo"                # file extension for metadata files

### VARIABLES
op=$cOP_SCRAP      # operation selected to perform
filename=""        # name of file to be operated on
err="scrap error:" # error message to be appended as it goes

### FUNCTIONS
function ErrMsg() {
    err+="\n  $1"
}
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
function RestoreFile() {
    origpath=$(awk -F 'Path=' '{print $2}' "$cINFOLOC$1$cINFOEXT") # Find the item's original path to restore it to
    origpath="${origpath//$'\n'}"                                  # Remove erroneous trailing newlines from previous step
    mkdir -p "${origpath%/*}/"                                     # Remake any parent directories, if needed (%/* removes the filename from the path)
    mv $cFILELOC$1 $origpath                                       # Move the file back to where it came from originally
    shred --remove=wipe "$cINFOLOC$filename$cINFOEXT"              # Remove the info file permanently
    echo $origpath                                                 # Return the restored file's new (original) path
}


### MAIN SCRIPT
if [ $# == 0 ]; then
    # no arguments given: display info about what's in the scrap (trash)
    printf "$(GetScrapInfo)"
    exit # no need to process anything further, quit the script
elif [ $# -gt 2 ]; then
    # should never have more than two arguments, based on the current design
    ErrMsg "Too many arguments"
    op=$cOP_ERROR
fi

# TODO: add more operations dependent upon arguments given
for arg in "$@"; do
    if [ $op == $cOP_ERROR ]; then
        break # ran into an error, break out of loop and report below
    fi
    case $arg in

    "-d" | "--directory") # print the path to the Trash/files location
        printf "$cFILELOC\n"
        exit # no need to process anything further, quit the script
        ;;

    "-f" | "--files") # list contents of Trash/files directory
        ls --color=auto -A $cFILELOC
        exit # no need to process anything further, quit the script
        ;;
    
    "-i" | "--info") # list contents of Trash/info directory
        ls --color=auto -A $cINFOLOC
        exit # no need to process anything further, quit the script
        ;;

    "-m" | "--meta") # view metadata associated with a given file
        op=$cOP_META
        ;;

    "-r" | "--restore") # restore a specfied file to its original location
        op=$cOP_RESTORE
        ;;
    
    "-s" | "--shred") # permanently and securely delete a scrapped file
        op=$cOP_SHRED
        ;;

    *) # argument is not a flag/option; likely a filename
        inputarg=${arg%/} # remove any '/' characters if it was a directory for metadata use
        filename="$(basename "$inputarg")"          # name of file
        relapath="$(echo ${inputarg%"$filename"})"  # relative path, if specified
        if [ "${relapath:0:1}" == "/" ]; then       # starts with a '/', assume absolute path given
            filepath=$relapath$filename             # absolute path
        else
            filepath="$PWD/$relapath$filename"      # relative path
        fi

        if [ $op == $cOP_SCRAP ]; then
            if ! [ -e $filepath ]; then
                ErrMsg "no file '$filename' exists at '$filepath'"
                op=$cOP_ERROR
            fi
        elif [[ ($op == $cOP_RESTORE) || ($op == $cOP_SHRED) || ($op == $cOP_META) ]]; then
            if ! [ -e "$cFILELOC$filename" ]; then # file name not in .../Trash/files
                ErrMsg "'$filename' does not exist in the scrap"
                op=$cOP_ERROR
            fi
            if ! [ -e "$cINFOLOC$filename$cINFOEXT" ]; then
                ErrMsg "'filename' does not have a $cINFOEXT file associated with it in the trash"
                op=$cOP_ERROR
            fi
        else
            ErrMsg "Invalid argument '$arg' for selected operation"
        fi
        ;;
    esac
done

if [[ ($# -lt 3) && (-z $filename) ]]; then # filename is an empty string
    # if we made it this far with no more than 2 arguments, we should have a valid file specified
    ErrMsg "missing file operand"
    op=$cOP_ERROR
fi
if [ $op == $cOP_ERROR ]; then
    # TODO: create help context
    printf "$err\n  Help context menu in development\n"
    exit # no need to process anything further, quit the script
fi

case $op in
    $cOP_META) # view metadata associated with a given file
        printf "$(cat "$cINFOLOC$filename$cINFOEXT")\n"
        ;;

    $cOP_RESTORE) # restore a file from the scrap to its original location
        printf "Restored $(RestoreFile "$filename")\n"
        ;;

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
    
    $cOP_SHRED) # permanently and securely delete a scrapped file
        printf "Confirm: permanently erase '$filename'?\n(THIS CANNOT BE UNDONE) (y/n) "
        read check
        while [[ ("$check" != "y") && ("$check" != "n") ]]; do
            printf "Please enter either 'y' or 'n': "
            read check
        done
        if [ "$check" == "y" ]; then # user confirmed operation
            if [ -d $cFILELOC$filename ]; then 
                # filename is actually a directory
                # shred all files in the directory first
                find "$cFILELOC$filename" -type f -exec shred -f --remove=wipe {} +
                # remove all directories (which are now empty)
                rm -r "$cFILELOC$filename" # shred does not handle directories well
            else
                # remove the specified file
                shred -f --remove=wipe "$cFILELOC$filename"
            fi
            shred --remove=wipe "$cINFOLOC$filename$cINFOEXT" # shred the metadata info file
            printf "$filename has successfully been shredded\n"
        else
            # user discontinued operation
            printf "Cancled shredding of $filename\n"
            exit # no need to process anything further, quit the script
        fi
        ;;
esac