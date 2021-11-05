# scrap: A(nother) Linux Trash CLI
This small repository supplies a simple, intuitive (I hope) command line interface (CLI) to a user's Trash bin, based off of the [FreeDesktop.org Trash Specification](https://specifications.freedesktop.org/trash-spec/trashspec-latest.html).  With that in mind, this is intended for use on Linux machines only, at least for now.

At the moment, it is entirely comprised of a single, fairly long, bash shell script.  I realize that this is not considered best practice (see [Google's Shell Guidelines](https://google.github.io/styleguide/shellguide.html#s1.2-when-to-use-shell)), but I chose to go down this route anyway, for two reasons.  (1) I wanted to practice writing bash scripts, and (2) I did not originally set out to make it as robust as it turned out to be (that is, I figured it would be less than 100 lines, not 350ish).  Future versions may entail real code developed to perform the same task, but this placeholder will do for now.

## History
I - along with many others, I'm sure - made the mistake of using "rm" in the Linux terminal a litle too quickly, soon after regretting the action.  This led to a brief search to find a better means of tossing files in such a way that I could recover them if needed, while also being able to erase them forever if desired.  Something like the standard trash GUI that comes on most operating systems, but handled through the terminal since I frequently work from there.

I quickly came across several options such as [@andreafrancia's trash-cli](https://github.com/andreafrancia/trash-cli/), or [@atharvakadam's Trash-Suite](https://github.com/atharvakadam/Trash-Suite-Linux), or [@nivekuil's rip](https://github.com/nivekuil/rip).  However, they all had shortcomings for what I was going for.  Many of these were more complex than what I desired, and some were not very intuitive to me, for example.  Plus, I saw it as a good opportunity to practice some skills of my own, so here I am.

## What is the Trash?
While that may seem like a silly question, I think it is worth the few extra words to cover this.  In the [FreeDesktop.org Trash Specification](https://specifications.freedesktop.org/trash-spec/trashspec-latest.html), all files that have been deleted via a valid trash functionality will be placed in a particular location on the disk.  In parallel, another file is created and placed in a neighboring directory that contains metadata to include the original path where it was deleted from and the timestamp of deletion.  Care has to be made to avoid confliction of file names (that is, if I delete a file name `a.b` and then delete another file named `a.b` also, they cannot overwrite each other in the trash bin).  This is generally handled through the `.trashinfo` metadata files.  The locations of these directories are as follows.
```
$HOME/.local/share/Trash/files     # for the original files
$HOME/.local/share/Trash/info      # for the corresponding metadata info files
```
With that in mind, `scrap` follows those same standards to avoid any complications between a CLI or GUI trash operation.  That is, users can select a file and delete it via the mouse or keyboard shortcut (e.g. `Delete` key), open a file browser to the Trash location and see it there.  They can then restore that same file using this script as described below, without having to think twice.  The same goes the other way: anything "scrapped" via this script can easily be viewed or restored in a typical trash GUI.




# Installation
Truly, the term "installation" seems a little out of place here, but nonetheless it gets the point across.  The recommended means of placing this on your system is to clone this repository and place it in a folder under the following directory.

```
/usr/share/scrap
```

Once there, any user on the system can edit their `.bashrc` file to include the following line.

```
alias scrap="/usr/share/scrap/scrap.sh"
```

With that in place, the user can then simply follow the usage guide below.




# Usage
This section will step through each of the available options that `scrap` comes with out of the box.  Before getting to the individual options, however, I would like to specify a few notes.

1. The usage below *assumes* that the user's `.bashrc` file is set such that `scrap` calls on this script (see Installation section above).  If that is not the case, the user will need to call it by other typical means, such as navigating to the directory and calling `./scrap.sh` or whatever they may prefer.
1. Whenever the term "file" is mentioned within this Usage section, it can be interchanged freely with the term "directory" as the operations are identical from the user's point of view.  It also handles both absolute and relative paths in place of the file operand.
1. If a file is scrapped with a name that already exists in the trash, it will automatically rename the file according to the standards mentioned above, while maintaining the original name in the info file, as it should.  Therefore, if you view the trash contents via the terminal (as described below), you may be surprised to see that the name has a number appended to it.  If you view it through a GUI, however, the name will seem untouched.  This is by design, following the standards.
1. If a user attempts to operate on a file in the trash from this script while more than one file contains that name (original name, not trash name), the script will respond with the list of files matching the name along with their original path and deletion date to assist in selecting the correct file.
1. In the syntax listed below, when an option is enclosed by <>'s (e.g. \<file>), that is a ***required*** input for that command.  However, when enclosed by []'s (e.g. \[input\]), it is an *optional* input.
1. This script does not handle multiple operations simultaneously.  That is, for example, you cannot scrap one file while restoring another in the same command, but instead you must separate it into two commands.  Therefore, all of the options below show every use-case.  No combinations are currently allowed.

With all of this in mind, consider the following capabilities that `scrap` has to offer.


```
scrap --help
```
Being a CLI, scrap comes with a few stereotypical command options, not least of which is the `--help` flag.  The output of this command to the terminal should hopefully suffice in explaining the usage and capabilities of the script, but the following sections will describe them in more depth.

```
scrap
```
Without any input arguments, the base script function returns information regarding the contents of the trash.  Specifically, it lists the number of items in the top level, the total number of items (including all subdirectories), and the total storage being used.


```
scrap <file>
```
The file specified will be "scrapped", or placed into the trash bin.  This generates an appropriate `.trashinfo` metadata file, and places both in their appropriate locations on the disk.


```
scrap -d
scrap --directory
```
This option echos to the terminal exactly where the trash files (not their metadata counterparts) are stored in case the user forgets, or in case they would like to use it as an input to another command.


```
scrap -f
scrap --files
```
All files listed (included hidden ones) under `Trash/files` will be listed out on the terminal.  This is essentially calling `ls $(scrap -d) -A` with colors set to auto.


```
scrap -i
scrap --info
```
All metadata info files under `Trash/info` will be listed out on the terminal in a similar manner as mentioned above with `scrap -f`.


```
scrap -t [positive integer]
scrap --tree [positve integer]
```
If the [tree](https://linux.die.net/man/1/tree) package is *not* installed, this will exit the script cleanly with a simple error stating that the package must be installed.  This is an unnecessary, but helpful, feature of the script, so if for some reason the user does not desire to install the commonly used package, they will only lack this one command.

However, if the package is installed, this will display a color-coded directory tree of all the contents (including subdirectories) of the `Trash/files` directory.  Providing an optional positive integer along with the flag will generate a tree going only that many levels deep, using `tree`'s `-L` option under the hood. That is, `scrap -t 2` will show the top-level trash contents along with the first-level contents of any folders contained within it.  Providing the number 0, any negative value, or some other string will result in the script exiting with an error message.

```
scrap -m <file>
scrap --meta <file>
```
Given a file name, `scrap` will find all files in the trash that match the name and print their relevant metadata contents (as found in the corresponding `.trashinfo` file) to the terminal.

```
scrap -r <file>
scrap --restore <file>
```
Given a file name, `scrap` will find all files in the trash that match the name and either (1) have the user select the one from the list, or (2) operate on the file if there is only one.  Once the final, individual file is selected, it will be restored to its original location while the corresponding `.trashinfo` file will be securely shredded.

``` 
scrap -s <file>
scrap --shred <file>
```
Given a file name, `scrap` will find all files in the trash that match the name and either (1) have the user select the one from the list, or (2) operate on the file if there is only one.  Once the final, individual file is selected, the user will be prompted to confirm the shred operation.  If confirmed, the file (and its corresponding `.trashinfo` file) will be securely erased from the system using the `shred` command.

*Note: Future iterations of this script may include the option for a "fast" deletion that simply uses `rm` instead, since `shred` can take notably longer.*

```
scrap --empty
```
The user is prompted to ensure that they mean to empty the entire trash bin, and then - upon confirmation - all contents within the trash (both under `Trash/files` and `Trash/info`) are securely erased using the `shred` command.

*Note: Future iterations of this script may include the option for a "fast" deletion that simply uses `rm` instead, since `shred` can take notably longer.*

```
scrap --version
```
This will output the current version information along with a brief license description regarding the script, following very closely to the format seen in common commands such as `cp`, `mv`, `rm`, etc.



# Bugs and Feedback
If you find bugs or have ideas on how to improve this simple CLI, please feel free to submit an issue to the [GitHub repo's issue page](https://github.com/zdemers/scrap/issues).