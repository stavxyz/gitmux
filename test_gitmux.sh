#!/usr/bin/env bash

# Undefined variables are errors.
set -euoE pipefail

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

_tree_func () {
    if [ -x "$(command -v tree)" ]; then
      tree
      return $?
    else
      find . -print | sort | sed 's;[^/]*/;|---;g;s;---|; |;g'
      return $?
    fi
}



# Constants / Arguments
# To override, user should export $GH_HOST before running this test script.
export GH_HOST=${GH_HOST:-'github.com'}
export GITHUB_OWNER=${GITHUB_OWNER:-}

TMPTESTWORKDIR=$(mktemp -t 'gitmux-test-XXXXXX' -d || errxit "Failed to create tmpdir.")
echo "Working in tmpdir ${TMPTESTWORKDIR}"
_pushd "${TMPTESTWORKDIR}"

repositoriesToDelete=()
cleanup() {
  errcho "Cleaning up!"
  rm -rf "${TMPTESTWORKDIR}"
  for r in "${repositoriesToDelete[@]}"; do
     echo "Deleting ${r}"
     gh api --method DELETE repos/"${r}" 2>/dev/null || true
  done
  echo "🛀"
}

# shellcheck disable=SC2120
errcleanup() {
  if [ -n "${1:-}" ]; then
    _errmsg="⏩ Error at line ${1}"
    if [ -n "${2:-}" ]; then
      _errmsg="${_errmsg} in function '${2}'"
    fi
    errcho "${_errmsg}"
  fi
  errcho "⛔️ Tests failed."
  cleanup
  exit 1
}

trap 'errcleanup ${LINENO} ${FUNCNAME:-}' ERR

rands() {
  # Usage: rands - generate random lowercase string from $RANDOM
  # Note: tr '0-9' '[:lower:]' works on BSD but not GNU tr, so use explicit mapping
  echo $RANDOM$RANDOM | tr '0-9' 'a-j'
}

REPO_REGEX='s/(.*:\/\/|^git@)(.*)([\/:]{1})([a-zA-Z0-9_\.-]{1,})([\/]{1})([a-zA-Z0-9_\.-]{1,}$)'


createRepository() {
  local _owner="${1}"
  local _project="${2}"
  local _visibility=${3:-'public'}
  if [[ -z "${_project}" ]] || [[ -z "${_owner}" ]]; then
    errxit "Repository owner and project are required. Usage: \`createRepository <ownerName> <repositoryName>\`"
  fi

  _ghcreateopts=''
  case ${_visibility} in
    internal) _ghcreateopts="--internal" ;;
    public) _ghcreateopts="--public" ;;
    private) _ghcreateopts="--private" ;;
    *) errxit "Not a valid value for visibility (choose one of public/private)";;
  esac

  ########## <GH CREATE REPO> ################
  # `gh repo create` must be run from inside a git repository. (weird)
  # gh repo create [<name>] [flags]
  TMPGHCREATEWORKDIR=$(mktemp -t 'gitmux-tests-XXXXXX' -d || errxit "Failed to create tmpdir.")
  _pushd "${TMPGHCREATEWORKDIR}"
  NEW_REPOSITORY_DESCRIPTION="Test repository for gitmux. If you find this lingering you may safely delete this repository."
  log "gh-cli is creating your new repository now!"
  gh repo create "${_owner}/${_project}" ${_ghcreateopts:-} --license=unlicense --gitignore 'VVVV' --clone --description "${NEW_REPOSITORY_DESCRIPTION}"
  _pushd "${_project}"
  log "renaming origin to hello"
  git remote rename origin hello
  pwd

  #_new_url=$(git remote get-url hello | sed -E "${REPO_REGEX}""/https\:\/\/${GH_TOKEN}\@\2\/\4\/\6/")
  _new_url=$(git remote get-url hello | sed -E "${REPO_REGEX}""/https\:\/\/git\:${GH_TOKEN}\@\2\/\4\/\6/")
  log "new url: ${_new_url//${GH_TOKEN}/[REDACTED]}"
  git remote set-url hello "${_new_url}"

  git commit --message 'Hello: this repository was created by gitmux.' --allow-empty
  # Mask token in verbose output
  git remote --verbose show | sed "s/${GH_TOKEN}/[REDACTED]/g"
  # Rename branch to trunk (gitmux convention) and push
  git branch -m trunk
  log "pushing change to hello"
  git push hello "trunk:trunk"
  # Set trunk as default branch on GitHub
  gh repo edit "${_owner}/${_project}" --default-branch trunk
  pwd
  _popd && _popd
  pwd
  log "cleaning up gh-create-repo workdir --> ${TMPGHCREATEWORKDIR}"
  rm -rf "${TMPGHCREATEWORKDIR}"
  ########## </GH CREATE REPO> ################
}


