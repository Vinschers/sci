#!/bin/sh

sudo git clone https://github.com/Vinschers/sci /usr/share/sci
cd /usr/share/sci || exit 1

if ! [ -d "/usr/lib/node_modules/translation-server/modules/utilities" ]; then
    echo "Make sure you have the Zotero translation server installed. Aborting..."
    sudo rm -rf /usr/share/sci
    exit 1
fi

sudo patch -N /usr/lib/node_modules/translation-server/modules/utilities/utilities_item.js utilities_item.js.diff

sudo ln -s /usr/share/sci/sci /usr/local/bin/sci
