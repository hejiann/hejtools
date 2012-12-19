#!/bin/bash

if [ ! -d ~/.vim ]; then
  mkdir ~/.vim
fi

# nerdtree
sudo yum -y install vim-nerdtree

# tagbar
wget https://github.com/majutsushi/tagbar/archive/master.zip
unzip master.zip
mv tagbar-master/* ~/.vim/
rm tagbar-master -rf
rm master.zip

# matchit
cp /usr/share/vim/vim73/macros/matchit.vim ~/.vim/plugin/
cp /usr/share/vim/vim73/macros/matchit.txt ~/.vim/doc/

