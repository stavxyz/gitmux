#!/usr/bin/env bash

# See ./repoman -h for more info.
#
# What does this script do?
#   This script creates a pull request on a destination repository
#   with content from a source repository and maintains all commit
#   history for all synced/forked files.
#
#   See ./repoman -h for more info.
#
# The pull request mechanism allows for discrete modifications
# to be made in both the source and destination repositories.
# The sync performed by this script is one-way which
# _should_ allow for additional changes in both your source
# repository and destination repository over time.
#
# This script can be run many times for the same source
# and destination. If you run this script for the first time
# on a Monday, and the source is updated on Wednesday, simply
# run this script again and it will generate a pull request
# with those updates which occurred in the interim.
#
# If -c is used, the destination repository will be created if it
# does not yet exists. Requires \`hub\` GitHub CLI.
#
# If -s is used, the pull request will be automatically submitted
# to your destination branch. Requires \`hub\` GitHub CLI.
#
#
# FAQ
#
# 1) Why doesnt this script push to my destination branch automatically?
#
#    That's dangerous. The best mechanism to view proposed changes is a
#    Pull Request so that is the mechanism used by this script. A unique
#    integration branch is created by this script in order to audit and
#    view proposed changes and the result of the filtered source repository.
#
# 2) This script always clones my source repo, can I just point to a local
#    directory containing a git repository as the source?
#
#    Yes. Feel free to use a local path for the source repository. That will
#    make the syncing much faster, but to minimize the chance that you miss
#    updates made in your source repository, supplying a URL is more consistent.
#
#  3) I want to manage the rebase myself in order to cherry-pick specific chanages.
#     Is that possible?
#
#     Sure is. Just supply -i to the script and you will be given a \`cd\`
#     command that will allow you to drop into the temporary workspace.
#     From there, you can complete the interactive rebase and push your
#     changes to the remote named 'destination'. The distinction between
#     remote names in the workspace is very imporant. To double-check, use
#     `git remote --verbose show` inside the repoman git workspace.

# Undefined variables are errors.
set -euoE pipefail

errcho ()
{
    printf "%s\n" "$@" 1>&2
}

errxit ()
{
  errcho "$@"
  # shellcheck disable=SC2119
  errcleanup
}

_pushd () {
    command pushd "$@" > /dev/null
}

_popd () {
    command popd > /dev/null
}

cleanup() {
  if [[ -d ${REPOMAN_TMP_WORKSPACE:-} ]]; then
    # shellcheck disable=SC2086
    if [ ${KEEP_TMP_WORKSPACE:-false} = true ]; then
      # implement -k (keep) and check for it
      errcho "You may navigate to ${REPOMAN_TMP_WORKSPACE} to complete the workflow manually (or, try again)."
    else
      errcho "Cleaning up."
      rm -rf "${REPOMAN_TMP_WORKSPACE}"
      errcho "Deleted repoman tmp workspace ${REPOMAN_TMP_WORKSPACE}"
      echo "🛀"
    fi
  fi
}

# shellcheck disable=SC2120
errcleanup() {
  errcho "⛔️ Repoman execution failed."
  if [ -n "${1:-}" ]; then
    errcho "⏩ Error at line ${1}."
  fi
  cleanup
  exit 1
}

intcleanup() {
  errcho "🍿 Script discontinued."
  cleanup
  exit 1
}

trap 'errcleanup ${LINENO}' ERR
trap 'intcleanup' SIGHUP SIGINT SIGTERM


# Reset in case getopts has been used previously in the shell.
OPTIND=1

# Set defaults
SOURCE_REPOSITORY="${SOURCE_REPOSITORY:-}"
SUBDIRECTORY_FILTER="${SUBDIRECTORY_FILTER:-}"
GIT_REF="${GIT_REF:-}"
DESTINATION_PATH="${DESTINATION_PATH:-}"
DESTINATION_REPOSITORY="${DESTINATION_REPOSITORY:-}"
DESTINATION_BRANCH="${DESTINATION_BRANCH:-master}"
SUBMIT_PR="${SUBMIT_PR:-false}"
INTERACTIVE_REBASE="${INTERACTIVE_REBASE:-false}"
CREATE_NEW_REPOSITORY="${CREATE_NEW_REPOSITORY:-false}"
KEEP_TMP_WORKSPACE="${KEEP_TMP_WORKSPACE:-false}"
# Don't default these rebase options *yet*
MERGE_STRATEGY_OPTION_FOR_REBASE="${MERGE_STRATEGY_OPTION_FOR_REBASE:-ours}"
REBASE_OPTIONS="${REBASE_OPTIONS:-}"
GITHUB_HOST="${GITHUB_HOST:-}"

