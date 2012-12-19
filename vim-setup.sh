#!/bin/bash
#
# vim-setup.sh - install and setup vim
# author: hejiannn <hejia3n@gmail.com>
#
# plugins installed: nerdtree, tagbar, matchit, python-mode, jedi-vim
#
# key maps:
# F2 : NERDTreeToggle
# F8 : TagbarToggle
#

# GetOSVersion
# Determine OS Vendor, Release and Update
# Tested with RedHat, CentOS, Fedora, Mint, Ubuntu, Debian, OS/X
# Returns results in global variables:
# os_VENDOR - vendor name
# os_RELEASE - release
# os_UPDATE - update
# os_PACKAGE - package type
# os_CODENAME - vendor's codename for release
GetOSVersion() {
    # Figure out which vendor we are
    if [[ -n "`which sw_vers 2>/dev/null`" ]]; then
        # OS/X
        os_VENDOR=`sw_vers -productName`
        os_RELEASE=`sw_vers -productVersion`
        os_UPDATE=${os_RELEASE##*.}
        os_RELEASE=${os_RELEASE%.*}
        os_PACKAGE=""
        if [[ "$os_RELEASE" =~ "10.7" ]]; then
            os_CODENAME="lion"
        elif [[ "$os_RELEASE" =~ "10.6" ]]; then
            os_CODENAME="snow leopard"
        elif [[ "$os_RELEASE" =~ "10.5" ]]; then
            os_CODENAME="leopard"
        elif [[ "$os_RELEASE" =~ "10.4" ]]; then
            os_CODENAME="tiger"
        elif [[ "$os_RELEASE" =~ "10.3" ]]; then
            os_CODENAME="panther"
        else
            os_CODENAME=""
        fi
    elif [[ -x $(which lsb_release 2>/dev/null) ]]; then
        os_VENDOR=$(lsb_release -i -s)
        os_RELEASE=$(lsb_release -r -s)
        os_UPDATE=""
        if [[ "Debian,Ubuntu" =~ $os_VENDOR ]]; then
            os_PACKAGE="deb"
        elif [[ "SUSE LINUX" =~ $os_VENDOR ]]; then
            lsb_release -d -s | grep -q openSUSE
            if [[ $? -eq 0 ]]; then
                os_VENDOR="openSUSE"
            fi
            os_PACKAGE="rpm"
        else
            os_PACKAGE="rpm"
        fi
        os_CODENAME=$(lsb_release -c -s)
    elif [[ -r /etc/redhat-release ]]; then
        # Red Hat Enterprise Linux Server release 5.5 (Tikanga)
        # CentOS release 5.5 (Final)
        # CentOS Linux release 6.0 (Final)
        # Fedora release 16 (Verne)
        os_CODENAME=""
        for r in "Red Hat" CentOS Fedora; do
            os_VENDOR=$r
            if [[ -n "`grep \"$r\" /etc/redhat-release`" ]]; then
                ver=`sed -e 's/^.* \(.*\) (\(.*\)).*$/\1\|\2/' /etc/redhat-release`
                os_CODENAME=${ver#*|}
                os_RELEASE=${ver%|*}
                os_UPDATE=${os_RELEASE##*.}
                os_RELEASE=${os_RELEASE%.*}
                break
            fi
            os_VENDOR=""
        done
        os_PACKAGE="rpm"
    elif [[ -r /etc/SuSE-release ]]; then
        for r in openSUSE "SUSE Linux"; do
            if [[ "$r" = "SUSE Linux" ]]; then
                os_VENDOR="SUSE LINUX"
            else
                os_VENDOR=$r
            fi

            if [[ -n "`grep \"$r\" /etc/SuSE-release`" ]]; then
                os_CODENAME=`grep "CODENAME = " /etc/SuSE-release | sed 's:.* = ::g'`
                os_RELEASE=`grep "VERSION = " /etc/SuSE-release | sed 's:.* = ::g'`
                os_UPDATE=`grep "PATCHLEVEL = " /etc/SuSE-release | sed 's:.* = ::g'`
                break
            fi
            os_VENDOR=""
        done
        os_PACKAGE="rpm"
    fi
    export os_VENDOR os_RELEASE os_UPDATE os_PACKAGE os_CODENAME
}

GetOSVersion
echo "vim setup for $os_VENDOR $os_RELEASE $os_UPDATE $os_CODENAME"

# Save trace setting
XTRACE=$(set +o | grep xtrace)
set +o xtrace

# Install vim
if [[ "$os_VENDOR" =~ (CentOS) ]]; then
  sudo yum -y install vim ctags
elif [[ "$os_VENDOR" =~ (Fedora) ]]; then
  sudo yum -y install vim
elif [[ "$os_VENDOR" =~ (LinuxMint) ]]; then
  sudo apt-get -y install vim exuberant-ctags
elif [[ "$os_VENDOR" =~ (Debian) ]]; then
  sudo apt-get -y install vim exuberant-ctags
fi

# Create ~/.vim directory
if [ ! -d ~/.vim ]; then
  mkdir ~/.vim
fi

# Install nerdtree plugin
if [[ "$os_VENDOR" =~ (Fedora) ]]; then
  sudo yum -y install vim-nerdtree
else
  if [ ! -f ~/.vim/plugin/NERD_tree.vim ]; then
    wget https://github.com/scrooloose/nerdtree/archive/master.zip -O master.zip
    unzip master.zip
    cp nerdtree-master/* ~/.vim/ -r
    rm nerdtree-master -rf
    rm master.zip
  fi
fi

# Install tagbar plugin
if [ ! -f ~/.vim/plugin/tagbar.vim ]; then
  wget https://github.com/majutsushi/tagbar/archive/master.zip -O master.zip
  unzip master.zip
  cp tagbar-master/* ~/.vim/ -r
  rm tagbar-master -rf
  rm master.zip
fi

# Install matchit plugin
if [ ! -f ~/.vim/plugin/matchit.vim ]; then
  if [ -d /usr/share/vim/vim73 ]; then
    cp /usr/share/vim/vim73/macros/matchit.vim ~/.vim/plugin/
    cp /usr/share/vim/vim73/macros/matchit.txt ~/.vim/doc/
  elif [ -d /usr/share/vim/vim72 ]; then
    cp /usr/share/vim/vim72/macros/matchit.vim ~/.vim/plugin/
    cp /usr/share/vim/vim72/macros/matchit.txt ~/.vim/doc/
  else
    echo "ERROR: Could not find the vim directory !!!"
  fi
fi

# Install python-mode plugin
if [ ! -f ~/.vim/plugin/pymode.vim ]; then
  wget https://github.com/klen/python-mode/archive/master.zip -O master.zip
  unzip master.zip
  cp python-mode-master/* ~/.vim/ -r
  rm python-mode-master -rf
  rm master.zip
fi

# Install jedi-vim plugin
if [ ! -f ~/.vim/plugin/jedi.vim ]; then
  wget https://github.com/davidhalter/jedi-vim/archive/master.zip -O master.zip
  unzip master.zip
  cp jedi-vim-master/* ~/.vim/ -r
  rm jedi-vim-master -rf
  rm master.zip
fi

# Customize ~/.vimrc
cat > ~/.vimrc <<EOF
set fileencodings=ucs-bom,utf-8,gbk,default,latin1

set expandtab
set tabstop=2
set shiftwidth=2
set autoindent
set smartindent

if has("autocmd")
  " Drupal *.module and *.install files.
  augroup module
    autocmd BufRead,BufNewFile *.module set filetype=php
    autocmd BufRead,BufNewFile *.install set filetype=php
    autocmd BufRead,BufNewFile *.test set filetype=php
    autocmd BufRead,BufNewFile *.inc set filetype=php
    autocmd BufRead,BufNewFile *.profile set filetype=php
    autocmd BufRead,BufNewFile *.view set filetype=php
  augroup END
endif
syntax on

map <F2> :NERDTreeToggle<CR>
nnoremap <silent> <F8> :TagbarToggle<CR>

" Turn on Line numbers
set number

let php_parent_error_close = 1
let php_parent_error_open = 1
let php_folding = 1

" highlight all its matches
set hlsearch
EOF

# Restore xtrace
$XTRACE

echo "vim-setup.sh completed in $SECONDS seconds."
