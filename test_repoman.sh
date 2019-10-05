#!/usr/bin/env bash

# Undefined variables are errors.
set -euo pipefail

errcho ()
{
    printf "%s\n" "$@" 1>&2
}

errxit ()
{
  errcho "$@"
  cleanup
  exit 1
}

_pushd () {
    command pushd "$@" > /dev/null
}

_popd () {
    command popd > /dev/null
}

function log () {
  printf "%s\n" "$@"
}

# Constants / Arguments
# To override, user should export $GITHUB_HOST before running this test script.
export GITHUB_HOST=${GITHUB_HOST:-'github.com'}
export GITHUB_OWNER=${GITHUB_OWNER:-}

if [[ -z "${GITHUB_HOST:-}" ]]; then
  errxit "GITHUB_HOST must be set."
elif [[ -z "${GITHUB_OWNER:-}" ]]; then
  errxit "GITHUB_OWNER must be set."
fi


TMPTESTWORKDIR=$(mktemp -t 'repoman-test-XXXX' -d || errxit "Failed to create tmpdir.")
echo "Working in tmpdir ${TMPTESTWORKDIR}"
_pushd "${TMPTESTWORKDIR}"

repositoriesToDelete=()
cleanup() {
  errcho "Cleaning up!"
  rm -rf "${TMPTESTWORKDIR}"
  for r in "${repositoriesToDelete[@]}"; do
     echo "Deleting ${r}"
     hub delete -y "${r}"
  done
  echo "🛀"
}

errcleanup() {
  if [ -n "${1:-}" ]; then
    errcho "⏩ Error at line ${1}."
  fi
  errcho "⛔️ Tests failed."
  cleanup
  exit 1
}

trap 'errcleanup ${LINENO}' ERR

rands() {
  # Usage: rands <len>
  # defaults to 8 random characters
  openssl rand -hex "${1:-8}"
}

createRepository() {
  local _owner="${1}"
  local _project="${2}"
  local _visibility=${3:-'public'}
  if [[ -z "${_project}" ]] || [[ -z "${_owner}" ]]; then
    errxit "Repository owner and project are required. Usage: \`createRepository <ownerName> <repositoryName>\`"
  fi

  _hubcreateopts=''
  case ${_visibility} in
    public) : ;;
    private) _hubcreateopts="--private" ;;
    *) errxit "Not a valid value for visibility (choose one of public/private)";;
  esac

  ########## <HUB CREATE REPO> ################
  # `hub create` must be run from inside a git repository. (weird)
  log "hub is creating your new repository now!"
  # hub create [-poc] [-d DESCRIPTION] [-h HOMEPAGE] [[ORGANIZATION/]NAME]
  TMPHUBCREATEWORKDIR=$(mktemp -t 'repoman-tests-XXXX' -d || errxit "Failed to create tmpdir.")
  _pushd "${TMPHUBCREATEWORKDIR}" && git init --quiet
  NEW_REPOSITORY_DESCRIPTION="Test repository for repoman. If you find this lingering you may safely delete this repository."
  hub create ${_hubcreateopts:-} --remote-name hello -d "${NEW_REPOSITORY_DESCRIPTION}" "${_owner}/${_project}"
  git commit --message 'Hello: this repository was created by repoman.' --allow-empty
  git push hello "master:master"
  _popd
  log "cleaning up hub-create workdir"
  rm -rf "${TMPHUBCREATEWORKDIR}"
  ########## </HUB CREATE REPO> ################
}

#####################################
#### Setup source git repository.
#####################################
SOURCE_REPOSITORY_NAME="repoman_test_source_$(rands)"
mkdir -p "${SOURCE_REPOSITORY_NAME}"
_pushd "${SOURCE_REPOSITORY_NAME}" && SOURCE_REPOSITORY_PATH="$(pwd)"
git init
createRepository "${GITHUB_OWNER}" "${SOURCE_REPOSITORY_NAME}"
repositoriesToDelete+=("${GITHUB_OWNER}/${SOURCE_REPOSITORY_NAME}")
git remote add source_remote_name "git@${GITHUB_HOST}:${GITHUB_OWNER}/${SOURCE_REPOSITORY_NAME}.git"
git fetch source_remote_name
git checkout -b something-new --track source_remote_name/master
echo "Hello World" > "hello.txt"
git add "hello.txt"
git commit -m 'initial source repo commit: repoman test'
_sha=$(git rev-parse --short HEAD)
_popd

