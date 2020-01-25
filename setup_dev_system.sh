#!/bin/bash


### Things that must still be done manually
# 1. copy your public key into github
# 2. download and install zeromq
# 3. download and install eventqueue
# 4. download and install the ext directory


# Default colors
RED='\033[0;31m'
GREEN='\033[0;32m'
BLACK='\033[0;30m'

# The location in the user's home directory where Go stuff lives
DEV_DIR_NAME="dev"

CUR_USER=`who am i | awk '{print $1}'`

# Clean this up at somepoint since this is kind of redundant now
CUR_GO_PATH=`env | grep GOPATH 2> /dev/null | cut -d "=" -f2`


#####################################################
### Prints the help menu
#####################################################
usage() {
    cat <<EOF
setup_dev_system

NAME
        setup_dev_system - Configures a new install to conform to FBNC's development needs

SYNOPSIS
        setup_dev_system <flag>

DESCRIPTION
        This tool both checks system status and installs the needed toosl for
        development. The primary things that can be installed with this tool
        include the EPEL repo, core dev utilities, Cassandra (2.2.3), 
        Cassandra's dependencies, Git (2.8.0), Golang's developer toolset, and 
        ExtJS. Additionally this sets up the Go dev directory, generates your 
        Github ssh keys, creates Git aliases, pulls down Novetta's core repos 
        (Common, kerbproxy, etc.) and otherwise tries to provide a consistent
        development environment.

        -h
               prints this help screen

        -c
               checks the system

        -i       
               installs and configures everything

AUTHOR
        Another handy tool by James Stoup (jstoup@novetta.com)        
EOF
    
    exit 1
}

#####################################################
### Checks if the version of a binary is valid
#####################################################
checkForBin() {
    if hash $1 2>/dev/null; then
	BIN_VERSION=`$1 $2 | head -1`
        printf "  [SUCCESS] - $1 ($BIN_VERSION)\n"
    else
        printf "  [FAILURE] - $1 not found!\n"
    fi
}


#####################################################
### Checks if an rpm is installed
#####################################################
isInstalled() {
    if yum list installed "$@" >/dev/null 2>&1; then
	true
    else
	false
    fi
}


#####################################################
### Checks the status of the system
#####################################################
checkStatus() {
    echo "----------------------------"
    echo "-  CHECKING SYSTEM STATUS  -"
    echo "----------------------------"
    echo ""


    ### Make sure this is run properly
    if [ "$EUID" -eq 0 ]; then
	echo "please DON'T run me with sudo"
	exit 1
    fi

    ### Check if sudo is setup for this user
    echo "> Checking permissions"
    sudo echo -n " "
    if [ $? -ne 0 ]; then
	printf "  [FAILURE] - sudo\n"
	echo "    Sudo is not setup for this user!"
        echo "    To enable sudo for user $USER run visudo and"
	echo "    add this line at the end of the file:"
        echo "    <your_user_name_here> ALL=(ALL) NOPASSWD: ALL"
    else
	printf " [SUCCESS] - sudo enabled for this user\n"
    fi
    
    echo ""
    

    ### Check environment variables
    echo "> Checking for environment variables"

    # REFACTOR THIS
    # ALSO, put in checks for: USE_LIBRE and KLE_MIGRATE_DIR

    
    CLS=`env | grep _CLUSTER 2> /dev/null`
    CAS=`env | grep CASSANDRA_CONSISTENCY 2> /dev/null`
    MY_GOPATH=`env | grep GOPATH 2> /dev/null`
    MY_GOBIN=`env | grep GOBIN 2> /dev/null`

    if [[ -z $CLS ]] ; then
	printf "  [FAILURE] - "
    else
	printf "  [SUCCESS] - "
    fi
    echo "*_CLUSTER"

    if [[ -z $CAS ]] ; then
	printf "  [FAILURE] - "
    else
	printf "  [SUCCESS] - "
    fi
    echo "CASSANDRA_CONSISTENCY"


    if [[ -z $MY_GOPATH ]] ; then
	printf "  [FAILURE] - "
	echo "WARNING the GOPATH environment variable is not set. Please fix this and run this check again!"
	exit 1
    else
	printf "  [SUCCESS] - "
    fi
    echo "GOPATH"

    if [[ -z $MY_GOBIN ]] ; then
	printf "  [FAILURE] - "
    else
	printf "  [SUCCESS] - "
    fi
    echo "GOBIN"

    if [[ -z $CAS ]] || [[ -z $CLS ]]; then
	echo "To set the needed variables for this session"
	echo "source the .env file in the conf directory"
	echo "of the application you are trying to run."
    fi
    echo ""


    ### Check if the required directories exists in /opt
    echo "> Checking /opt directories"    

    OPT_FILES_STR=`find $CUR_GO_PATH/src/github.com/Novetta -name "*.env" | xargs grep "/opt/" | cut -d ":" -f2 | grep -v "^#" | grep export | cut -d "=" -f2 | cut -d "/" -f3 | tr -d "\"" | sort -u  | tr "\n" " " | tr " " "\n" | grep -v PATH | tr "\n" " "`

    OIFS=$IFS
    IFS=" "
    OPT_FILES=($OPT_FILES_STR)

    for key in "${!OPT_FILES[@]}" 
    do 
	KEY_DIR="/opt/${OPT_FILES[$key]}"

	# Check if dir exists
	if [ -d $KEY_DIR ]; then
	    KEY_PERM=`stat -c "%a" $KEY_DIR`
	    
	    # If it exists, make sure the permissions are correct
	    if [ $KEY_PERM -ne 755 ] ; then
		printf "  [FAILURE] - $KEY_DIR (permissions should be 755 not $KEY_PERM)\n"
	    else
		printf "  [SUCCESS] - $KEY_DIR\n"
	    fi
	else
	    printf "  [FAILURE] - $KEY_DIR\n"
	fi

    done

    IFS=$OIFS

    echo ""


    ### Make sure migrate is installed
    echo "> Checking for required tools"

    checkForBin migrate "-version"
    checkForBin cassandra "-v"
    checkForBin go "version"
    checkForBin git "--version"
    checkForBin emacs "--version"
    checkForBin vim "--version"
    checkForBin sencha "help"


    ### Check the Git submodules for each project
    # Need to run 'git submodule status --recursive' at the root of each project
    # output a warning if it starts with "-" (not initialized)
    # output a failure if it starts with a "+" or a "U" (hash doesn't match or conflicts)
    # git submodule init --recursive
    # git submodule update --recursive
    # git submodule sync --recursive  should do it


    echo ""
    exit 1
}