#####################################
#### Setup source git repository.
#####################################
SOURCE_REPOSITORY_NAME="gitmux_test_source_$(rands)"
mkdir -p "${SOURCE_REPOSITORY_NAME}"
_pushd "${SOURCE_REPOSITORY_NAME}" && SOURCE_REPOSITORY_PATH="$(pwd)"
git init --initial-branch=trunk
createRepository "${GITHUB_OWNER}" "${SOURCE_REPOSITORY_NAME}"
repositoriesToDelete+=("${GITHUB_OWNER}/${SOURCE_REPOSITORY_NAME}")
git remote add source_remote_name "https://${GITHUB_OWNER}:${GH_TOKEN}@${GH_HOST}/${GITHUB_OWNER}/${SOURCE_REPOSITORY_NAME}.git"
log "Fetching in $(pwd)"
git fetch source_remote_name
git checkout -b something-new --track source_remote_name/trunk
echo "Hello World" > "hello.txt"
echo "## wat" > 'wat.md'
mkdir -p toto
echo 'TUTU' > 'toto/tutu.txt'
echo 'TATA' > 'toto/tata.txt'
git add "hello.txt"
git commit -m 'initial source repo commit: gitmux test'
git add "wat.md"
git commit -m 'and now wat?'
git add toto
git commit -m 'toto/ 🇫🇷'
_sha=$(git rev-parse --short HEAD)
_popd

#####################################
#### Setup destination git repository.
#####################################
DESTINATION_REPOSITORY_NAME="gitmux_test_destination_$(rands)"
mkdir -p "${DESTINATION_REPOSITORY_NAME}"
_pushd "${DESTINATION_REPOSITORY_NAME}"
DESTINATION_REPOSITORY_PATH="$(pwd)"
git init --initial-branch=trunk
createRepository "${GITHUB_OWNER}" "${DESTINATION_REPOSITORY_NAME}"
repositoriesToDelete+=("${GITHUB_OWNER}/${DESTINATION_REPOSITORY_NAME}")
git remote add destination_remote_name "https://${GITHUB_OWNER}:${GH_TOKEN}@${GH_HOST}/${GITHUB_OWNER}/${DESTINATION_REPOSITORY_NAME}.git"
git fetch --update-head-ok destination_remote_name
# This actually creates a local 'trunk' tracking branch.
git checkout trunk
# Now back to current branch.
git checkout -b destination_current_branch --track destination_remote_name/trunk
git commit --allow-empty -m 'initial destination repo commit: gitmux test'
_popd && _popd


echo
echo "*~*~*~*~*~*~*~*~*~*~*~*~*~*~*~*~*~*~*~*~*~*~*~*~*~*"
echo

##########################################
#### Test 1:
####    - defaults
####    - use existing github repository
####    - rebase strategy 'theirs' (default)
##########################################

test_defaults_with_existing_upstream_destination() {
  ./gitmux.sh -v -r "${SOURCE_REPOSITORY_PATH}" -t "${DESTINATION_REPOSITORY_PATH}"
  _pushd "${DESTINATION_REPOSITORY_PATH}"
  git checkout "update-from-something-new-${_sha}-rebase-strategy-theirs"
  local output=''
  if output=$(cat hello.txt) && [ "${output}" == "Hello World" ];then
    echo "${output}" && echo "✅ Success"
    # reset
    git checkout destination_current_branch
  else
    errcleanup
  fi
  _popd
}

echo
echo "*~*~*~*~*~*~*~*~*~*~*~*~*~*~*~*~*~*~*~*~*~*~*~*~*~*"
echo

