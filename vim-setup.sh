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
        if [[ "Debian,Ubuntu,LinuxMint" =~ $os_VENDOR ]]; then
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
    elif [[ -r /etc/issue ]]; then
      if grep -q "Debian" /etc/issue; then
        os_VENDOR="Debian"
        os_PACKAGE="deb"
      elif grep -q "Arch" /etc/issue; then
        os_VENDOR="Arch"
        os_PACKAGE="pacman"
      fi
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

# Distro-agnostic function to tell if a package is installed
# is_package_installed package [package ...]
function is_package_installed() {
    if [[ -z "$@" ]]; then
        return 1
    fi

    if [[ -z "$os_PACKAGE" ]]; then
        GetOSVersion
    fi

    if [[ "$os_PACKAGE" = "deb" ]]; then
        dpkg -l "$@" > /dev/null
        return $?
    elif [[ "$os_PACKAGE" = "rpm" ]]; then
        rpm --quiet -q "$@"
        return $?
    elif [[ "$os_PACKAGE" = "pacman" ]]; then
        pacman -Q "$@" > /dev/null
        return $?
    else
        echo "Support for $os_VENDOR $os_RELEASE $os_UPDATE $os_PACKAGE $os_CODENAME is incomplete."
        exit 1
    fi
}

# Distro-agnostic package installer
# install_package package [package ...]
function install_package() {
    if is_fedora; then
        yum_install "$@"
    elif is_debian; then
        [[ "$NO_UPDATE_REPOS" = "True" ]] || apt_get update
        NO_UPDATE_REPOS=True

        apt_get install "$@"
    elif is_arch; then
        pacman_install "$@"
    elif is_suse; then
        zypper_install "$@"
    else
        echo "Support for $os_VENDOR $os_RELEASE $os_UPDATE $os_PACKAGE $os_CODENAME is incomplete."
        exit 1
    fi
}

# Determine if current distribution is a Fedora-based distribution
# (Fedora, RHEL, CentOS).
# is_fedora
function is_fedora {
    if [[ -z "$os_VENDOR" ]]; then
        GetOSVersion
    fi

    [ "$os_VENDOR" = "Fedora" ] || [ "$os_VENDOR" = "Red Hat" ] || [ "$os_VENDOR" = "CentOS" ]
}

# Determine if current distribution is an Ubuntu-based distribution.
# It will also detect non-Ubuntu but Debian-based distros; this is not an issue
# since Debian and Ubuntu should be compatible.
# is_debian
function is_debian {
    if [[ -z "$os_PACKAGE" ]]; then
        GetOSVersion
    fi

    [ "$os_PACKAGE" = "deb" ]
}

# Determine if current distribution is a Arch distribution.
# is_arch
function is_arch {
    if [[ -z "$os_VENDOR" ]]; then
        GetOSVersion
    fi

    [ "$os_PACKAGE" = "pacman" ]
}

# Determine if current distribution is a SUSE-based distribution
# (openSUSE, SLE).
# is_suse
function is_suse {
    if [[ -z "$os_VENDOR" ]]; then
        GetOSVersion
    fi

    [ "$os_VENDOR" = "openSUSE" ] || [ "$os_VENDOR" = "SUSE LINUX" ]
}

# Wrapper for ``yum`` to set proxy environment variables
# Uses globals ``OFFLINE``, ``*_proxy`
# yum_install package [package ...]
function yum_install() {
    [[ "$OFFLINE" = "True" ]] && return
    local sudo="sudo"
    [[ "$(id -u)" = "0" ]] && sudo="env"
    $sudo http_proxy=$http_proxy https_proxy=$https_proxy \
        no_proxy=$no_proxy \
        yum install -y "$@"
}

# Wrapper for ``apt-get`` to set cache and proxy environment variables
# Uses globals ``OFFLINE``, ``*_proxy`
# apt_get operation package [package ...]
function apt_get() {
    [[ "$OFFLINE" = "True" || -z "$@" ]] && return
    local sudo="sudo"
    [[ "$(id -u)" = "0" ]] && sudo="env"
    $sudo DEBIAN_FRONTEND=noninteractive \
        http_proxy=$http_proxy https_proxy=$https_proxy \
        no_proxy=$no_proxy \
        apt-get --option "Dpkg::Options::=--force-confold" --assume-yes "$@"
}
# Wrapper for ``pacman``
# yaourt -S package [package ...]
function pacman_install() {
    [[ "$OFFLINE" = "True" || -z "$@" ]] && return
    local sudo="sudo"
    [[ "$(id -u)" = "0" ]] && sudo="env"
    $sudo http_proxy=$http_proxy https_proxy=$https_proxy \
        no_proxy=$no_proxy \
        yaourt -Sy "$@"
}