#####################################################
### Check to make sure this isn't run with sudo
#####################################################
sudoCheck() {
    if [ $EUID -eq 0 ]; then
	echo "This script doesn't need to be run with sudo"
	exit 1
    fi
}


#####################################################
### Check to make sure we aren't running this as root
#####################################################
rootCheck() {
    WHO_AM_I=`who am i | awk '{print $1}'`
    if [[ "$WHO_AM_I" = "root" ]]; then
	echo "WARNING! You can't run this AS the root user!" 
	echo "This should be installed as a user because this script"
	echo "installs into the user's home directory and you do not "
	echo "this installed in /root."
	exit 1
    fi
}

#####################################################
### Welcome
#####################################################
printWelcome() {
    echo "=================================================="
    echo "===     DEVELOPER SETUP/CONFIGURE SCRIPT      ==="
    echo "=================================================="
    echo ""
    echo "Welcome to the developers setup script. This"
    echo "script should configure a new machine for our"
    echo "basic development layout."
    echo ""
}


#####################################################
### Print default install banner
#####################################################
printInstallBanner() {
    echo ""
    echo "  ==================================="
    echo "  === $1"
    echo "  ==================================="
}


#####################################################
### Print new heading
#####################################################
printInstallHeading() {
    echo ""
    echo "-- $1"
}



#####################################################
### Add additional repos to your system
#####################################################
addRepos() {
    read -p "  [$counter] Do you want to install extra repos? (y/n) " -n 1 -r
    counter=$((counter+1)) 

    if [[ $REPLY =~ ^[Yy]$ ]] ; then
	printInstallBanner "Installing the extra repos"

	echo " Installing EPEL, Remi and Datastax..."
	sudo rpm -Uvh http://dl.fedoraproject.org/pub/epel/6/x86_64/epel-release-6-8.noarch.rpm
	sudo rpm -Uvh http://rpms.famillecollet.com/enterprise/remi-release-6.rpm

	# Install Datastax differently because they are special snowflakes
	TEMP_LOC="/tmp/datastax.repo"
	touch $TEMP_LOC

	echo "[datastax]" >> $TEMP_LOC
	echo "name = DataStax Repo for Apache Cassandra" >> $TEMP_LOC
	echo "baseurl = https://rpm.datastax.com/community" >> $TEMP_LOC
	echo "enabled = 1" >> $TEMP_LOC
	echo "gpgcheck = 0" >> $TEMP_LOC

	sudo mv $TEMP_LOC /etc/yum.repos.d/datastax.repo
	
	echo ""
    fi
    echo ""
}


