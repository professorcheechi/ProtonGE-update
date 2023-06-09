#!/bin/bash

# expanded from instructions here
# https://github.com/GloriousEggroll/proton-ge-custom

######################################################################################## vars
# noGEproton    - there are no proton files found, whether no working dir or files within
# latest_GE     - what is the latest protonGE version we have?
# latest        - do we have the latest version?
# shaOK         - the checksum passed
# checksumtries - loop counter
# untarsuccess  - verify the unzip is good or exit
# exit_state    - useful error messages

me=$(whoami)

myhome=/home/$me

mydl=$myhome/Downloads

comptoolsdir=$myhome/.steam/root/compatibilitytools.d

protonGE_url=https://api.github.com/repos/GloriousEggroll/proton-ge-custom/releases/latest

######################################################################################## functions

usage()
{
  printf "\n\n This script is an expansion and automation of the instructions provided at the Proton GE github page \
          \n\n https://github.com/GloriousEggroll/proton-ge-custom \
          \n\n The purpose is to automate the installation steps and if needed help diagnose install isssues. \
          \n It needs no flags or arguments, the only flag is -h to display this help message \n\n"
}

#version_check_only()
#{
#  if [ -d "$comptoolsdir" ]; then
#    # check the existing installed version
#    current_GE=$(ls -lrt $comptoolsdir | grep GE-Proton | tail -1 | awk '{print $9}')
#    printf "\n Installed version is $current_GE \n"
#  else 
#    printf "\n No Proton GE installed \n\n"
#  fi
#  # check current version available
#  latest_GE=$(curl -s $protonGE_url -- list-only | grep "tag_name" | awk '{print $NF}' | tr -d '",')
#  printf "\n Latest version is $latest_GE \n\n"
#}

exit_clean()
{ # Assumption: any step that fails will provide some output along the way to assist with troubleshooting

  if [ -n "$cwd" ]; then
    if [ -z "$(pwd | grep "$cwd")" ]; then
      cd $cwd
    fi
  fi

  case $exit_state in
    2) exit_message="Downloaded file checksum OK but failed to unzip to local Steam. Please troubleshoot your system before trying again" ;;
    3) exit_message="No newer ProtonGE to download" ;;
    4) exit_message="Please check file permissions" ;;
    5) exit_message="3 failed attempts to download & chesksum. Please troubleshoot your system & connection before trying again" ;;
    6) exit_message="Unable to reach github or bandwitdh restriction attempts fetching latest version info. Please troubleshoot connection or try again later" ;;
  esac

  printf "\n Unable to continue, $exit_message \n\n"
  exit $exit_state
}

local_files_check()
{
  # make working directory if needed
  if ! [ -d $mydl/protonGE ]; then
    noGEproton=1
    if [[ "$version_check_only" -ne 1 ]]; then
      mkdir $mydl/protonGE
    else
      exit_state=7 &&  exit_clean $@
    fi
  fi

  # make steam directory if it does not exist
  if ! [ -d $comptoolsdir ]; then
    noGEproton=1
    if [[ "$version_check_only" -ne 1 ]]; then 
      mkdir -p ~/.steam/root/compatibilitytools.d
    else
      exit_state=7 &&  exit_clean $@
    fi
  fi

  # make sure we can write to both dir
  if [[ "$noGEproton" -ne 1 ]]; then
    ls -lrt $mydl | grep -w protonGE | grep -q "drwx" || exit_state=4
    ls -lrt ~/.steam/root/ | grep -w compatibilitytools.d | grep -q "drwx" || exit_state=4
  fi

  # verbose output whether checking or installing files
  # exit if only checking
  printf "\n $mydl/protonGE \n\n"
  dl_files=$(ls -lrt $mydl/protonGE | grep -w "protonGE ")
  echo "$dl_files" 

  printf "\n $comptoolsdir \n\n"
  installed_files=$(ls -lrt $comptoolsdir)
  echo "$installed_files"

  if [[ "$version_check_only" -ne 1 ]]; then
    if [ -n "$exit_state" ]; then
      exit_clean $@
    else
      cwd=$(pwd)
      cd $mydl/protonGE
    fi
  else
    exit 1
  fi
}


remote_files_check()
{ # assumption: whatever version is listed on github as current, even if older.
  # For instance if a version is rolled back there is probably a good reason. 
  # should download & install the current version available if not already present locally.

  if [[ "$noGEproton" -ne 1 ]]; then
    # check the existing installed version
    current_GE=$(ls -lN $comptoolsdir | grep GE-Proton | tail -1 | awk '{print $9}')
    printf "\n Installed version is $current_GE \n"
  fi

  # check if newer/different version
  latest_GE=$(curl -s $protonGE_url -- list-only | grep "tag_name" | awk '{print $NF}' | tr -d '",')

  if [ -z "$(echo "$latest_GE" | grep -i proton)" ]; then
    exit_state=6 && exit_clean $@
  fi

  printf "\n Latest version is $latest_GE \n\n"

  if [[ -n "$(echo "$current_GE" | grep "$latest_GE")" ]]; then
    latest=1
  fi
  # note: there is not a check if the tar/sha files exist in the download dir
  # and whether they are the current version. if the script was run prior and failed
  # these might be the cause, should move forward & download new ones just in case
  # this script writes no log or other tracking, only interacting with files to ls, download, checksum & untar
}


get_new_protonGE()
{
  # download  tarball
  curl -sLOJ $(curl -s $protonGE_url | grep browser_download_url | cut -d\" -f4 | grep -E .tar.gz)

  # download checksum
  curl -sLOJ $(curl -s $protonGE_url | grep browser_download_url | cut -d\" -f4 | grep -E .sha512sum)
}

check_tarball()
{
  # check tarball with checksum
  sha512sum -c $latest_GE.sha512sum | grep -q "OK" && shaOK=1

  checksumtries=$(( $checksumtries + 1 ))
}

install_protonGE()
{
  # extract proton tarball to steam directory
  printf " unzipping $latest_GE to $comptoolsdir ..."
  tar -xf $latest_GE.tar.gz -C "$comptoolsdir" && untarsuccess=1

  if [[ "$untarsuccess" -eq 1 ]]; then
    proton_installed=$(ls -l "$comptoolsdir/$latest_GE/proton")
    printf "OK\n"

    if [  -n "$(echo "$proton_installed" | grep $latest_GE)" ]; then
      printf "\n $latest_GE successfully installed. Please restart Steam \n\n"
    else
      exit_state=2 && exit_clean $@
    fi
  else
    printf "Failure\n"
    exit_state=2 && exit_clean $@
  fi
}

######################################################################################## main

# todo -v for what version is installed
while getopts :hv flag; do
  case $flag in
    h) usage && exit 1 ;;
    v) version_check_only=1 ;;
  esac
done

local_files_check $@

remote_files_check $@


if [[ "$latest" -eq 1 ]]; then
  exit_state=3 && exit_clean $@
fi



checksumtries=0
while (( "$checksumtries" < 3 )) ; do

  get_new_protonGE $@

  check_tarball $@

  if [ "$shaOK" -eq 1 ]; then
    break
  fi
done

if [[ "$checksumtries" -eq 3 ]] ||  [[ "$shaOK" -ne 1 ]]; then
  exit_state=5 && exit_clean $@
else
  install_protonGE $@
fi

######################################################################################## end