# zypper wrapper to set arguments correctly
# zypper_install package [package ...]
function zypper_install() {
    [[ "$OFFLINE" = "True" ]] && return
    local sudo="sudo"
    [[ "$(id -u)" = "0" ]] && sudo="env"
    $sudo http_proxy=$http_proxy https_proxy=$https_proxy \
        zypper --non-interactive install --auto-agree-with-licenses "$@"
}

GetOSVersion
echo "vim setup for $os_VENDOR $os_RELEASE $os_UPDATE $os_PACKAGE $os_CODENAME $DISTRO"

# root access
# vim-setup.sh is designed to be run as a non-root user but need sudo priviledge to install packages.
if [[ $EUID -eq 0 ]]; then
    echo "You are running this script as root."
    is_package_installed sudo || install_package sudo
    USER=$(who am i | awk '{ print $1 }')
    if ! grep -q "$USER ALL=(ALL:ALL) ALL" /etc/sudoers; then
        echo "Give $USER sudo priviledge."
        echo "$USER ALL=(ALL:ALL) ALL" >> /etc/sudoers
    fi
    echo "Please re-run desktop-setup.sh as normal user."
    exit 1
else
    if ! is_package_installed sudo; then
        echo "Sudo is required. Re-run vim-setup.sh as su to setup sudo."
        exit 1
    fi
fi

# Save trace setting
XTRACE=$(set +o | grep xtrace)
set +o xtrace

echo "Check and install vim & ctagas"
is_package_installed vim || install_package vim
if [[ "$os_VENDOR" =~ (CentOS) ]]; then
  is_package_installed ctags || install_package ctags
elif [[ "$os_VENDOR" =~ (Fedora) ]]; then
  is_package_installed ctags || install_package ctags
elif [[ "$os_VENDOR" =~ (LinuxMint) ]]; then
  is_package_installed exuberant-ctags || install_package exuberant-ctags
elif [[ "$os_VENDOR" =~ (Ubuntu) ]]; then
  is_package_installed exuberant-ctags || install_package exuberant-ctags
elif [[ "$os_VENDOR" =~ (Debian) ]]; then
  is_package_installed exuberant-ctags || install_package exuberant-ctags
fi

if [ ! -d ~/.vim ]; then
    echo "Create ~/.vim directory"
    mkdir ~/.vim
fi

if [[ "$os_VENDOR" =~ (Fedora) ]]; then
  is_package_installed vim-nerdtree || install_package vim-nerdtree