#####################################################
### Install additional packages
#####################################################
addRPMs() {
    read -p "  [$counter] Do you want to install additional packages? (y/n) " -n 1 -r
    counter=$((counter+1)) 

    if [[ $REPLY =~ ^[Yy]$ ]] ; then
	printInstallBanner "Installing extra RPMs"

	RPMS=(
	    ack
	    autoconf
	    automake
	    bash-completion
	    cmake
	    curl-devel
	    emacs
	    expat-devel
	    freetype-devel
	    ftp
	    gcc
	    gcc-c++
	    gettext-devel
	    giflib
	    giflib-devel
	    giflib-utils
	    git
	    gtk2-devel
	    ImageMagick
	    libjpeg
	    libjpeg-turbo
	    libjpeg-turbo-devel
	    libstdc++
	    libtiff
	    libtiff-devel
	    libtool
	    libXpm
	    libXpm-devel
	    make
	    mercurial
	    nasm
	    ncurses-devel
	    openoffice.org-base
	    openoffice.org-base-core
	    openoffice.org-brand
	    openoffice.org-calc
	    openoffice.org-calc-core
	    openoffice.org-core
	    openoffice.org-devel
	    openoffice.org-draw
	    openoffice.org-draw-core
	    openoffice.org-graphicfilter
	    openoffice.org-headless
	    openoffice.org-impress
	    openoffice.org-impress-core
	    openoffice.org-math
	    openoffice.org-math-core
	    openoffice.org-ogltrans
	    openoffice.org-pdfimport
	    openoffice.org-presentation-minimizer
	    openoffice.org-rhino
	    openoffice.org-sdk
	    openoffice.org-sdk-doc
	    openoffice.org-testtools
	    openoffice.org-writer
	    openoffice.org-writer-core
	    openssl-devel
	    perl-ExtUtils-MakeMaker
	    pkgconfig
	    uuid-devel
	    xclip
	    yasm
	    zlib-devel
	)

	for rpm in "${RPMS[@]}"
	do
	    echo "--------------------------"
	    echo "> INSTALLING RPM $rpm"
	    echo ""
	    sudo yum install -y $rpm
	    echo ""
	    echo ""
	done

	echo ""
	
    fi
    echo ""   

}


#####################################################
### Disable firewall
#####################################################
disableFirewall() {
    read -p "  [$counter] Do you want to disable iptables? (y/n) " -n 1 -r
    counter=$((counter+1)) 

    if [[ $REPLY =~ ^[Yy]$ ]] ; then
	printInstallBanner "Disabling iptables & ip6tables"

	sudo service iptables stop
	sudo service ip6tables stop

	sudo chkconfig iptables off
	sudo chkconfig ip6tables off
	
    fi
    echo ""
}


#####################################################
### Install Cassandra 2.2.3
#####################################################
installCassandra() {
    read -p "  [$counter] Do you want to install Cassandra 2.2.3? (y/n) " -n 1 -r
    counter=$((counter+1)) 

    if [[ $REPLY =~ ^[Yy]$ ]] ; then
	printInstallBanner "Installing Cassandra 2.2.3"

	# Disable some IPV6 stuff that gives cassandra pains
	sudo sysctl -w net.ipv6.conf.all.disable_ipv6=1
	sudo sysctl -w net.ipv6.conf.default.disable_ipv6=1

	# If Datastax repo hasn't been installed, do it now
	if [[ ! -f /etc/yum.repos.d/datastax.repo ]] ; then

	    TEMP_LOC="/tmp/datastax.repo"
	    touch $TEMP_LOC
	    
	    echo "[datastax]" >> $TEMP_LOC
	    echo "name = DataStax Repo for Apache Cassandra" >> $TEMP_LOC
	    echo "baseurl = https://rpm.datastax.com/community" >> $TEMP_LOC
	    echo "enabled = 1" >> $TEMP_LOC
	    echo "gpgcheck = 0" >> $TEMP_LOC
	    
	    sudo mv $TEMP_LOC /etc/yum.repos.d/datastax.repo
	fi

	# Add exclude string
	sudo sh -c 'echo "exclude=cassandra22-2.2.4* dsc22-2.2.4* cassandra22-tools-2.2.4* cassandra22-2.2.5* dsc22-2.2.5* cassandra22-tools-2.2.5* cassandra22-2.2.6* dsc22-2.2.6* cassandra22-tools-2.2.6* cassandra22-2.2.7* dsc22-2.2.7* cassandra22-tools-2.2.7 cassandra22-2.2.8* dsc22-2.2.8* cassandra22-tools-2.2.8*"  >> /etc/yum.conf'

	sudo yum install -y cassandra22.noarch cassandra22-tools.noarch
	echo ""
    fi
    echo ""

}