#####################################
#### Setup destination git repository.
#####################################
DESTINATION_REPOSITORY_NAME="repoman_test_destination_$(rands)"
mkdir -p "${DESTINATION_REPOSITORY_NAME}"
_pushd "${DESTINATION_REPOSITORY_NAME}"
DESTINATION_REPOSITORY_PATH="$(pwd)"
git init
createRepository "${GITHUB_OWNER}" "${DESTINATION_REPOSITORY_NAME}"
repositoriesToDelete+=("${GITHUB_OWNER}/${DESTINATION_REPOSITORY_NAME}")
git remote add destination_remote_name "git@${GITHUB_HOST}:${GITHUB_OWNER}/${DESTINATION_REPOSITORY_NAME}.git"
git fetch --update-head-ok destination_remote_name
# This actually creates a local 'master' tracking branch.
git checkout master
# Now back to current branch.
git checkout -b destination_current_branch --track destination_remote_name/master
git commit --allow-empty -m 'initial destination repo commit: repoman test'
_popd && _popd


echo
echo "*~*~*~*~*~*~*~*~*~*~*~*~*~*~*~*~*~*~*~*~*~*~*~*~*~*"
echo

##########################################
#### Test 1:
####    - defaults
####    - use existing github repository
####    - rebase strategy 'ours'
##########################################

./repoman.sh -v -r "${SOURCE_REPOSITORY_PATH}" -t "${DESTINATION_REPOSITORY_PATH}"
_pushd "${DESTINATION_REPOSITORY_PATH}"
git checkout update-from-something-new-${_sha}-rebase-strategy-ours
if output=$(cat hello.txt) && [ "${output}" == "Hello World" ];then
  echo "${output}" && echo "✅ Success"
  # reset
  git checkout destination_current_branch
else
  errcleanup
fi
_popd

echo
echo "*~*~*~*~*~*~*~*~*~*~*~*~*~*~*~*~*~*~*~*~*~*~*~*~*~*"
echo

##########################################
#### Test 2:
####    - With -p (place in subdir at destination)
####    - use existing github repository
####    - rebase strategy 'theirs'
##########################################
./repoman.sh -v -r "${SOURCE_REPOSITORY_PATH}" -t "${DESTINATION_REPOSITORY_PATH}" -p place_content_in_this_subdir -b master -X theirs
_pushd "${DESTINATION_REPOSITORY_PATH}"
git checkout update-from-something-new-${_sha}-rebase-strategy-theirs
if output=$(cat place_content_in_this_subdir/hello.txt) && [ "${output}" == "Hello World" ];then
  echo "${output}" && echo "✅ Success"
else
  errcleanup
fi
_popd

echo
echo "*~*~*~*~*~*~*~*~*~*~*~*~*~*~*~*~*~*~*~*~*~*~*~*~*~*"
echo

##########################################
#### Test 3:
####    - defaults with -c (create repo for me)
####    - repoman should create repository for me
####    - rebase strategy 'ours'
##########################################

NEW_REPO_URI="${GITHUB_OWNER}/repoman_test_destination_$(rands)"
repositoriesToDelete+=("${NEW_REPO_URI}")
NEW_REPO_NO_UPSTREAM_YET="git@${GITHUB_HOST}:${NEW_REPO_URI}.git"
./repoman.sh -v -c -r "${SOURCE_REPOSITORY_PATH}" -t "${NEW_REPO_NO_UPSTREAM_YET}"
_pushd "${DESTINATION_REPOSITORY_PATH}"
git checkout update-from-something-new-${_sha}-rebase-strategy-ours
if output=$(cat hello.txt) && [ "${output}" == "Hello World" ];then
  echo "${output}" && echo "✅ Success"
  # reset
  git checkout destination_current_branch
else
  errcleanup
fi
_popd


echo 'Tests completed successfully.' && cleanup
