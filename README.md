# ⚠️ Disclaimer
I did this program in a couple of days and I am not that good with shell scripting, so if you find any mistake or possible improvement, *please* open an issue or pull request. If you think the ideia of sci is good but my code is irredeemable bad, feel free to copy everything you need and create your own program.

# Introduction
I tried using Zotero in the past and it was amazingly good at finding the references I needed based on their DOI or ISBN/ISSN.
The problem with it, at least for me, is that it is very bloated.
I'll never use about 90% of its features.

Ideally, I want a simple terminal program that organizes my references in a *bib* file and downloads all the articles that are available out there.
If possible, it should get the PDFs directly from the journals that publish them.
As I am in university, most of the papers are freely downloadable, given that I'm using their network or connected by a VPN.
Stuff like sci-hub or libgen should be possible to use, but only as a last resort.

Because of all that, I created these scripts to help me organize my references.
Keep in mind that it doesn't do all the fancy stuff programs like [papis](https://github.com/papis/papis) or [pubs](https://github.com/pubs/pubs/) do.

The ideia is more like creating a wrapper around [Zotero's translation server](https://github.com/zotero/translation-server), which is the stuff that actually gets information based on DOIs in the Zotero software.


# Installation
## Pre requisites
- Zotero's [translation-server](https://github.com/zotero/translation-server)
- [undetected-chromedriver](https://pypi.org/project/undetected-chromedriver)
- [bibtexparser](https://pypi.org/project/bibtexparser)
- [moreutils](https://joeyh.name/code/moreutils)

On Arch Linux (and derived distros) there are AUR packages for the translation-server ([zotero-translation-server-git](https://aur.archlinux.org/packages/zotero-translation-server-git)), bibtexparser ([python-bibtexparser](https://aur.archlinux.org/packages/python-bibtexparser)) and a pacman package for [moreutils](https://archlinux.org/packages/community/x86_64/moreutils). Undetected-chromedriver has to be installed through pip.
```sh
# Arch Linux
yay -S zotero-translation-server-git python-bibtexparser
pacman -S python-pip # if not already installed
pip install undetected-chromedriver
```
## Automatic
```sh
curl -s "https://raw.githubusercontent.com/Vinschers/sci/main/install.sh" | /bin/sh
```
## Manual
Clone the repository wherever you like and patch your zotero-translation-server-git installation with the [utilities_item.js.diff](https://github.com/Vinschers/sci/blob/main/utilities_item.js.diff) file
```sh
# Example
git clone https://github.com/Vinschers/sci
cd sci
patch -N translation-server-directory/modules/utilities/utilities_item.js utilities_item.js.diff
```
This is needed because, by default, the translation-server does not return the download url of the paper.

Then, create a symbolic link to run **sci** from some folder in your $PATH.
```sh
# Example
sudo ln -s sci-directory/sci /usr/local/bin/sci
```
## Uninstall
Once **sci** is installed, simply run `sci uninstall` to uninstall it. You have the option of deleting your bibliography directory or maintain it.

# How does it work?
Basically, a global `library.bib` file will be created in a directory specified by the user.
This file will contain ALL of your references, across every project you might have.

This global .bib file exists simply to avoid unnecessary requests to the zotero translator.
This way, if you happen to need a reference that was previously used in another project, the information will just be copied from the global bib file to the current bib file you are using.

Every time you add a reference to sci, this will append the BibLaTeX to the global bib and any local .bib in the current directory.
Also, sci will try to download the paper and, if successful, a symbolic link will be created from the global bibliography directory to your current .bib directory.
This way, every paper will have only one copy of itself across all projects.

Naturally, you may alter anything you wish in both your local and global bib file.

# Usage
The first thing you need to do is set the **ACADEMIC_DIRECTORY** environment variable.
This is used to store your global bib file as well as all the papers you download.
You could set it in your `.bashrc`, for example.
```sh
echo 'export ACADEMIC_DIRECTORY="$HOME/academic"' >> "$HOME/.bashrc"
```
Make sure to have this environment variable set.

Now, you can open a directory in which you will start a new research project.
Run the following command:
```sh
sci init
```
This will create both a `bibliography` directory and a `library.bib` file. You may change the bib file's name.
The `bibliography` directory will contain all the symbolic links available for the references present in the `library.bib` file.

Let's say you want to add [this](https://doi.org/10.1038/nphys1170) reference.
Go ahead and copy its DOI or url (https://doi.org/10.1038/nphys1170) and run
```sh
sci add "https://doi.org/10.1038/nphys1170"
```
If everything went fine, you will be able to see that the reference to this paper was added to your `library.bib` and, inside the bibliography directory, there is a directory called `article` and, inside it, the symlink to the pdf that was downloaded. If no download link is available, said article directory won't exist.

Note that the pdf name is the same as the BibLaTeX id.

If the article was, in fact, downloaded you may want to open it somehow. You can do so by running
```sh
sci open "https://doi.org/10.1038/nphys1170"
```
The default PDF viewer will be used.

You may now want to remove this reference. Simply delete it from the local bib file and run
```sh
sci update
```
This will update your symbolic links and, therefore, delete the symlink that pointed to that paper.
Keep in mind that the reference will still exist your global bib. If you wish to delete it there as well, you will have to manually delete the pdf from the `bibliography` directory.

Let's say the repository has been updated with some kind of fix or with some new feature. If you want to update it in your machine as well, run
```sh
sci update-git
```
This will simply do a git pull in the directory you installed *sci*.