#####################################################
### Install Lucene
#####################################################
installLucene() {
    read -p "  [$counter] Do you want to install Lucene? (y/n) " -n 1 -r
    counter=$((counter+1)) 

    if [[ $REPLY =~ ^[Yy]$ ]] ; then
	printInstallBanner "Installing Lucene"

	NOVAHOME=$GOPATH/src/github.com/Novetta
	LUCENE_FILES=$NOVAHOME/common/lucene/cassandra-lucene-index-plugin* 

	if ls $LUCENE_FILES 1> /dev/null 2>&1; then
	    sudo cp $NOVAHOME/common/lucene/cassandra-lucene-index-plugin* /usr/share/cassandra/lib/
	    sudo chown cassandra:cassandra /usr/share/cassandra/lib/cassandra-lucene-index-plugin*
	    sudo service cassandra restart
	else
	    echo "WARNING! Lucene not found. Check in $GOPATH/common/lucene for the jar file"
	fi
    fi
    echo ""
}


#####################################################
### Install Custom RPMs
#####################################################
installCoreDependencies() {
    read -p "  [$counter] Do you want to install our custom RPMs? (y/n) " -n 1 -r
    counter=$((counter+1)) 

    if [[ $REPLY =~ ^[Yy]$ ]] ; then
	printInstallBanner "Installing Core Dependencies"

	# NOVAHOME=$GOPATH/src/github.com/Novetta
	# CUSTOM_PATH=$NOVAHOME/common/bin

	
	# ### Install the RPM tools
	# # Need rpm-build
	# if ! isInstalled rpm-build ; then
	#     sudo yum install -y rpm-build
	# fi

	# # Need redhat-rpm-config too
	# if ! isInstalled redhat-rpm-config ; then
	#     sudo yum install -y redhat-rpm-config
	# fi
	
	# mkdir -p ~/rpmbuild/{BUILD,RPMS,SOURCES,SPECS,SRPMS}
	# echo '%_topdir %(echo $HOME)/rpmbuild' > ~/.rpmmacros

	
	### Build needed core libraries

	# so we need libsodium (maybe, not using it just yet, but we might)
	# cd /tmp
	# LIBSODIUM='libsodium-1.0.9'
	# wget https://download.libsodium.org/libsodium/releases/$LIBSODIUM.tar.gz
	# tar -xzf $LIBSODIUM
	# cd $LIBSODIUM
	# ./autogen.sh
	# ./configure --with-libsodium=no
	# make
	# sudo make install
	# cd -
	
	# now we can build zeromq
	# cd /tmp
	# ZMQ="zeromq-4.1.3"
	# wget https://archive.org/download/zeromq_4.1.3/$ZMQ.tar.gz
	# tar -xzf $ZMQ.tar.gz
	# cd $ZMQ
	# ./configure --with-libsodium=no
	# make
	# sudo make install
	# sudo sh -c 'echo /usr/local/lib > /etc/ld.so.conf.d/local.conf'
	# sudo ldconfig
	
	# ### Build our own RPMs and install them
	# cd $CUSTOM_PATH
	# # Eventually build a loop to iterate through everything	but for now, just pick out what we need
	# ./jenkins-eventqueue
	# sudo yum install -y ~/rpmbuild/RPMS/x86_64/eventqueue-*.x86_64.rpm
	# sudo chkconfig eventqueue on
	# cd -
    fi
    echo ""
}


#####################################################
### Install Migrate Tool (might not need this anymore)
#####################################################
installMigrate() {
    read -p "  [$counter] Do you want to install the migrate tool? (y/n) " -n 1 -r
    counter=$((counter+1)) 

    if [[ $REPLY =~ ^[Yy]$ ]] ; then
	printInstallBanner "Installing Migrate"
	go get -u github.com/mattes/migrate
	cd $GOPATH/src/github.com/mattes/migrate
	git checkout master
	cd -
    fi
    echo ""
}


