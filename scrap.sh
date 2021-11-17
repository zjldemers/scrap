#!/bin/bash
# Licensed under the terms of the GPL v3. See LICENSE.


### CONSTANTS
# Operations
o=0 # used to increment op codes below
OP_SCRAP=$((o=o+1))   # scrap a file (place it in the trash with metadata)
OP_RESTORE=$((o=o+1)) # restore a specified file to its original location
OP_SHRED=$((o=o+1))   # permanently and securely delete a scrapped file
OP_META=$((o=o+1))    # view metadata associated with a given file
OP_TREE=$((o=o+1))    # view contents of Trash/files as a tree to specified depth
OP_EMPTY=$((o=o+1))   # permanently and securely delete all scrapped files
OP_ERROR=$((o=o+1))   # display error messages

# Paths and other constant strings
TRASH_LOC="$HOME/.local/share/Trash" # overall trash location
FILE_LOC="$TRASH_LOC/files/"         # location of scrapped files
INFO_LOC="$TRASH_LOC/info/"          # location of scrapped file metadata files
INFO_EXT=".trashinfo"                # file extension for metadata files
HELP_STR="USAGE: scrap
  or:  scrap FILE
  or:  scrap OPTION
  or:  scrap OPTION FILE
Interact with your trash bin by discarding, restoring, or shredding various
  files in such a way that a GUI-based trash manager will also be able to
  operate without any conflicts.
\nMandatory arguments to long options are mandatory for short options too.
  -d, --directory  print the directory where trash files are stored
  --empty          after confirmation, shred all scrapped files, permanently
                       and securely removing them from the system.
  -f, --files      list contents of Trash/files directory (scrapped files)
  -i, --info       list contents of Trash/info directory (metadata associated
                       with scrapped files)
  -m, --meta       view metadata associated with a given file
  -r, --restore    restore a specified file to its original location
  -s, --shred      after confirmation, shred the specified scrapped file, 
                       permanently and securely removing it from the system
  -t, --tree       view contents of Trash/files directory as a tree, add a
                       positive integer for max depth, if desired
  --help           display this help and exit
  --version        output version information and exit
\nWritten by Zachary J. L. Demers
View the source at https://github.com/zdemers/scrap.git\n"
VERSION_STR="scrap 1.0\nLicense GPLv3+: GNU GPL version 3 or later <https://gnu.org/licenses/gpl.html>
This is free software: you are free to change and redistribute it.
View the open source repository at https://github.com/zdemers/scrap
There is NO WARRANTY, to the extent permitted by law.\n
Written by Zachary J. L. Demers\n"


### VARIABLES
op=$OP_SCRAP       # operation selected to perform
filename=""        # name of file to be operated on
numopt=-1          # a number option input (e.g. tree depth)
reqfile=1          # flag stating whether or not the operation requires a file
err="scrap error:" # error message to be appended as it goes

### FUNCTIONS
function ErrMsg() {
    # Appends the given argument error message to the global error message string
    err+="\n  $1"
}
function GetScrapInfo() {
    # return information about the scrap pile such as number of files and storage used
    ret="   Items at top level in scrap:    $(ls -A "$FILE_LOC" | wc -l)\n"
    ret+="   Items including subdirectories: $(find "$FILE_LOC" -mindepth 1 | wc -l)\n"
    total="$(du -ach "$FILE_LOC" | tail -1)"
    ret+="   Total storage used:             ${total%%[[:space:]]*}B\n"
    echo "$ret"
}
function RestoreFile() {
    # $1: file name (as formatted in the Trash) to be restored
    origpath=$(awk -F 'Path=' '{print $2}' "$INFO_LOC$1$INFO_EXT") # Find the item's original path to restore it to
    origpath="${origpath//$'\n'}"                                  # Remove erroneous trailing newlines from previous step
    mkdir -p "${origpath%/*}/"                                     # Remake any parent directories, if needed (%/* removes the filename from the path)
    mv $FILE_LOC$1 $origpath                                       # Move the file back to where it came from originally
    shred --remove=wipe "$INFO_LOC$filename$INFO_EXT"              # Remove the info file permanently
    echo $origpath                                                 # Return the restored file's new (original) path
}
function FindMatchingFiles() {
    # $1: file name (as originally named, not as named after trash deconfliction)
    declare -a files=() # create an array to return
    for f in $INFO_LOC*; do
        line2="$(sed '2q;d' $f)" # line 2 of the .trashinfo file (Path=...)
        namext="$(basename $line2)" # name.extension of original file
        if [ $1 == $namext ]; then
            # found a file with the right name and extension
            files+=("$f")
        fi
    done
    echo ${files[@]} # return the list of files that matched
}