##########################################
#### Test 2:
####    - With -p (place in subdir at destination)
####    - use existing github repository
####    - rebase strategy 'theirs'
##########################################

test_rebase_strategy_theirs_with_existing_upstream_destination() {
  ./gitmux.sh -v -r "${SOURCE_REPOSITORY_PATH}" -t "${DESTINATION_REPOSITORY_PATH}" -p place_content_in_this_subdir -b trunk -X theirs
  _pushd "${DESTINATION_REPOSITORY_PATH}"
  git checkout "update-from-something-new-${_sha}-rebase-strategy-theirs"
  local output=''
  if output=$(cat place_content_in_this_subdir/hello.txt) && [ "${output}" == "Hello World" ];then
    echo "${output}" && echo "✅ Success"
  else
    errcleanup
  fi
  _popd
}

echo
echo "*~*~*~*~*~*~*~*~*~*~*~*~*~*~*~*~*~*~*~*~*~*~*~*~*~*"
echo

##########################################
#### Test 3:
####    - defaults with -c (create repo for me)
####    - gitmux should create repository for me
####    - rebase strategy 'theirs' (default)
##########################################

test_defaults_destination_dne_yet() {
  NEW_REPO_PROJECT_NAME="gitmux_test_destination_$(rands)"
  repositoriesToDelete+=("${GITHUB_OWNER}/${NEW_REPO_PROJECT_NAME}")
  NEW_REPO_NO_UPSTREAM_YET="https://${GITHUB_OWNER}:${GH_TOKEN}@${GH_HOST}/${GITHUB_OWNER}/${NEW_REPO_PROJECT_NAME}.git"
  ./gitmux.sh -v -c -r "${SOURCE_REPOSITORY_PATH}" -t "${NEW_REPO_NO_UPSTREAM_YET}"
  log "Now cloning repository which should have been created on GitHub by gitmux."
  git clone "${NEW_REPO_NO_UPSTREAM_YET}"
  # This should create a directory called $NEW_REPO_PROJECT_NAME
  _pushd "${NEW_REPO_PROJECT_NAME}"
  git checkout "update-from-something-new-${_sha}-rebase-strategy-theirs"
  local output=''
  if output=$(cat hello.txt) && [ "${output}" == "Hello World" ];then
    echo "${output}" && echo "✅ Success"
    # reset
    git checkout destination_current_branch
  else
    errcleanup
  fi
  _popd
}

echo
echo "*~*~*~*~*~*~*~*~*~*~*~*~*~*~*~*~*~*~*~*~*~*~*~*~*~*"
echo

##########################################
#### Test 4:
####    - defaults with -c (create repo for me)
####    - gitmux should create repository for me
####    - rebase strategy 'theirs' (default)
####    - add github team infraconfig/infracore
##########################################

test_defaults_add_orgteam() {
  NEW_REPO_PROJECT_NAME="gitmux_test_destination_$(rands)"
  repositoriesToDelete+=("${GITHUB_OWNER}/${NEW_REPO_PROJECT_NAME}")
  NEW_REPO_NO_UPSTREAM_YET="https://${GITHUB_OWNER}:${GH_TOKEN}@${GH_HOST}/${GITHUB_OWNER}/${NEW_REPO_PROJECT_NAME}.git"
  ./gitmux.sh -v -c -r "${SOURCE_REPOSITORY_PATH}" -t "${NEW_REPO_NO_UPSTREAM_YET}" -z infraconfig/infracore
  log "Now cloning repository which should have been created on GitHub by gitmux."
  git clone "${NEW_REPO_NO_UPSTREAM_YET}"
  # This should create a directory called $NEW_REPO_PROJECT_NAME
  _pushd "${NEW_REPO_PROJECT_NAME}"
  # update-from-something-new-23eae47-rebase-strategy-theirs
  git checkout "update-from-something-new-${_sha}-rebase-strategy-theirs"
  local output=''
  if output=$(cat hello.txt) && [ "${output}" == "Hello World" ];then
    echo "${output}" && echo "✅ Success"
    # reset
    git checkout destination_current_branch
  else
    errcleanup
  fi
  _popd
}

