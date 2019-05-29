#!/bin/bash

################################################################################
## Hongkee Yoon Hongkeeyoon@kaist.ac.kr
## 2019.05
## https://kaist-elst.github.io/DFTforge.jl/
################################################################################

RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m'

echo 'This is JX installer. If Julia is already installed simply type julia install.jl'

echo ' To install julia see: https://julialang.org/downloads/'
echo ' Platform specfic detail see: https://julialang.org/downloads/platform.html'
echo '========================================================================='
printf "${RED} Please install hdf5 lib before the install (e.g. in Ubuntu 'apt-get install hdf5-tools', OSX 'brew install hdf5') ${NC} \n"
echo '========================================================================='

printf "${BLUE} 1. Installing the  Julia ${NC} \n"
sleep 2
case "$OSTYPE" in
  #solaris*) echo "SOLARIS" ;;
  darwin*)  echo "OSX"
  brew cask install julia
  ;;
  linux*)
  echo "Linux"
  mkdir -p ~/bin
  echo 'export PATH=~/bin:$PATH' >>~/.profile
  echo 'export PATH=~/bin:$PATH' >>~/.bashrc
  JULIA_INSTALL=~/bin  bash -ci "$(curl -fsSL https://raw.githubusercontent.com/abelsiqueira/jill/master/jill.sh)"
  ;;
  bsd*)     echo "BSD"
  echo 'Visit https://julialang.org/downloads/'
  ;;
  *)        echo "unknown: $OSTYPE"
  echo 'Visit https://julialang.org/downloads/'
  ;;
esac

echo ' The Julia install would be finished.'

echo ' Now the below commands will be excuted'
echo '${BLUE}source ~/.profile # to detect installed Julia'
echo '${BLUE}julia install.jl'

source ~/.profile
printf "${BLUE} 2. Installing required Julia packages & DFTforge.jl ${NC}\n"
sleep 2
julia install.jl

echo '========================================================================='
echo 'If `DFTforge Version XXX` is shown above, the install would completed without error. '
echo 'Try to run NiO example by typing the'
printf "${BLUE}./example_NiO_OpenMX.sh ${NC}\n"
echo '========================================================================='

# install DFTforge
# julia install.jl
