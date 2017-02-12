#!/bin/bash
###############################################
# Usage:
#   ./make.emacs.docset.sh
#
# e.g.
#   ./make.emacs.docset.sh
###############################################

CONTENTS_DIR=emacs.docset/Contents/
RES_DIR=${CONTENTS_DIR}/Resources/
DOC_DIR=${RES_DIR}/Documents/
HTML_FILE=emacs.html_node.tar.gz
EMACS_DOC_URL=https://www.gnu.org/software/emacs/manual/emacs.html_node.tar.gz

#
# Download Emacs manual
#
if [ ! -f "$HTML_FILE" ]; then
    echo "Download GNU Emacs manual"
    wget ${EMACS_DOC_URL} -O ${HTML_FILE}
    if [ ! $? ]; then exit 1; fi
fi

#
# Uncompress document file
#
echo "Uncompress document file"
if [ -f "$HTML_FILE" ]; then
    mkdir -p ${DOC_DIR}
    tar xf ${HTML_FILE} -C $DOC_DIR --strip-components=1
    cp icon.png icon@2x.png ${CONTENTS_DIR}/../
else
    echo ${HTML_FILE} NOT exist!
    exit 1
fi

#
# Generate Info.plist file
#
echo "Generate Info.plist file"
tee ${CONTENTS_DIR}/Info.plist >/dev/null <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>dashIndexFilePath</key>
    <string>index.html</string>
    <key>CFBundleIdentifier</key>
    <string>emacs</string>
    <key>CFBundleName</key>
    <string>GNU Emacs</string>
    <key>DocSetPlatformFamily</key>
    <string>emacs</string>
    <key>isDashDocset</key>
    <true/>
</dict>
</plist>
EOF

#
# Generate index database
#
echo "Generate index database"
python <<EOF
#!/usr/bin/env python

import os
import re
import sqlite3
from bs4 import BeautifulSoup

conn = sqlite3.connect('${RES_DIR}/docSet.dsidx')
cur = conn.cursor()

try:
    cur.execute('DROP TABLE searchIndex;')
except:
    pass

cur.execute('CREATE TABLE searchIndex(id INTEGER PRIMARY KEY, name TEXT, '
            'type TEXT, path TEXT);')
cur.execute('CREATE UNIQUE INDEX anchor ON searchIndex (name, type, path);')

docpath = '${DOC_DIR}'

######################
# Categories
######################
page = open(os.path.join(docpath, 'index.html')).read()
soup = BeautifulSoup(page, 'lxml')
cate_links = soup.find_all('table')[0].find_all('a')

for tag in cate_links:
    name = tag.text.strip()
    path = tag.attrs['href'].strip()
    cur.execute('INSERT OR IGNORE INTO searchIndex(name, type, path)'
                ' VALUES (?,?,?)', (name, 'Category', path))
    # print 'name: %s, path: %s' % (name, path)

######################
# Entries
######################
entry_links = soup.find_all('table')[1].find_all('a')

for tag in entry_links:
    name = tag.text.strip()
    path = tag.attrs['href'].strip()
    cur.execute('INSERT OR IGNORE INTO searchIndex(name, type, path)'
                ' VALUES (?,?,?)', (name, 'Entry', path))
    # print 'name: %s, path: %s' % (name, path)

######################
# Options
######################
page = open(os.path.join(docpath, 'Option-Index.html')).read()
soup = BeautifulSoup(page, 'lxml')
option_links = soup.find_all('a')

for tag in option_links:
    name = tag.text.strip()
    if re.match(r"^[+-][-a-z]", name):
       path = tag.attrs['href'].strip()
       cur.execute('INSERT OR IGNORE INTO searchIndex(name, type, path)'
                ' VALUES (?,?,?)', (name, 'Option', path))
    # print 'name: %s, path: %s' % (name, path)

######################
# Commands
######################
page = open(os.path.join(docpath, 'Command-Index.html')).read()
soup = BeautifulSoup(page, 'lxml')
command_links = soup.find_all('a')

for tag in command_links:
    name = tag.text.strip()
    if re.match(r"^[0-9a-z][-A-Za-z]+", name):
       path = tag.attrs['href'].strip()
       cur.execute('INSERT OR IGNORE INTO searchIndex(name, type, path)'
                ' VALUES (?,?,?)', (name, 'Command', path))
    # print 'name: %s, path: %s' % (name, path)

######################
# Variable
######################
page = open(os.path.join(docpath, 'Variable-Index.html')).read()
soup = BeautifulSoup(page, 'lxml')
variable_links = soup.find_all('a')

for tag in variable_links:
    name = tag.text.strip()
    if re.match(r"^[a-z]+", name):
       path = tag.attrs['href'].strip()
       cur.execute('INSERT OR IGNORE INTO searchIndex(name, type, path)'
                ' VALUES (?,?,?)', (name, 'Variable', path))
    # print 'name: %s, path: %s' % (name, path)

conn.commit()
conn.close()
EOF