source_repository="${SOURCE_REPOSITORY}"
subdirectory_filter="${SUBDIRECTORY_FILTER}"
git_ref="${GIT_REF}"
destination_path="${DESTINATION_PATH}"
destination_repository="${DESTINATION_REPOSITORY}"
destination_branch="${DESTINATION_BRANCH}"
_verbose=0

function stripslashes () {
  echo "$@" | sed 's:/*$::' | sed 's:^/*::'
}

function log () {
  if [[ $_verbose -eq 1 ]]; then
    printf "%s\n" "$@"
  fi
}

function show_help()
{
  # shellcheck disable=SC1111
  cat << EOF
  Usage: ${0##*/} [-r SOURCE_REPOSITORY] [-d SUBDIRECTORY_FILTER] [-g GITREF] [-t DESTINATION_REPOSITORY] [-p DESTINATION_PATH] [-b DESTINATION_BRANCH] [-X REBASE_STRATEGY_OPTION | -o REBASE_OPTIONS] [-i] [-s] [-c] [-k] [-v] [-h]
  “The life of a repo man is always intense.”
  -r <repository>              Path/url to the [remote] source repository. Required.
  -t <destination_repository>  Path/url to the [remote] destination repository. Required.
  -d <sub/directory>           Directory within source repository to extract. This value is supplied to \`git filter-branch\` as --subdirectory-filter. (default: '/' which is effectively a fork of the entire repo.) Supply a value for -d to extract only a piece/subdirectory of your source repository.
  -g <gitref>                  Git ref for the [remote] source repository. (default: null, which just uses the HEAD of the default branch, probably 'master', after cloning.) Can be any value valid for \`git checkout <ref>\` e.g. a branch, commit, or tag.
  -p <destination_path>        Destination path for the filtered repository content ( default: '/' which places the repository content into the root of the destination repository. e.g. to place source repository's /app directory content into the /lib directory of your destination repository, supply -p lib )
  -b <destination_branch>      Destination (a.k.a. base) branch in destination repository against which, changes will be rebased. Further, if [-s] is supplied, the resulting content will be submitted with this destination branch as the target (base) for the pull request. (Default: master)
  -o <rebase_options>          Options to supply to \`git rebase\`. If set and includes --interactive or -i, this script will drop you into the workspace to complete the workflow manually (Note: cannot use with -X)
  -X <option>                  Rebase strategy option, e.g. ours/patience. Defaults to 'theirs' (Note: cannot use with -o)
  -i                           Perform an interactive rebase. If you use this option you will need to push your resulting branch to the remote named 'destination' and submit a pull request manually.
  -s                           Submit a pull request to your destination. Requires \`hub\`. Only valid for non-local destination repositories. (default: off)
  -c                           Create the destination repository if it does not exist. Requires \`hub\`. (default: off)
  -k                           Keep the tmp git workspace around instead of cleaning it up (useful for debugging). (default: off)
  -v                           Verbose ( default: off )
  -h                           Print help / usage
EOF
}

# Rebase option related flags are mutually exclusive
_rebase_option_flags=''

while getopts "h?vr:d:g:t:p:b:o:X:sick" OPT; do
  case "$OPT" in
    r)  source_repository=$OPTARG
      ;;
    d)  subdirectory_filter="$(stripslashes "${OPTARG}")" # Is relative to the git repo, should not have leading slashes.
      ;;
    g)  git_ref=$OPTARG
      ;;
    t)  destination_repository=$OPTARG
      ;;
    p)  destination_path="$(stripslashes "${OPTARG}")" # Is relative to the git repo, should not have leading slashes.
      ;;
    b)  destination_branch=$OPTARG
      ;;
    X) [ -n "${_rebase_option_flags}" ] && show_help && errxit "" "error: -${OPT} cannot be used with -o" || _rebase_option_flags='set' MERGE_STRATEGY_OPTION_FOR_REBASE=$OPTARG
      ;;
    o) [ -n "${_rebase_option_flags}" ] && show_help && errxit "" "error: -${OPT} cannot be used with -X" || _rebase_option_flags='set' REBASE_OPTIONS=$OPTARG
      ;;
    s)  SUBMIT_PR=true
      ;;
    i)  INTERACTIVE_REBASE=true
      ;;
    c)  CREATE_NEW_REPOSITORY=true
      ;;
    k)  KEEP_TMP_WORKSPACE=true
      ;;
    h)  show_help && exit 0;;
    v)   _verbose=1;;
    \? ) errxit show_help && errxit "Unknown option: -${OPT} ( ${OPTARG} )";;
    ':') errxit "Missing option argument for -${OPT} ( ${OPTARG} )";;
    *  ) errxit "Unimplemented option: -${OPT} ( ${OPTARG} )";;
  esac
done

shift $((OPTIND-1))
[ "${1:-}" = "--" ] && shift

# Check required variables/arguments.
if [[ -z "$source_repository" ]]; then
  errxit "Source repository url or path is required"
elif [[ -z "$subdirectory_filter" ]]; then
  errcho "No subdirectory filter specified! Entire source repository will be extracted."
elif [[ -z "$destination_repository" ]]; then
  errxit "Destination repository url or path is required"
elif [[ -z "${GITHUB_HOST:-}" ]]; then
  errxit "GITHUB_HOST must be set."
fi

# Export this for `hub`.
export GITHUB_HOST=${GITHUB_HOST}

_append_to_pr_branch_name=''
if [[ -z "${REBASE_OPTIONS}" ]]; then
  # If REBASE_OPTIONS are not set by caller, *now* we set this default.
  if [[ -z "$MERGE_STRATEGY_OPTION_FOR_REBASE" ]]; then
          errxit "Merge strategy option (-X) is required. Value choices: ours, theirs, patience, diff-algorithm=[patience|minimal|histogram|myers]"
  fi
  REBASE_OPTIONS="--keep-empty --autostash --merge --strategy recursive --strategy-option ${MERGE_STRATEGY_OPTION_FOR_REBASE}"
  _append_to_pr_branch_name="${MERGE_STRATEGY_OPTION_FOR_REBASE}"
fi

if [ ${INTERACTIVE_REBASE} = true ]; then
  # This will result in rebase detection below and force a manual workflow for completion.
  REBASE_OPTIONS="${REBASE_OPTIONS} --interactive"
fi

# TODO(sam): - More regex to extract base domain (e.g. 'github.com') for building URLs for PR description.
#              - n/a for destinations repos which are local paths
#            - If uri is [colon]owner like github.com:org/project use git@
#            - If uri is [slash]owner like github.com/org/project use https
#            - If uri is local, dont parse the path for repo details

# This expression pulls out the owner and project name from a repository url
# as the second and fourth matched group, respectively. Referred to as \2 and \4
REPO_REGEX='s/(.*:\/\/|^git@)(.*)([\/:]{1})([a-zA-Z0-9_\.-]{1,})([\/]{1})([a-zA-Z0-9_\.-]{1,}$)'


if [[ -d "${source_repository}" ]]; then
  log "Source repository [ ${source_repository} ] is to a local path."
  source_repository=$(realpath -e "${source_repository}")
  log "Attempting to discover source repository remote url."
  _pushd "${source_repository}"
  # WARNING: WITHIN THIS BLOCK YOU ARE NOW IN A LOCAL REPOSITORY THAT SOMEONE PROBABLY CARES ABOUT.
  #          PERFORM EXCLUSIVELY READ-ONLY COMMANDS.
  _source_current_remote=$(git branch -vv --no-color | grep -e '^\*' | sed -E 's/.*\[(.*)\/[a-zA-Z0-9\ \:\,\_\.-]+\].*/\1/')
  source_url=$(git remote get-url "${_source_current_remote}")
  log "Discovered source url from local repo: ${source_url}"
  _popd
elif [[ ! "${source_repository}" =~ (:\/\/)|(^git@) ]] && [[ "${source_repository}" =~ \. ]]; then
  # For this condition, the source_repository must also contain a '.' otherwise it cannot possibly be a url
  # if protocol not specified, use git@
  # github and gitlab use 'git' user. address other use cases if/when they arise.
  source_repository="git@"${source_repository}
  source_url=${source_repository}
else
  source_url=${source_repository}
fi

# Remove trailing .git if present
source_url="${source_url/%\.git/''}"
source_domain=$(echo "${source_url}" | sed -E "${REPO_REGEX}"'/\2/')
source_project=$(echo "${source_url}" | sed -E "${REPO_REGEX}"'/\6/')
source_owner=$(echo "${source_url}" | sed -E "${REPO_REGEX}"'/\4/')
source_uri="${source_owner}/${source_project}"


if [[ -d "${destination_repository}" ]]; then
  log "Destination repository [ ${destination_repository} ] is to a local path."
  destination_repository=$(realpath -e "${destination_repository}")
  _pushd "${destination_repository}"
  _destination_current_remote=$(git branch -vv --no-color | grep -e '^\*' | sed -E 's/.*\[(.*)\/[a-zA-Z0-9\ \:\,\_\.-]+\].*/\1/')
  destination_url=$(git remote get-url "${_destination_current_remote}")
  log "Discovered destination url from local repo: ${destination_url}"
  _popd
elif [[ ! "${destination_repository}" =~ (:\/\/)|(^git@) ]] && [[ "${destination_repository}" =~ \. ]]; then
  # For this condition, the destination_repository must also contain a '.' otherwise it cannot possibly be a url
  # if protocol not specified, use git@
  # github and gitlab use 'git' user. address other use cases if/when they arise.
  destination_repository="git@"${destination_repository}
  destination_url=${destination_repository}
else
  destination_url=${destination_repository}
fi

# Remove trailing .git if present
destination_url="${destination_url/%\.git/''}"
destination_domain=$(echo "${destination_url}" | sed -E "${REPO_REGEX}"'/\2/')
destination_project=$(echo "${destination_url}" | sed -E "${REPO_REGEX}"'/\6/')
destination_owner=$(echo "${destination_url}" | sed -E "${REPO_REGEX}"'/\4/')
destination_uri="${destination_owner}/${destination_project}"

if [ "${source_domain}" != "${destination_domain}" ]; then
  # A safety check to prevent accidental open-sourcing of intellectual property :)
  errcho  "Source domain (${source_domain}) does not match destination domain (${destination_domain})."
  # shellcheck disable=SC2162
  read -p "Continue (y/N)?" _choice
  case "${_choice}" in
    y|Y ) echo "Ok." ;;
    * ) errxit "Goodbye.";;
  esac
fi

log "source_repository         ==> ${source_repository}"
log "source_url                ==> ${source_url}"
log "subdirectory_filter       ==> ${subdirectory_filter}"
log "git_ref                   ==> ${git_ref}"
log "destination_path          ==> ${destination_path}"
log "destination_repository    ==> ${destination_repository}"
log "destination_url           ==> ${destination_url}"
log "destination_branch        ==> ${destination_branch}"

log "SOURCE PROJECT OWNER ==> ${source_owner}"
log "SOURCE PROJECT NAME ==> ${source_project}"
log "SOURCE PROJECT URI ==> ${source_uri}"

log "DESTINATION PROJECT OWNER ==> ${destination_owner}"
log "DESTINATION PROJECT NAME ==> ${destination_project}"
log "DESTINATION PROJECT URI ==> ${destination_uri}"

REPOMAN_TMP_WORKSPACE=$(mktemp -t 'repoman-XXXXX' -d || errxit "Failed to create tmpdir.")
log "Working in tmpdir ${REPOMAN_TMP_WORKSPACE}"
_pushd "${REPOMAN_TMP_WORKSPACE}"
_GITDIR="tmp-${source_owner}_${source_project}"
git clone "${source_repository}" "${_GITDIR}"
_pushd "${_GITDIR}"
_WORKSPACE=$(pwd)

# The following is unnecessary when doing a full clone.
# Without a full clone, this procedure just doesnt work quite right.
#git fetch --update-shallow --shallow-since=1month --update-head-ok --progress origin master

# If a non-default ref is specified, fetch it explicitly and perform a checkout.
if [[ -n "$git_ref" ]]; then
  git fetch origin "${git_ref}" && git checkout "origin/${git_ref}"
fi

GIT_BRANCH=$(git rev-parse --abbrev-ref HEAD)
GIT_SHA=$(git rev-parse --short HEAD)


log "GIT BRANCH ==> ${GIT_BRANCH}"
log "GIT_SHA ==> ${GIT_SHA}"

# In plain(er) english:
#  - Let's take everything in the ci/ directory of the my-monorepo/
#    repository and place it into the / directory of the 'monorepo-ci' repository.
#  - While doing this, let's maintain the commit history.
#
# `git filter-branch` using --subdirectory-filter doesnt
# keep the actual directory specified, *only its contents*.
# So, lets create the directory structure we ultimately want
# *in advance* which is chef/.

# If a destination path is specified, do some tricks.
if [[ -n "$destination_path" ]] && ! [[ "${destination_path}" == '/' ]]; then
  log "Destination path ( ${destination_path} ) was specified. Do a tango."
  # ( Must use an intermediate temporary directory )
  mkdir -p __tmp__
  log "Temp dir created."

  if [ -n "${subdirectory_filter}" ]; then
    log "Moving files from ${subdirectory_filter} into tempdir."
    git mv "${subdirectory_filter}"/* __tmp__
    log "Creating destination path ${subdirectory_filter}/${destination_path}."
    mkdir -p "${subdirectory_filter}/${destination_path}"
    log "Moving content from tempdir into ${subdirectory_filter}/${destination_path}."
    git mv __tmp__/* "${subdirectory_filter}/${destination_path}/"
    log "Cleaning up tempdir."
    rm -rf __tmp__
    git add --update --refresh "${subdirectory_filter:-.}"
  else
    log "Moving repository files into tempdir."
    # First create a random file in case the directory is empty
    # For some odd reason. (Delete afterward)
    _rname="$(openssl rand -hex 8).txt"
    echo "Created by repoman. Serves two puposes, one of which is acting like a .gitkeep and the other has to do with shopt -s extglob. Delete me." > "${_rname}"
    git add --force --intent-to-add "${_rname}"
    shopt -s extglob
    # Move everything except __tmp__ into __tmp__
    # Everything except __tmp__ is -->  $(echo !(__tmp__))"
    # shellcheck disable=SC2046
    git mv $(echo !(__tmp__)) __tmp__
    shopt -u extglob
    mkdir -p "${destination_path}"
    git mv __tmp__/* "${destination_path}/"
    # Trying to ensure we get all the commit history...
    git add --update --refresh
    log "Cleaning up ${_rname}"
    git rm -f "${destination_path}/${_rname}"
    log "Cleaning up tempdir."
    rm -rf __tmp__
  fi
fi

git commit --allow-empty -m "Bring in changes from ${source_uri} ${GIT_BRANCH}"

# With "--subdirectory-filter=app"  ${destination_path} == lib 
# we get the contents of the app/
# directory, which is now a directory called "lib/" containing
# the contents of what was in the original app/ directory.

if [ -n "${subdirectory_filter}" ]; then
  _subdirectory_filter_options="--subdirectory-filter ${subdirectory_filter}"
else
  _subdirectory_filter_options=''
fi

log "subdirectory filter options --> ${_subdirectory_filter_options}"
# Might need --unshallow
#git filter-branch --prune-empty ${_subdirectory_filter_options}
git filter-branch ${_subdirectory_filter_options}
log "git filter-branch completed."
git status
log "Adding 'destination' remote --> ${destination_repository}"
git remote add destination "${destination_repository}"

DESTINATION_PR_BRANCH_NAME="update-from-${GIT_BRANCH}-${GIT_SHA}"
if [[ -n "${_append_to_pr_branch_name}" ]]; then
  DESTINATION_PR_BRANCH_NAME="${DESTINATION_PR_BRANCH_NAME}-rebase-strategy-${_append_to_pr_branch_name}"
fi
git checkout --no-track -b "${DESTINATION_PR_BRANCH_NAME}"
log "Status after filter-branch and checkout -b:"
log "$(git status)"
# Must exist in order to set-upstream-to.
# git branch --set-upstream-to=destination/${DESTINATION_PR_BRANCH_NAME}


# Fetch commits from the destination remote
log "Attempting to fetch remote 'destination' --> ${destination_repository}"
if ! _repo_existence="$(git fetch destination 2>&1)"; then
  log "Destination repository (${destination_repository}) doesn't exist. If -c supplied, create it"
  if [ ${CREATE_NEW_REPOSITORY} = true ] && [[ "${_repo_existence}" =~ "Repository not found" ]]; then

    ########## <HUB CREATE REPO> ################
    # `hub create` must be run from inside a git repository. (weird)
    log "hub is creating your new repository now!"
    NEW_REPOSITORY_DESCRIPTION="New repository from ${source_url} (${subdirectory_filter:-/})"
    # hub create [-poc] [-d DESCRIPTION] [-h HOMEPAGE] [[ORGANIZATION/]NAME]
    TMPHUBCREATEWORKDIR=$(mktemp -t 'repoman-hub-create-destination-XXXXXXXXXXXXX' -d || errxit "Failed to create tmpdir.")
    # Note: If you want to move the --orphan bits below, remove --bare from the next line.
    _pushd "${TMPHUBCREATEWORKDIR}" && git init --bare --quiet
    hub create -d "${NEW_REPOSITORY_DESCRIPTION}" "${destination_owner}/${destination_project}"
    _popd
    log "cleaning up hub-create workdir"
    rm -rf "${TMPHUBCREATEWORKDIR}"
    ########## </HUB CREATE REPO> ################

    log "Attempting (again) to fetch remote 'destination' --> ${destination_repository}"
    git fetch destination
    # Our brand new repo destination branch needs at least one commit (to be the base branch of a PR).
    # This will also help remind us where this repository came from.
    git status
    # A local 'master' branch probably already exists
    git checkout --orphan "repoman-dest-${destination_branch}"
    # Unstage everything (from ${DESTINATION_PR_BRANCH_NAME})
    git rm -r --cached .
    git status
    log "Creating empty commit for its own sake"
    git commit --message 'Hello: this repository was created by repoman.' --allow-empty
    # git push destination "${destination_branch}"
    git push destination "repoman-dest-${destination_branch}:master"
    # Now go back to the build branch.
    log "Going back to build branch --> ${DESTINATION_PR_BRANCH_NAME}"
    git checkout --force "${DESTINATION_PR_BRANCH_NAME}"
  else
    errxit "${_repo_existence}"
  fi
elif [ ${CREATE_NEW_REPOSITORY} = true ]; then
  # -c was supplied but the repository already existed.
  errxit "Destination repository ( ${destination_repository} ) already exists. -c is not needed."
fi


# Prefer changes made within the destination target branch
# (useful for syncing updates to a fork)
# rather than changes made in the original ${source_repository}

# Some notes on `git rebase`:
#  - When using --merge (-m) theirs/ours becomes intuitive
#    - Without -m, 'theirs' is what is currently local/checked out and 'ours'
#      is the ref/remote you are rebasing
#  - Strategy implies merge [strategy], so --strategy-option implies --merge

# Rebase against the destination target branch in order to ensure it is clean/mergeable
# TODO(sam): make this configurable so that
#  - users can perform the rebase themselves incase of "interesting" conflict resolution
#  - users can specify the merge strategy they prefer instead of hard-coding "theirs"
#  - in this context, 'theirs' is the destination repo. if this script is being run 
#    as a sync/update rather than an initial repo-ectomy, we _probably_ want 'theirs'.

perform_rebase () {
 log "Rebase options --> ' ${REBASE_OPTIONS} '"
 # shellcheck disable=SC2086
 if [[ $(echo " ${REBASE_OPTIONS} " | sed -E 's/.*(\ -i\ |\ --interactive\ ).*/INTERACTIVE/') == "INTERACTIVE" ]]; then
   echo "Interactive rebase detected."
   git rebase "${REBASE_OPTIONS}" "destination/${destination_branch}"
   log "Rebase completed successfully."
   echo "After rebasing, this might be useful: \`git push destination ${DESTINATION_PR_BRANCH_NAME}\`"
   echo "Navigate to the temp workspace at ${_WORKSPACE} to complete the workflow."
   echo "cd ${_WORKSPACE}"
 elif ! output="$(git rebase ${REBASE_OPTIONS} "destination/${destination_branch}" 2>&1)"; then
   # I only undestood this block long enough to write it.
   errcho "${output}"
   if [[ "${output}" =~ "invalid upstream" ]]; then
     errxit "Invalid upstream. Does '${destination_branch}' exist in '${destination_repository}'?"
   fi
   errcho "Rebase failed, trying to --continue..."
   n=1
   while [ $n -le 50 ] && ! output="$(git rebase --continue 2>&1)";do
     errcho "_______________________________________________"
     errcho "${output}"
     if [[ "${output}" =~ "needs merge" ]]; then
       echo "Renamed/unchanged files need merge, using \`git add --all\`"
       export GIT_EDITOR=true
       git add --all
     elif [[ "${output}" =~ "If you wish to commit it anyway" ]]; then
       echo "Committing anyway with \`git commit --allow-empty --no-edit\`"
       git commit --allow-empty --no-edit
     fi
     errcho "[${n}] Trying to --continue again..."
     (( n += 1 ))
     git rebase --continue && break
     errcho "_______________________________________________"
   done
   log "Pushing to branch ${DESTINATION_PR_BRANCH_NAME}"
   git push --progress --atomic --verbose --force-with-lease destination "${DESTINATION_PR_BRANCH_NAME}"
 else
   # rebase in elif condition succeeded
   log "Rebase completed successfully."
   log "Pushing to branch ${DESTINATION_PR_BRANCH_NAME}"
   git push --progress --atomic --verbose --force-with-lease destination "${DESTINATION_PR_BRANCH_NAME}"
 fi
}

perform_rebase

echo "Now create a pull request from ${DESTINATION_PR_BRANCH_NAME} into ${destination_branch}"

PR_DESCRIPTION=$(printf "%s\n" \
  "------------------------------" \
  "Sync from ${source_uri} \`${GIT_BRANCH}\` revision \`${GIT_SHA}\`" \
  "" \
  "# Hello" \
  "This is an automated pull request." \
  "" \
  "## Source repository details" \
  "Source repository: ${source_repository}" \
  "Source url: ${source_url}" \
  "Source git ref (if provided): \`${GIT_REF:-n/a}\`" \
  "Source git branch: ${GIT_BRANCH} (\`${GIT_SHA}\`)" \
  "Directory within source repository (if provided, else entire repository): \`${subdirectory_filter:-/}\`" \
  "Repository url: https://${GITHUB_HOST}/${source_owner}/${source_project}/tree/${GIT_SHA}/${SUBDIRECTORY_FILTER}" \
  "" \
  "## Destination repository details" \
  "Destination repository: ${destination_repository}" \
  "PR Branch at Destination (head): \`${DESTINATION_PR_BRANCH_NAME}\`" \
  "Destination branch (base): \`${DESTINATION_BRANCH}\`" \
  "PR Branch URL: https://${GITHUB_HOST}/${destination_owner}/${destination_project}/tree/${DESTINATION_PR_BRANCH_NAME}/${DESTINATION_PATH:-}" \
  "Destination url: ${destination_url}" \
  "Destination path (if applicable, or identical in structure to source): \`${DESTINATION_PATH:-n/a}\`" \
  "" \
  "------------------------------" \
)

if [ -x "$(command -v hub)" ] && [ ${SUBMIT_PR} = true ]; then
  # shellcheck disable=SC2016
  echo '`hub` is installed. Submitting PR'
  hub pull-request --message "${PR_DESCRIPTION}" \
    --labels sync \
    --browse \
    --no-edit --base "${destination_uri}:${destination_branch}" \
    --head "${destination_uri}:${DESTINATION_PR_BRANCH_NAME}"
else
  errcho "Please manually submit PR for branch ${DESTINATION_PR_BRANCH_NAME} to ${destination_repository}"
  errcho "auto-generated pull request description:" "" "${PR_DESCRIPTION}"
fi


_popd && _popd && cleanup