#####################################################
### Install Go
#####################################################
installGo() {
    GOVER=1.6.1
    
    read -p "  [$counter] Do you want to install Go $GOVER? (y/n) " -n 1 -r
    counter=$((counter+1)) 

    if [[ $REPLY =~ ^[Yy]$ ]] ; then
	printInstallBanner "Installing Go"

	# Setup the Go Dev directory structure
	mkdir ~/$DEV_DIR_NAME
	cd  ~/$DEV_DIR_NAME
	mkdir bin pkg src

	echo "# Go Environment Variables" >> ~/.bashrc
	echo "export GOPATH=\$HOME/\$DEV_DIR_NAME" >> ~/.bashrc
	echo "export GOBIN=\$GOPATH/bin" >> ~/.bashrc
	echo "export GOROOT=/usr/local/go" >> ~/.bashrc
	echo "" >> ~/.bashrc
	echo "export PATH=$PATH:\$GOBIN:\$GOROOT/bin" >> ~/.bashrc

	source ~/.bashrc
	cd $HOME/Downloads

	wget "https://storage.googleapis.com/golang/go$GOVER.linux-amd64.tar.gz"
	sudo tar -C /usr/local -xzf go$GOVER.linux-amd64.tar.gz

	# I probably can get rid of this
	echo "export GOPATH=$GOPATH" | tee -a $HOME/.env
	source $HOME/.env
	cd $HOME

    fi
    echo ""
}


#####################################################
### Install Go Lint
#####################################################
installGoLinters() {
    read -p "  [$counter] Do you want to install Go Lint? (y/n) " -n 1 -r
    counter=$((counter+1)) 

    if [[ $REPLY =~ ^[Yy]$ ]] ; then
	printInstallBanner "Installing Go Lint (requires ssh key in github)"

	# TODO - put a check in to make sure GOPATH is set
	go get -u github.com/golang/lint/golint

    fi
    echo ""
}


#####################################################
### Install the additional Go dev tools
#####################################################
installGoTools() {
    read -p "  [$counter] Do you want to install extra Go tools? (y/n) " -n 1 -r
    counter=$((counter+1)) 

    if [[ $REPLY =~ ^[Yy]$ ]] ; then
	printInstallBanner "Pulling down the Golang Tools"
	go get golang.org/x/tools/cmd/...
	go get github.com/rogpeppe/godef
	go get -u github.com/nsf/gocode
	go get golang.org/x/tools/cmd/goimports
    fi
    echo ""
}


#####################################################
### Install Git 2.8.0
#####################################################
installGit() {
    read -p "  [$counter] Do you want to install Git 2.8.0? (y/n) " -n 1 -r
    counter=$((counter+1)) 

    if [[ $REPLY =~ ^[Yy]$ ]] ; then
	printInstallBanner "Installing Git"

	sudo yum install -y curl-devel expat-devel gettext-devel openssl-devel zlib-devel gcc perl-devel
	sudo yum install -y asciidoc xmlto docbook2X
	sudo ln -s /usr/bin/db2x_docbook2texi /usr/bin/docbook2x-texi
	sudo yum install -y autoconf
	GIT_VERSION_TO_INSTALL="2.8.0"
	MY_CUR_DIR=`pwd`
	cd ~/Downloads
	wget https://github.com/git/git/archive/v$GIT_VERSION_TO_INSTALL.tar.gz
	tar -xzf v$GIT_VERSION_TO_INSTALL.tar.gz
	cd git-$GIT_VERSION_TO_INSTALL
	make configure
	./configure --prefix=/usr
	make all doc info
	sudo make install install-doc install-html install-info
	cd ../
	rm -rf git-$GIT_VERSION_TO_INSTALL*
	rm -rf v$GIT_VERSION_TO_INSTALL.tar.gz
	cd $MY_CUR_DIR

    fi
    echo ""

}


