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

# Translate the OS version values into common nomenclature
# Sets ``DISTRO`` from the ``os_*`` values
function GetDistro() {
    GetOSVersion
    if [[ "$os_VENDOR" =~ (Ubuntu) ]]; then
        # 'Everyone' refers to Ubuntu releases by the code name adjective
        DISTRO=$os_CODENAME
    elif [[ "$os_VENDOR" =~ (Fedora) ]]; then
        # For Fedora, just use 'f' and the release
        DISTRO="f$os_RELEASE"
    elif [[ "$os_VENDOR" =~ (openSUSE) ]]; then
        DISTRO="opensuse-$os_RELEASE"
    elif [[ "$os_VENDOR" =~ (SUSE LINUX) ]]; then
        # For SLE, also use the service pack
        if [[ -z "$os_UPDATE" ]]; then
            DISTRO="sle${os_RELEASE}"
        else
            DISTRO="sle${os_RELEASE}sp${os_UPDATE}"
        fi
    else
        # Catch-all for now is Vendor + Release + Update
        DISTRO="$os_VENDOR-$os_RELEASE.$os_UPDATE"
    fi
    export DISTRO
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
    else
        exit_distro_not_supported "finding if a package is installed"
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

# Distro-agnostic package installer
# install_package package [package ...]
function install_package() {
    if is_debian; then
        [[ "$NO_UPDATE_REPOS" = "True" ]] || apt_get update
        NO_UPDATE_REPOS=True

        apt_get install "$@"
    elif is_fedora; then
        yum_install "$@"
    elif is_suse; then
        zypper_install "$@"
    else
        exit_distro_not_supported "installing packages"
    fi
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

# Determine if current distribution is a SUSE-based distribution
# (openSUSE, SLE).
# is_suse
function is_suse {
    if [[ -z "$os_VENDOR" ]]; then
        GetOSVersion
    fi

    [ "$os_VENDOR" = "openSUSE" ] || [ "$os_VENDOR" = "SUSE LINUX" ]
}

# Exit after outputting a message about the distribution not being supported.
# exit_distro_not_supported [optional-string-telling-what-is-missing]
function exit_distro_not_supported {
    if [[ -z "$DISTRO" ]]; then
        GetDistro
    fi

    if [ $# -gt 0 ]; then
        echo "Support for $DISTRO is incomplete: no support for $@"
    else
        echo "Support for $DISTRO is incomplete."
    fi

    exit 1
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

# zypper wrapper to set arguments correctly
# zypper_install package [package ...]
function zypper_install() {
    [[ "$OFFLINE" = "True" ]] && return
    local sudo="sudo"
    [[ "$(id -u)" = "0" ]] && sudo="env"
    $sudo http_proxy=$http_proxy https_proxy=$https_proxy \
        zypper --non-interactive install --auto-agree-with-licenses "$@"
}

GetDistro
echo "vim setup for $os_VENDOR $os_RELEASE $os_UPDATE $os_PACKAGE $os_CODENAME $DISTRO"

# root access
# vim-setup.sh is designed to be run as a non-root user but need sudo priviledge to install packages.
if [[ $EUID -eq 0 ]]; then
  echo "You are running this script as root."
  is_package_installed sudo || install_package sudo
  # TODO: who am i
else
  is_package_installed sudo || die "Sudo is required. Re-run vim-setup.sh as root to setup sudo."
fi

# Save trace setting
XTRACE=$(set +o | grep xtrace)
set +o xtrace

echo "Install vim"
is_package_installed vim || install_package vim
echo "Install ctags"
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

set tabstop=2
set shiftwidth=2
set expandtab

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
syntax on

" Automatically indent based on file type
filetype indent on
" Keep indentation level from previous line
set autoindent
" Folding based on indentation
" set foldmethod=indent

"======================================

map <F2> :NERDTreeToggle<CR>
nnoremap <silent> <F8> :TagbarToggle<CR>

"======================================

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

" Turn on Line numbers
set number

let php_parent_error_close = 1
let php_parent_error_open = 1
let php_folding = 1

" highlight all its matches
set hlsearch
EOF
if ! egrep -q '^so ~/.vim/vimrc$' ~/.vimrc; then
  echo "Customize ~/.vimrc"
  echo 'so ~/.vim/vimrc' >> ~/.vimrc
fi

# Restore xtrace
$XTRACE

echo "vim-setup.sh completed in $SECONDS seconds."