else
  if [ ! -f ~/.vim/plugin/NERD_tree.vim ]; then
    echo "Install nerdtree plugin"
    wget https://github.com/scrooloose/nerdtree/archive/master.zip -O master.zip
    unzip master.zip
    cp nerdtree-master/* ~/.vim/ -r
    rm nerdtree-master -rf
    rm master.zip
  fi
fi

if [ ! -f ~/.vim/plugin/tagbar.vim ]; then
    echo "Install tagbar plugin"
    wget https://github.com/majutsushi/tagbar/archive/master.zip -O master.zip
    unzip master.zip
    cp tagbar-master/* ~/.vim/ -r
    rm tagbar-master -rf
    rm master.zip
fi

if [ ! -f /usr/include/tags ]; then
    echo "Creating /usr/include/tags"
    sudo ctags -R -f /usr/include/tags /usr/include
fi

if [ ! -f ~/.vim/plugin/matchit.vim ]; then
    echo "Install matchit plugin"
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

if [ ! -f ~/.vim/plugin/git.vim ]; then
  echo "Install git-vim plugin"
  wget https://github.com/motemen/git-vim/archive/master.zip -O master.zip
  unzip master.zip
  cp git-vim-master/* ~/.vim/ -r
  rm git-vim-master -rf
  rm master.zip
fi

if [ ! -f ~/.vim/plugin/pymode.vim ]; then
  echo "Install python-mode plugin"
  wget https://github.com/klen/python-mode/archive/master.zip -O master.zip
  unzip master.zip
  cp python-mode-master/* ~/.vim/ -r
  rm python-mode-master -rf
  rm master.zip
fi

if [ ! -f ~/.vim/plugin/jedi.vim ]; then
  echo "Install jedi-vim plugin"
  wget https://github.com/davidhalter/jedi-vim/archive/master.zip -O master.zip
  unzip master.zip
  cp jedi-vim-master/* ~/.vim/ -r
  rm jedi-vim-master -rf
  rm master.zip
fi

cat > ~/.vim/vimrc <<EOF
" This file is created by vim-setup.sh

set expandtab
set shiftwidth=4
set softtabstop=4
set tabstop=4

"======================================
" Drupal Coding Standards

fu Drupal_style()
  set filetype=php
  set expandtab
  set tabstop=2
  set shiftwidth=2
  set autoindent
  set smartindent
endf

if has("autocmd")
  " Drupal *.module and *.install files.
  augroup module
    autocmd BufRead,BufNewFile *.module call Drupal_style
    autocmd BufRead,BufNewFile *.install call Drupal_style
    autocmd BufRead,BufNewFile *.test call Drupal_style
    autocmd BufRead,BufNewFile *.inc call Drupal_style
    autocmd BufRead,BufNewFile *.profile call Drupal_style
    autocmd BufRead,BufNewFile *.view call Drupal_style
  augroup END
endif
syntax on

"======================================
" coding standards specified in PEP 7 & 8

" Number of spaces that a pre-existing tab is equal to.
" For the amount of space used for a new tab use shiftwidth.
au BufRead,BufNewFile *py,*pyw,*.c,*.h set tabstop=8

" What to use for an indent.
" This will affect Ctrl-T and 'autoindent'.
" Python: 4 spaces
" C: tabs (pre-existing files) or 4 spaces (new files)
au BufRead,BufNewFile *.py,*pyw set shiftwidth=4
au BufRead,BufNewFile *.py,*.pyw set expandtab
fu Select_c_style()
    if search('^\t', 'n', 150)
        set shiftwidth=8
        set noexpandtab
    el
        set shiftwidth=4
        set expandtab
    en
endf
au BufRead,BufNewFile *.c,*.h call Select_c_style()
au BufRead,BufNewFile Makefile* set noexpandtab

" Use the below highlight group when displaying bad whitespace is desired.
highlight BadWhitespace ctermbg=red guibg=red

" Display tabs at the beginning of a line in Python mode as bad.
au BufRead,BufNewFile *.py,*.pyw match BadWhitespace /^\t\+/
" Make trailing whitespace be flagged as bad.
au BufRead,BufNewFile *.py,*.pyw,*.c,*.h match BadWhitespace /\s\+$/

" Wrap text after a certain number of characters
" Python: 79 
" C: 79
au BufRead,BufNewFile *.py,*.pyw,*.c,*.h set textwidth=79

" Turn off settings in 'formatoptions' relating to comment formatting.
" - c : do not automatically insert the comment leader when wrapping based on
"    'textwidth'
" - o : do not insert the comment leader when using 'o' or 'O' from command mode
" - r : do not insert the comment leader when hitting <Enter> in insert mode
" Python: not needed
" C: prevents insertion of '*' at the beginning of every line in a comment
au BufRead,BufNewFile *.c,*.h set formatoptions-=c formatoptions-=o formatoptions-=r

" Use UNIX (\n) line endings.
" Only used for new files so as to not force existing files to change their
" line endings.
" Python: yes
" C: yes
au BufNewFile *.py,*.pyw,*.c,*.h set fileformat=unix

"======================================

set fileencodings=ucs-bom,utf-8,gbk,default,latin1
set encoding=utf-8

" For full syntax highlighting
let python_highlight_all=1

" Automatically indent based on file type
filetype indent on
" Folding based on indentation
" set foldmethod=indent

"======================================

map <F2> :NERDTreeToggle<CR>
nnoremap <silent> <F8> :TagbarToggle<CR>

"======================================

" Turn on Line numbers
set number

let php_parent_error_close = 1
let php_parent_error_open = 1
let php_folding = 1

" highlight all its matches
set hlsearch

set tags=./tags,./TAGS,tags,TAGS,/usr/include/tags
EOF
if ! egrep -q '^so ~/.vim/vimrc$' ~/.vimrc; then
    echo "Customize ~/.vimrc"
    echo 'so ~/.vim/vimrc' >> ~/.vimrc
fi

# Restore xtrace
$XTRACE

echo "vim-setup.sh completed in $SECONDS seconds."