#####################################################
### Configure Git with aliases and user info
#####################################################
configureGit() {
    read -p "  [$counter] Do you want to configure Git? (y/n) " -n 1 -r
    counter=$((counter+1)) 

    if [[ $REPLY =~ ^[Yy]$ ]] ; then
	printInstallBanner "Setup Git Config"

	
	if [[ -z $USER_EMAIL ]] ; then
	    echo -n "Please enter your email address > "
	    read USER_EMAIL

	    while true; do
		echo "You entered: $USER_EMAIL"
		read -p "  Is this correct? (y/n) " yn
		case $yn in
		    
		    [Yy]* ) break;;
		    [Nn]* ) echo -n "Please enter your email address > " ; read USER_EMAIL;;
		    * ) echo "Please answer yes or no.";;
		esac
	    done
	fi

	git config --global user.name $USER_NAME
	git config --global user.email $USER_EMAIL
	git config --global core.editor emacs
	git config --global core.autocrlf input
	git config --global core.safecrlf true
	git config --global core.excludesfile "~/.gitignore_global"
	git config --global color.ui always
	git config --global push.default simple
	git config --global credential.helper "cache --timeout=36000"
	git config --global url.ssh://git@github.com/.insteadOf https://github.com/
	git config --global alias.co checkout
	git config --global alias.stage add
	git config --global alias.switch checkout
	git config --global alias.unstage "reset HEAD"
	git config --global alias.delete "branch -d"
	GIT_LL_STR='log --pretty=format:"%C(yellow)%h%Cred%d\\ %Creset%s%Cblue\\ [%cn]" --decorate --numstat'
	echo "        ll       = $GIT_LL_STR" >> ~/.gitconfig
	GIT_LS_STR='log --pretty=format:"%C(yellow)%h%Cred%d\\ %Creset%s%Cblue\\ [%cn]" --decorate'
	echo "        ls       = $GIT_LS_STR" >> ~/.gitconfig
	GIT_LDR_STR='log --pretty=format:"%C(yellow)%h\\ %ad%Cred%d\\ %Creset%s%Cblue\\ [%cn]" --decorate --date=relative'
	echo "        ldr      = $GIT_LDR_STR" >> ~/.gitconfig
	GIT_LDS_STR='log --pretty=format:"%C(yellow)%h\\ %ad%Cred%d\\ %Creset%s%Cblue\\ [%cn]" --decorate --date=short'
	echo "        lds      = $GIT_LDS_STR" >> ~/.gitconfig

	echo "New data written to ~/.gitconfig"
    fi
    echo ""
}


#####################################################
### Generate the SSH key for Github
#####################################################
generateSshKey() {
    read -p "  [$counter] Do you want to generate your SSH keys for github? (y/n) " -n 1 -r
    counter=$((counter+1)) 

    if [[ $REPLY =~ ^[Yy]$ ]] ; then
	printInstallBanner "Generating an SSH Key for Github"

	echo ""
	echo -n "Please enter your email address > "
	read USER_EMAIL

	while true; do
	    echo "You entered: $USER_EMAIL"
	    read -p "  Is this correct? (y/n) " yn
	    case $yn in
		
		[Yy]* ) break;;
		[Nn]* ) echo -n "Please enter your email address > " ; read USER_EMAIL;;
		* ) echo "Please answer yes or no.";;
	    esac
	done

	ssh-keygen -t rsa -b 4096 -C $USER_EMAIL

	echo "Adding id_rsa to the ssh agent"
	ssh-add ~/.ssh/id_rsa

	echo "Be sure to visit https://github.com/settings/ssh to enter this ssh key."
	echo "Failure to add this key to github will prevent git from working properly."

    fi
    echo ""
}


#####################################################
### Pull down the Novetta repos
#####################################################
installNovettaRepos() {
    # Important note! You have to have the ssh keys created
    # and github authorized for those keys before this will work.

    read -p "  [$counter] Do you want to install the Novetta repos? (y/n) " -n 1 -r
    counter=$((counter+1)) 

    if [[ $REPLY =~ ^[Yy]$ ]] ; then
	printInstallBanner "Pulling down the Novetta Repos"
	echo ""
	echo "This might take a while..."

	NOVA_REPOS=(common
		    fbncjs
		    gokerb
		    goldap
		    ITK
		    KLE
		    kerbproxy)
		    

	cd ~/$DEV_DIR_NAME
	
	export GOPATH=$CUR_GO_PATH

	for repo in "${NOVA_REPOS[@]}"
	do
	    echo "--------------------------"
	    echo "> Installing $repo"
	    go get github.com/Novetta/$repo
	    cd $GOPATH/src/github.com/Novetta/$repo
	    echo "> UPDATING REPO"
	    go get -u -f -v 
	    echo "> UPDATING SUBMODULES"
	    git submodule update --init --recursive 
	    cd ../

	done

	# Pull down some misc github stuff
	go get -u github.com/pebbe/zmq4
	go get -u github.com/TomiHiltunen/geohash-golang
	go get -u github.com/go-martini/martini
	go get -u github.com/fatih/set
	cd $GOPATH/src/github.com/fatih/set/
	git checkout master
	cd -
	go get -u github.com/martini-contrib/encoder
	go get -u github.com/martini-contrib/gzip
	go get -u github.com/nfnt/resize
	go get -u github.com/nlacey/go-cairo
	go get -u github.com/paulmach/go.geojson
	go get -u github.com/the42/cartconvert/cartconvert
	go get github.com/tealeg/xlsx 

	# setup the environment variables correctly

	# create the search tables
	cd $GOPATH/src/github.com/Novetta/common/aide/search/setup
	./updateDb.sh
	cd -
	
    fi
    
    echo ""
}