echo
echo "*~*~*~*~*~*~*~*~*~*~*~*~*~*~*~*~*~*~*~*~*~*~*~*~*~*"
echo

##########################################
#### Test 5:
####    - defaults with -c (create repo for me)
####    - gitmux should create repository for me
####    - rebase strategy 'theirs' (default)
####    - selective file migration
##########################################

test_defaults_destination_dne_yet_only_wat() {
  NEW_REPO_PROJECT_NAME="gitmux_test_destination_$(rands)"
  repositoriesToDelete+=("${GITHUB_OWNER}/${NEW_REPO_PROJECT_NAME}")
  NEW_REPO_NO_UPSTREAM_YET="https://${GITHUB_OWNER}:${GH_TOKEN}@${GH_HOST}/${GITHUB_OWNER}/${NEW_REPO_PROJECT_NAME}.git"
  ./gitmux.sh -v -c -r "${SOURCE_REPOSITORY_PATH}" -t "${NEW_REPO_NO_UPSTREAM_YET}" -l "wat.md"
  log "Now cloning repository which should have been created on GitHub by gitmux."
  git clone "${NEW_REPO_NO_UPSTREAM_YET}"
  # This should create a directory called $NEW_REPO_PROJECT_NAME
  _pushd "${NEW_REPO_PROJECT_NAME}"
  git checkout "update-from-something-new-${_sha}-rebase-strategy-theirs"
  if [ -f hello.txt ]; then
    errcho "File hello.txt should not be here"
    errcleanup
  fi
  local output=''
  pwd
  if output=$(cat wat.md) && [ "${output}" == "## wat" ];then
    echo "${output}" && echo "✅ Success"
    # reset
    git branch
    git checkout destination_current_branch
  else
    errcleanup
  fi
  _popd
}

test_defaults_destination_dne_yet_only_toto() {
  NEW_REPO_PROJECT_NAME="gitmux_test_destination_$(rands)"
  repositoriesToDelete+=("${GITHUB_OWNER}/${NEW_REPO_PROJECT_NAME}")
  NEW_REPO_NO_UPSTREAM_YET="https://${GITHUB_OWNER}:${GH_TOKEN}@${GH_HOST}/${GITHUB_OWNER}/${NEW_REPO_PROJECT_NAME}.git"
  ./gitmux.sh -v -c -r "${SOURCE_REPOSITORY_PATH}" -t "${NEW_REPO_NO_UPSTREAM_YET}" -l "toto"
  log "Now cloning repository which should have been created on GitHub by gitmux."
  git clone "${NEW_REPO_NO_UPSTREAM_YET}"
  # This should create a directory called $NEW_REPO_PROJECT_NAME
  _pushd "${NEW_REPO_PROJECT_NAME}"
  git checkout "update-from-something-new-${_sha}-rebase-strategy-theirs"
  if [ -f hello.txt ]; then
    errcho "File hello.txt should not be here"
    errcleanup
  fi
  if [ -f wat.md ]; then
    errcho "File wat.md should not be here"
    errcleanup
  fi
  local output=''
  pwd
  if output=$(cat toto/tutu.txt) && \
      [ "${output}" == "TUTU" ] && \
      output=$(cat toto/tata.txt) && \
      [ "${output}" == "TATA" ] && \
      _tree=$(_tree_func); then
    echo "${_tree}" && echo "✅ Success"
    # reset
    git branch
    git checkout destination_current_branch
  else
    errcleanup
  fi
  _popd
}


##########################################
#### Test 6:
####    - Multi-path migration with -m flag
####    - Two directories mapped to different destinations
####    - Single PR branch created
##########################################