function main() {
    if [ $# == 0 ]; then
        # no arguments given: display info about what's in the scrap (trash)
        printf "$(GetScrapInfo)"
        exit # no need to process anything further, quit the script
    elif [ $# -gt 2 ]; then
        # should never have more than two arguments, based on the current design
        ErrMsg "Too many arguments"
        op=$OP_ERROR
    fi

    # Parse through input arguments
    for arg in "$@"; do
        if [ $op == $OP_ERROR ]; then
            break # ran into an error, break out of loop and report below
        fi
        case $arg in

        "-d" | "--directory") # print the path to the Trash/files location
            printf "$FILE_LOC\n"
            exit # no need to process anything further, quit the script
            ;;
        
        "--empty") # permanently and securely delete all scrapped files
            op=$OP_EMPTY
            reqfile=0
            ;;

        "-f" | "--files") # list contents of Trash/files directory
            ls --color=auto -A $FILE_LOC
            exit # no need to process anything further, quit the script
            ;;
        
        "--help") # display the help menu and quit
            printf "$HELP_STR"
            exit
            ;;

        "-i" | "--info") # list contents of Trash/info directory
            ls --color=auto -A $INFO_LOC
            exit # no need to process anything further, quit the script
            ;;

        "-m" | "--meta") # view metadata associated with a given file
            op=$OP_META
            ;;

        "-r" | "--restore") # restore a specified file to its original location
            op=$OP_RESTORE
            ;;
        
        "-s" | "--shred") # permanently and securely delete a scrapped file
            op=$OP_SHRED
            ;;
        
        "-t" | "--tree") # view contents of Trash/files as a tree to specified depth
            op=$OP_TREE
            reqfile=0
            ;;
        
        "--version") # output version information and exit
            printf "$VERSION_STR"
            exit
            ;;

        *) # argument is not a flag/option; likely a filename
            if [ $op == $OP_TREE ]; then
                # $arg should be an integer > 0
                if ! command -v "tree" &> /dev/null; then
                    # tree command is not installed/available
                    ErrMsg "This operation requires 'tree' to be installed"
                    op=$OP_ERROR
                elif [[ (-z "${arg//[0-9]}") && (-n "$arg") && ($arg -gt 0) ]]; then
                    # arg is a valid integer > 0
                    numopt=$arg # set the number option input for when operation is performed below
                else
                    # bad argument input
                    ErrMsg "invalid argument '$arg': -t/--tree requires an integer greater than 0"
                    op=$OP_ERROR
                fi
            else
                # $arg should be a file or directory name
                inputarg=${arg%/} # remove any '/' characters if it was a directory for metadata use
                filename="$(basename "$inputarg")"          # name of file

                if [ $op == $OP_SCRAP ]; then
                    relapath="$(echo ${inputarg%"$filename"})"  # relative path, if specified
                    filepath="$PWD/$relapath$filename"          # assume relative path / define filepath
                    if [ "${relapath:0:1}" == "/" ]; then       # starts with a '/', assume absolute path given
                        filepath=$relapath$filename             # absolute path
                    fi
                    if ! [ -e $filepath ]; then # filepath doesn't point to an existing file/directory
                        ErrMsg "no file '$filename' exists at '$filepath'"
                        op=$OP_ERROR
                    fi
                elif [[ ($op == $OP_RESTORE) || ($op == $OP_SHRED) || ($op == $OP_META) ]]; then
                    # Find all scrapped files that match the given file name and let the user choose which to operate on
                    declare -A arr
                    count=0
                    for f in $INFO_LOC*; do
                        # search all files in Trash/info/*
                        scrapfile="$(basename $f .trashinfo)" # name of file in the scrap (deconfliction considered)
                        line2="$(sed '2q;d' $f)" # line 2 of the .trashinfo file (Path=...)
                        line3="$(sed '3q;d' $f)" # line 3 of the .trashinfo file (DeletionDate=...)
                        namext="$(basename $line2)" # name.extension of original file
                        if [ $filename == $namext ]; then # found a file with the right name and extension
                            arr[$count,0]=$line2     # [0]="Path=..."
                            arr[$count,1]=$line3     # [1]="DeletionDate="
                            arr[$count,2]=$scrapfile # [2]="name.deconfliction#.ext"
                            count=$((count+1)) # increment the counter
                        fi
                    done

                    # Check how many files matched the given filename
                    if [ $count == 0 ]; then
                        ErrMsg "'$filename' does not exist in the scrap"
                        op=$OP_ERROR
                    elif [ $count -gt 1 ]; then
                        printf "Multiple files in the trash match that name\n"
                        for (( i=0; i<$count; i++ )); do
                            printf "$i:\t${arr[$i,0]}\n\t${arr[$i,1]}\n"
                        done
                        if ! [ $op == $OP_META ]; then # not just searching for metadata
                            printf "Select which file you would like to operate on: "
                            read check
                            while [[ ($check -lt 0) || ($check -ge $count) ]]; do
                                printf "Please enter a selection between 0 and $((count-1)): "
                                read check
                            done
                            filename=${arr[$check,2]} # deconflictable name as stored in trash
                        else
                            # was only searching for metadata, already listed at this point
                            exit
                        fi
                    else
                        # Only one file with that name
                        filename=$scrapfile # only one scrapfile was found, so use it to find it in the scrap
                    fi
                else
                    ErrMsg "invalid argument '$arg' for selected operation"
                fi # end if[scrap], elif[restore,shred,meta]
            fi # end if[tree], else
            ;;
        esac
    done

    if [[ ($reqfile == 1) && ($# -lt 3) && (-z $filename) ]]; then 
        # filename is an empty string but the operation requires a file
        ErrMsg "missing file operand"
        op=$OP_ERROR
    fi
    if [ $op == $OP_ERROR ]; then
        # Report errors, recommend help menu, and quit
        ErrMsg "  Try 'scrap --help' for more information"
        printf "$err\n"
        exit # no need to process anything further, quit the script
    fi

    case $op in
        $OP_EMPTY) # permanently and securely delete all scrapped files
            if [[ "$(ls -A $FILE_LOC)" || "$(ls -A $INFO_LOC)" ]]; then
                # either Trash/files OR Trash/info contains files that could be erased
                printf "Confirm: permanently erase all contents in trash?\n(THIS CANNOT BE UNDONE) (y/n) "
                read check
                while [[ ("$check" != "y") && ("$check" != "n") ]]; do
                    printf "Please enter either 'y' or 'n': "
                    read check
                done
                if [ "$check" == "y" ]; then # user confirmed operation
                    printf "Shredding all trash files...\n"
                    # shred all files in the files directory and its sub-directories
                    find "$FILE_LOC" -type f -exec shred -f --remove=wipe {} +
                    # delete all directories inside of the trash folder (all are empty now)
                    find "$FILE_LOC" -mindepth 1 -delete
                    # delete all metadata files
                    printf "Shredding all trash metadata...\n"
                    find "$INFO_LOC" -type f -exec shred -f --remove=wipe {} +
                    printf "Shredding complete\n"
                else
                    printf "Canceled empty operation\n"
                fi
            else
                # Trash is already empty
                printf "Trash is already empty\n"
            fi
            ;;

        $OP_META) # view metadata associated with a given file
            printf "$(cat "$INFO_LOC$filename$INFO_EXT")\n"
            ;;

        $OP_RESTORE) # restore a file from the scrap to its original location
            printf "Restored $(RestoreFile "$filename")\n"
            ;;

        $OP_SCRAP) # scrap a file, placing it in the trash along with relevant metadata
            # To follow standards, this performs somewhat of a messy process to deconflict files with the same
            #    name that have been added to the Trash
            infofile="$INFO_LOC$filename$INFO_EXT" # file to store metadata in
            num=1 # file number for duplicates
            namext="$(basename $filename)" # name and extension (but no path)
            name=${namext%%.*} # get the filename without an extension (if there is one)
            ext="" # default to no extension until found
            if [ -z $name ]; then # if name is empy (occurs for files likek ".abc")
                name=$namext # reset the name
            elif [[ "$namext" == *"."* ]]; then # there is an extension, so set that appropriately
                ext=".${namext#*.}" # handles multi-extension files such as "*.tar.xz"
            fi
            while [[ -f $infofile ]]; do 
                # file already exists, increment num and append it to the file name to try that
                ((num=num+1)) # starts with 2, following standards (e.g. a.b, a.2.b, a.3.b, ...)
                infofile="$INFO_LOC$name.$num$ext$INFO_EXT"
            done

            trashname="$name" # name to place in Trash/files (with deconfliction)
            if [ $num -gt 1 ]; then # a file number was needed to avoid overwriting
                trashname+=".$num"  # add that number to the name for deconfliction
            fi
            trashname+=$ext # add extension ($ext is an empty string if there is no extension)
            printf "[Trash Info]\nPath=$filepath\nDeletionDate=$(date '+%Y-%m-%dT%H:%M:%S')\n" > $infofile # Write the metadata file
            mv $filepath $FILE_LOC$trashname # move the file to be scrapped into the trash
            printf "Successfully scrapped the file $filename\n" # report results to the user, using original filename
            ;;
        
        $OP_SHRED) # permanently and securely delete a scrapped file
            printf "Confirm: permanently erase '$filename'?\n(THIS CANNOT BE UNDONE) (y/n) "
            read check
            while [[ ("$check" != "y") && ("$check" != "n") ]]; do
                printf "Please enter either 'y' or 'n': "
                read check
            done
            if [ "$check" == "y" ]; then # user confirmed operation
                if [ -d $FILE_LOC$filename ]; then 
                    # filename is actually a directory
                    # shred all files in the directory first
                    find "$FILE_LOC$filename" -type f -exec shred -f --remove=wipe {} +
                    # remove all directories (which are now empty)
                    rm -r "$FILE_LOC$filename" # shred does not handle directories well
                else
                    # remove the specified file
                    shred -f --remove=wipe "$FILE_LOC$filename"
                fi
                shred --remove=wipe "$INFO_LOC$filename$INFO_EXT" # shred the metadata info file
                printf "$filename has successfully been shredded\n"
            else
                # user discontinued operation
                printf "Cancled shredding of $filename\n"
            fi
            ;;

        $OP_TREE) # view contents of Trash/files as a tree to specified depth
            if [ $numopt -gt 0 ]; then
                tree $FILE_LOC -L $numopt
            else
                tree $FILE_LOC
            fi
            ;;
    esac
}

main "$@"