#####################################################
### Configure /opt with the correct permissions
#####################################################
configureOpt() {
    read -p "  [$counter] Do you want to create the app directories in /opt and set correct permissions? (y/n) " -n 1 -r
    counter=$((counter+1)) 

    if [[ $REPLY =~ ^[Yy]$ ]] ; then
	printInstallBanner "Creating directories in /opt"

	OPT_FILES_STR=`find $CUR_GO_PATH/src/github.com/Novetta -name "*.env" | xargs grep "/opt/" | cut -d ":" -f2 | grep -v "^#" | grep export | cut -d "=" -f2 | cut -d "/" -f3 | tr -d "\"" | sort -u  | tr "\n" " " | tr " " "\n" | grep -v PATH | tr "\n" " "`

	OIFS=$IFS
	IFS=" "
	OPT_FILES=($OPT_FILES_STR)

	CUR_PERSON=`whoami`
	CUR_GROUP=`groups`
	
	for key in "${!OPT_FILES[@]}" 
	do 
	    KEY_DIR="/opt/${OPT_FILES[$key]}"

	    # Check if dir exists
	    if [ -d $KEY_DIR ]; then
		KEY_PERM=`stat -c "%a" $KEY_DIR`
		
		# If it exists, make sure the permissions are correct
		if [ $KEY_PERM -ne 755 ] ; then
		    sudo chmod 755 $KEY_DIR
		fi
	    else
		sudo mkdir -m 755 $KEY_DIR
	    fi

	    sudo chown $CUR_PERSON:$CUR_GROUP $KEY_DIR
	    
	    #val="SUCCESS"
	    #printf "%10s -[ %30s]\n" "$KEY_DIR" "$val"
	    printf "[SUCCESS] %20s\n" "$KEY_DIR"
	done

	IFS=$OIFS


	
    fi
    echo ""
}


#####################################################
### Install NodeJS
#####################################################
installNode() {
    read -p "  [$counter] Do you want to install NodeJS & JS tools? (y/n) " -n 1 -r
    counter=$((counter+1)) 

    if [[ $REPLY =~ ^[Yy]$ ]] ; then
	printInstallBanner "Installing JS tools & linters"

	sudo yum install -y nodejs
	sudo yum install -y npm
	
	# now install npm packages
	NODE_GLOBAL="js-beautify"

	for N in $NODE_GLOBAL
	do
	    sudo npm -g install $N
	done
    fi
    echo ""

}


#####################################################
### Install Chrome
#####################################################
installChrome() {
read -p "  [$counter] Do you want to install Chrome? (y/n) " -n 1 -r
    counter=$((counter+1)) 

    if [[ $REPLY =~ ^[Yy]$ ]] ; then
	printInstallBanner "Installing Chrome"

	echo "Installing Google Chrome"
	cd $HOME/Downloads
	wget https://dl.google.com/linux/direct/google-chrome-stable_current_x86_64.rpm
	sudo yum install -y google-chrome-stable_current_x86_64.rpm
	cd $HOME
    fi
    echo ""
}


#####################################################
### Install the one true editor
#####################################################
installEmacs() {

        read -p "  [$counter] Do you want to install emacs? (y/n) " -n 1 -r
    counter=$((counter+1)) 

    if [[ $REPLY =~ ^[Yy]$ ]] ; then
	printInstallBanner "Installing emacs"

	if [ ! -d ~/Downloads ] ; then
	    mkdir ~/Downloads
	fi
	cd ~/Downloads
	emacsVersion=24.5
	wget ftp://ftp.gnu.org/pub/gnu/emacs/emacs-$emacsVersion.tar.gz
	tar -xzf emacs-$emacsVersion.tar.gz
	cd emacs-$emacsVersion
	./configure
	make
	sudo make install
	# put in check to see if emacs was installed correctly
	cd ../
	rm -rf emacs-$emacsVersion

    fi
    echo ""
    }