test_multipath_migration() {
  # Create a new source repo specifically for multi-path testing
  MULTIPATH_SOURCE_NAME="gitmux_test_multipath_source_$(rands)"
  mkdir -p "${MULTIPATH_SOURCE_NAME}"
  _pushd "${MULTIPATH_SOURCE_NAME}"
  MULTIPATH_SOURCE_PATH="$(pwd)"
  git init --initial-branch=trunk
  createRepository "${GITHUB_OWNER}" "${MULTIPATH_SOURCE_NAME}"
  repositoriesToDelete+=("${GITHUB_OWNER}/${MULTIPATH_SOURCE_NAME}")
  git remote add multipath_source_remote "https://${GITHUB_OWNER}:${GH_TOKEN}@${GH_HOST}/${GITHUB_OWNER}/${MULTIPATH_SOURCE_NAME}.git"
  git fetch multipath_source_remote
  git checkout -b multipath-test --track multipath_source_remote/trunk

  # Create src/ directory with some files
  mkdir -p src
  echo 'console.log("hello");' > 'src/index.js'
  echo 'module.exports = {};' > 'src/utils.js'
  git add src
  git commit -m 'feat: add source files'

  # Create tests/ directory with some files
  mkdir -p tests
  echo 'test("works", () => {});' > 'tests/index.test.js'
  echo 'test("utils", () => {});' > 'tests/utils.test.js'
  git add tests
  git commit -m 'test: add test files'

  git push multipath_source_remote multipath-test
  _multipath_sha=$(git rev-parse --short HEAD)
  _popd

  # Create destination repo for multi-path test
  MULTIPATH_DEST_NAME="gitmux_test_multipath_dest_$(rands)"
  mkdir -p "${MULTIPATH_DEST_NAME}"
  _pushd "${MULTIPATH_DEST_NAME}"
  MULTIPATH_DEST_PATH="$(pwd)"
  git init --initial-branch=trunk
  createRepository "${GITHUB_OWNER}" "${MULTIPATH_DEST_NAME}"
  repositoriesToDelete+=("${GITHUB_OWNER}/${MULTIPATH_DEST_NAME}")
  git remote add multipath_dest_remote "https://${GITHUB_OWNER}:${GH_TOKEN}@${GH_HOST}/${GITHUB_OWNER}/${MULTIPATH_DEST_NAME}.git"
  git fetch --update-head-ok multipath_dest_remote
  git checkout trunk
  git checkout -b multipath_dest_branch --track multipath_dest_remote/trunk
  git commit --allow-empty -m 'initial destination repo commit: multipath test'
  _popd

  echo
  echo "*~*~*~*~* MULTI-PATH MIGRATION TEST *~*~*~*~*"
  echo

  # Run gitmux with multiple -m flags
  ./gitmux.sh -v \
    -r "${MULTIPATH_SOURCE_PATH}" \
    -t "${MULTIPATH_DEST_PATH}" \
    -g multipath-test \
    -m "src:packages/app/src" \
    -m "tests:packages/app/tests"

  # Verify both paths exist in destination
  _pushd "${MULTIPATH_DEST_PATH}"
  git checkout "update-from-multipath-test-${_multipath_sha}-rebase-strategy-theirs"

  # Check src files are in packages/app/src/
  local src_output=''
  if src_output=$(cat packages/app/src/index.js) && [[ "${src_output}" == 'console.log("hello");' ]]; then
    echo "✅ src/index.js migrated correctly to packages/app/src/"
  else
    errcho "❌ src/index.js not found or incorrect content"
    errcleanup
  fi

  # Check tests files are in packages/app/tests/
  local test_output=''
  if test_output=$(cat packages/app/tests/index.test.js) && [[ "${test_output}" == 'test("works", () => {});' ]]; then
    echo "✅ tests/index.test.js migrated correctly to packages/app/tests/"
  else
    errcho "❌ tests/index.test.js not found or incorrect content"
    errcleanup
  fi

  echo "✅ Multi-path migration test passed!"
  git checkout multipath_dest_branch
  _popd
}

run_test_cases() {
  test_defaults_with_existing_upstream_destination
  test_rebase_strategy_theirs_with_existing_upstream_destination
  test_defaults_destination_dne_yet
  #test_defaults_add_orgteam
  test_defaults_destination_dne_yet_only_wat
  test_defaults_destination_dne_yet_only_toto
  test_multipath_migration
}


if run_test_cases; then
  echo '✨✨✨✨✨✨✨✨✨✨✨✨✨✨✨✨✨✨✨✨'
  echo '✨  All tests completed successfully. ✨'
  echo '✨✨✨✨✨✨✨✨✨✨✨✨✨✨✨✨✨✨✨✨'
  cleanup
else
  errxit "Tests failed."
fi