#####################################################
### Configure bashrc to handle git properly
#####################################################
configureGitBash() {
read -p "  [$counter] Do you want to configure Bash to handle Git? (y/n) " -n 1 -r
    counter=$((counter+1)) 

    if [[ $REPLY =~ ^[Yy]$ ]] ; then
	printInstallBanner "Configuring Bash"

	read -d '' new_PS1_prompt <<"EOF"

    # ==================================
    # == Enhancing bash for git usage ==
    # ==================================
    function _git_prompt() {
        local git_status="`git status -unormal 2>&1`"
        if ! [[ "$git_status" =~ Not\\ a\\ git\\ repo ]]; then
            if [[ "$git_status" =~ nothing\\ to\\ commit ]]; then
                local ansi=42
            elif [[ "$git_status" =~ nothing\\ added\\ to\\ commit\\ but\\ untracked\\ files\\ present ]]; then
                local ansi=43
            else
                local ansi=41
            fi
            if [[ "$git_status" =~ On\\ branch\\ ([^[:space:]]+) ]]; then
                branch=${BASH_REMATCH[1]}
                test "$branch" != master || branch=' '
            else
                # Detached HEAD.  (branch=HEAD is a faster alternative.)
                branch="(`git describe --all --contains --abbrev=4 HEAD 2> /dev/null ||
                    echo HEAD`)"
            fi
            echo -n '\\[\\e[0;37;'"$ansi"';1m\\]'"$branch"'\\[\\e[0m\\] '
        fi
    }

    function _prompt_command() {
        PS1="`_git_prompt`"'[\\[\\033[0;36m\\]\\u$ \\t \\[\\033[0;34m\\]\\w\\[\\033[0;30m\\]]\\$\\[\\e[0m\\] '
    }
    PROMPT_COMMAND=_prompt_command
EOF

	echo "${new_PS1_prompt}" >> ~/.bashrc
	
    fi
    echo ""
}



#####################################################
### Install Sencha Cmd
#####################################################
installSenchaCmd() {
read -p "  [$counter] Do you want to install Sencha Cmd? (y/n) " -n 1 -r
    counter=$((counter+1)) 

    if [[ $REPLY =~ ^[Yy]$ ]] ; then
	printInstallBanner "Installing Sencha Cmd"

	cmdVersion="6.1.3"
	fileStr="SenchaCmd-$cmdVersion-linux-amd64.sh"
	cmdUrl="cdn.sencha.com/cmd/$cmdVersion/no-jre/$fileStr.zip"

	cd ~/Downloads
	wget $cmdUrl
	unzip "$fileStr.zip"
	chmod a+x "SenchaCmd-$cmdVersion.42-linux-amd64.sh" #clean this up
	./"SenchaCmd-$cmdVersion.42-linux-amd64.sh"         #clean this up
    fi
    echo ""
}


#####################################################
### Does all the heavy lifting of installing stuff
#####################################################
installAndConfigure() {
    clear
    counter=1

    # Make sure we aren't running this with sudo or root
    sudoCheck
    rootCheck

    # Print welcome info
    printWelcome

    # Install system 
    printInstallHeading "SYSTEM"
    addRepos
    addRPMs
    disableFirewall
    
    # Install Git
    printInstallHeading "GIT"
    installGit
    configureGit
    generateSshKey

    # Install Go
    printInstallHeading "GOLANG"
    installGo
    installGoLinters
    installGoTools

    # Install database
    printInstallHeading "DATABASE"
    installCassandra
    installMigrate
    
    # Pull down Novetta stuff
    printInstallHeading "NOVETTA"
    installNovettaRepos
    configureOpt
    installLucene #this need GOAPTH and common
    installCoreDependencies #this need GOAPTH and common

    # Install js
    printInstallHeading "JAVASCRIPT"
    installNode

    # Install tools
    printInstallHeading "TOOLS"
    installChrome
    installEmacs
    configureGitBash

    # Sencha
    printInstallHeading "SENCHA"
    installSenchaCmd

    echo ""
    exit 1
}


#####################################################
# If they just ran it blind, print the help
#####################################################
if [[ -z "$1" ]]; then
    usage
fi


#####################################################
# Parse the args
#####################################################
while getopts ":hci" opt; do
    case $opt in
	h)
	    usage
	    ;;
	c)
	    check=true
	    checkStatus
	    ;;
	i)
	    install=true
	    installAndConfigure
	    ;;
	*)
	    usage
	    ;;
    esac
done


#####################################################
# Check to make sure they didn't enter gibberish
#####################################################
if [ "$check" = true ] || [ "$install" = true ] ; then
    echo ""
else
    usage
fi



