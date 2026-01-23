#!/usr/bin/env bash

# See ./gitmux -h for more info.
#
# What does this script do?
#   This script creates a pull request on a destination repository
#   with content from a source repository and maintains all commit
#   history for all synced/forked files.
#
#   See ./gitmux -h for more info.
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
# does not yet exists. Requires \`gh\` GitHub CLI.
#
# https://cli.github.com
#
# If -s is used, the pull request will be automatically submitted
# to your destination branch. Requires \`gh\` GitHub CLI.
#
# https://cli.github.com
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
#     `git remote --verbose show` inside the gitmux git workspace.

# Undefined variables are errors.
set -euoE pipefail

# Enable extended globbing for patterns like !(pattern)
# Must be enabled at parse time for extglob patterns to work
shopt -s extglob

# Print message to stderr.
# Arguments:
#   $@ - Message(s) to print
errcho ()
{
    printf "%s\n" "$@" 1>&2
}

# Print error message and exit with cleanup.
# Arguments:
#   $@ - Error message(s) to print
errxit ()
{
  errcho "$@"
  # shellcheck disable=SC2119
  errcleanup
}

# Change to directory without printing output.
# Arguments:
#   $@ - Arguments to pass to pushd
_pushd () {
    command pushd "$@" > /dev/null
}

# Return to previous directory without printing output.
_popd () {
    command popd > /dev/null
}

# Get absolute path of file/directory (cross-platform).
# Arguments:
#   $@ - Path(s) to resolve
# Returns:
#   Absolute path to stdout
_realpath () {
    if _cmd_exists realpath; then
      realpath "$@"
      return $?
    else
      readlink -f "$@"
      return $?
    fi
}

# Check if a command exists on the system.
# Arguments:
#   $* - Command name to check
# Returns:
#   0 if command exists, 1 otherwise
_cmd_exists () {
  if ! type "$*" &> /dev/null; then
    errcho "$* command not installed"
    return 1
  fi
}

# Clean up temporary workspace.
# Removes the temp directory unless KEEP_TMP_WORKSPACE is true.
cleanup() {
  if [[ -d ${gitmux_TMP_WORKSPACE:-} ]]; then
    # shellcheck disable=SC2086
    if [ ${KEEP_TMP_WORKSPACE:-false} = true ]; then
      # implement -k (keep) and check for it
      errcho "You may navigate to ${gitmux_TMP_WORKSPACE} to complete the workflow manually (or, try again)."
    else
      errcho "Cleaning up."
      rm -rf "${gitmux_TMP_WORKSPACE}"
      errcho "Deleted gitmux tmp workspace ${gitmux_TMP_WORKSPACE}"
      echo "🛀"
    fi
  fi
}

# Handle error conditions: print error message, clean up, and exit.
# Arguments:
#   $1 - (optional) Line number where error occurred
# shellcheck disable=SC2120
errcleanup() {
  errcho "⛔️ gitmux execution failed."
  if [ -n "${1:-}" ]; then
    errcho "⏩ Error at line ${1}."
  fi
  cleanup
  exit 1
}

# Handle interrupt signals (SIGHUP, SIGINT, SIGTERM).
# Cleans up and exits gracefully.
intcleanup() {
  errcho "🍿 Script discontinued."
  cleanup
  exit 1
}

trap 'errcleanup ${LINENO}' ERR
trap 'intcleanup' SIGHUP SIGINT SIGTERM

#
# Early validation: check for required commands
#
if ! command -v git &> /dev/null; then
  errcho "Error: git is required but not installed."
  exit 1
fi

if ! command -v jq &> /dev/null; then
  errcho "Error: jq is required but not installed."
  exit 1
fi

# Convert long options to short options for getopts compatibility
for arg in "$@"; do
  shift
  case "$arg" in
    '--author-name')     set -- "$@" '-N' ;;
    '--author-email')    set -- "$@" '-E' ;;
    '--committer-name')  set -- "$@" '-n' ;;
    '--committer-email') set -- "$@" '-e' ;;
    '--coauthor-action') set -- "$@" '-C' ;;
    '--dry-run')         set -- "$@" '-D' ;;
    *)                   set -- "$@" "$arg" ;;
  esac
done

# Reset in case getopts has been used previously in the shell.
OPTIND=1

# Set defaults
SOURCE_REPOSITORY="${SOURCE_REPOSITORY:-}"
SUBDIRECTORY_FILTER="${SUBDIRECTORY_FILTER:-}"
SOURCE_GIT_REF="${SOURCE_GIT_REF:-}"
DESTINATION_PATH="${DESTINATION_PATH:-}"
DESTINATION_REPOSITORY="${DESTINATION_REPOSITORY:-}"
DESTINATION_BRANCH="${DESTINATION_BRANCH:-trunk}"
SUBMIT_PR="${SUBMIT_PR:-false}"
REV_LIST_FILES="${REV_LIST_FILES:-}"
INTERACTIVE_REBASE="${INTERACTIVE_REBASE:-false}"
CREATE_NEW_REPOSITORY="${CREATE_NEW_REPOSITORY:-false}"
KEEP_TMP_WORKSPACE="${KEEP_TMP_WORKSPACE:-false}"
DRY_RUN="${DRY_RUN:-false}"

# Don't default these rebase options *yet*
MERGE_STRATEGY_OPTION_FOR_REBASE="${MERGE_STRATEGY_OPTION_FOR_REBASE:-ours}"
REBASE_OPTIONS="${REBASE_OPTIONS:-}"
GH_HOST="${GH_HOST:-github.com}"
GITHUB_TEAMS=()

# Author/committer override options (can be set via environment)
GITMUX_AUTHOR_NAME="${GITMUX_AUTHOR_NAME:-}"
GITMUX_AUTHOR_EMAIL="${GITMUX_AUTHOR_EMAIL:-}"
GITMUX_COMMITTER_NAME="${GITMUX_COMMITTER_NAME:-}"
GITMUX_COMMITTER_EMAIL="${GITMUX_COMMITTER_EMAIL:-}"
GITMUX_COAUTHOR_ACTION="${GITMUX_COAUTHOR_ACTION:-}"

source_repository="${SOURCE_REPOSITORY}"
subdirectory_filter="${SUBDIRECTORY_FILTER}"
source_git_ref="${SOURCE_GIT_REF}"
destination_path="${DESTINATION_PATH}"
destination_repository="${DESTINATION_REPOSITORY}"
destination_branch="${DESTINATION_BRANCH}"
rev_list_files="${REV_LIST_FILES}"
_verbose=0

# Remove leading and trailing slashes from a path.
# Arguments:
#   $@ - Path string to process
# Returns:
#   Cleaned path to stdout
function stripslashes () {
  echo "$@" | sed 's:/*$::' | sed 's:^/*::'
}

# Print log message if verbose mode is enabled.
# Arguments:
#   $@ - Message(s) to print
function log () {
  if [[ $_verbose -eq 1 ]]; then
    printf "%s\n" "$@"
  fi
}

# Display usage information and available options.
function show_help()
{
  # shellcheck disable=SC1111
  cat << EOF
  Usage: ${0##*/} [-r SOURCE_REPOSITORY] [-d SUBDIRECTORY_FILTER] [-g GITREF] [-t DESTINATION_REPOSITORY] [-p DESTINATION_PATH] [-b DESTINATION_BRANCH] [-X REBASE_STRATEGY_OPTION | -o REBASE_OPTIONS] [-z GITHUB_TEAM -z ...] [--author-name NAME --author-email EMAIL] [--committer-name NAME --committer-email EMAIL] [--coauthor-action claude|all|keep] [-i] [-s] [-c] [-k] [-v] [-h]
  “The life of a repo man is always intense.”
  -r <repository>              Path/url to the [remote] source repository. Required.
  -t <destination_repository>  Path/url to the [remote] destination repository. Required.
  -d <sub/directory>           Directory within source repository to extract. This value is supplied to \`git filter-branch\` as --subdirectory-filter. (default: '/' which is effectively a fork of the entire repo.) Supply a value for -d to extract only a piece/subdirectory of your source repository.
  -g <gitref>                  Git ref for the [remote] source repository. (default: null, which just uses the HEAD of the default branch, probably 'trunk (or master)', after cloning.) Can be any value valid for \`git checkout <ref>\` e.g. a branch, commit, or tag.
  -p <destination_path>        Destination path for the filtered repository content ( default: '/' which places the repository content into the root of the destination repository. e.g. to place source repository's /app directory content into the /lib directory of your destination repository, supply -p lib )
  -b <destination_branch>      Destination (a.k.a. base) branch in destination repository against which, changes will be rebased. Further, if [-s] is supplied, the resulting content will be submitted with this destination branch as the target (base) for the pull request. (Default: trunk)
  -l <rev-list options>        Options passed to git rev-list during \`git filter-branch\`. Can be used to specify individual files to be brought into the [new] repository. e.g. -l '--all -- file1.txt file2.txt' Note: file paths with spaces are not supported. For more info see git's documentation for git filter-branch under the parameters for <rev-list options>…
  -o <rebase_options>          Options to supply to \`git rebase\`. If set and includes --interactive or -i, this script will drop you into the workspace to complete the workflow manually (Note: cannot use with -X)
  -X <option>                  Rebase strategy option, e.g. ours/patience. Defaults to 'ours' (Note: cannot use with -o)
  -i                           Perform an interactive rebase. If you use this option you will need to push your resulting branch to the remote named 'destination' and submit a pull request manually.
  -s                           Submit a pull request to your destination. Requires \`gh\`. Only valid for non-local destination repositories. (default: off)
  -c                           Create the destination repository if it does not exist. Requires \`gh\`. (default: off)
  -z                           Add this team to your destination repository. Use <org>/<team> notation e.g. engineering-org/firmware-team May be specified multiple times. Requires \`gh\`. Only valid for non-local destination repositories.
  -N, --author-name <name>     Override author name for all transferred commits. Requires --author-email. Can also be set via GITMUX_AUTHOR_NAME environment variable.
  -E, --author-email <email>   Override author email for all transferred commits. Requires --author-name. Can also be set via GITMUX_AUTHOR_EMAIL environment variable.
  -n, --committer-name <name>  Override committer name for all transferred commits. Requires --committer-email. Can also be set via GITMUX_COMMITTER_NAME environment variable.
  -e, --committer-email <email> Override committer email for all transferred commits. Requires --committer-name. Can also be set via GITMUX_COMMITTER_EMAIL environment variable.
  -C, --coauthor-action <action> Action for Co-authored-by trailers and Claude attribution in commit messages:
                               'claude' - Remove only Claude/Anthropic attribution (Co-authored-by and Generated-with lines)
                               'all' - Remove ALL Co-authored-by trailers and Generated-with lines
                               'keep' - Preserve all trailers unchanged
                               (default: 'claude' when author/committer options are used, otherwise 'keep')
                               Can also be set via GITMUX_COAUTHOR_ACTION environment variable.
  -D, --dry-run                Preview what changes would be made without actually modifying anything.
                               Shows: author/committer changes, coauthor-action effects, and affected commits.
                               Useful for verifying configuration before running. (default: off)
  -k                           Keep the tmp git workspace around instead of cleaning it up (useful for debugging). (default: off)
  -v                           Verbose ( default: off )
  -h                           Print help / usage
EOF
}

# Rebase option related flags are mutually exclusive
_rebase_option_flags=''

while getopts "h?vr:d:g:t:p:z:b:l:o:X:sickDN:E:n:e:C:" OPT; do
  case "$OPT" in
    r)  source_repository=$OPTARG
      ;;
    d)  subdirectory_filter="$(stripslashes "${OPTARG}")" # Is relative to the git repo, should not have leading slashes.
      ;;
    l)  rev_list_files=$OPTARG
      ;;
    g)  source_git_ref=$OPTARG
      ;;
    t)  destination_repository=$OPTARG
      ;;
    p)  destination_path="$(stripslashes "${OPTARG}")" # Is relative to the git repo, should not have leading slashes.
      ;;
    b)  destination_branch=$OPTARG
      ;;
    X) [ -n "${_rebase_option_flags}" ] && show_help && errxit "" "error: -${OPT} cannot be used with -o" || _rebase_option_flags='set' MERGE_STRATEGY_OPTION_FOR_REBASE=$OPTARG
      ;;
    z) ! _cmd_exists gh && show_help && errxit "" "error: -${OPT} requires gh-cli" || GITHUB_TEAMS+=("$OPTARG")
      ;;
    s) ! _cmd_exists gh && show_help && errxit "" "error: -${OPT} requires gh-cli" || SUBMIT_PR=true
      ;;
    o) [ -n "${_rebase_option_flags}" ] && show_help && errxit "" "error: -${OPT} cannot be used with -X" || _rebase_option_flags='set' REBASE_OPTIONS=$OPTARG
      ;;
    i)  INTERACTIVE_REBASE=true
      ;;
    c)  CREATE_NEW_REPOSITORY=true
      ;;
    k)  KEEP_TMP_WORKSPACE=true
      ;;
    D)  DRY_RUN=true
      ;;
    N)  GITMUX_AUTHOR_NAME=$OPTARG
      ;;
    E)  GITMUX_AUTHOR_EMAIL=$OPTARG
      ;;
    n)  GITMUX_COMMITTER_NAME=$OPTARG
      ;;
    e)  GITMUX_COMMITTER_EMAIL=$OPTARG
      ;;
    C)  GITMUX_COAUTHOR_ACTION=$OPTARG
      ;;
    h)  show_help && exit 0;;
    v)   _verbose=1;;
    \? ) show_help; errxit "Unknown option: -${OPT} ( ${OPTARG} )";;
    ':') errxit "Missing option argument for -${OPT} ( ${OPTARG} )";;
    *  ) errxit "Unimplemented option: -${OPT} ( ${OPTARG} )";;
  esac
done

shift $((OPTIND-1))
[ "${1:-}" = "--" ] && shift

#
# Argument validation.
#
if [[ -z "$source_repository" ]]; then
  errxit "Source repository url or path (-r) is required"
elif [[ -z "$destination_repository" ]]; then
  errxit "Destination repository url or path (-t) is required"
elif [[ -z "${GH_HOST:-}" ]]; then
  errxit "GH_HOST must be set."
fi

if [[ -z "$subdirectory_filter" ]]; then
  errcho "No subdirectory filter specified! Entire source repository will be extracted."
fi

if [ ${#GITHUB_TEAMS[@]} -gt 0 ]; then
  log "validating github teams formats (length: ${#GITHUB_TEAMS[@]} ) --> ${GITHUB_TEAMS[*]}"
  for orgteam in "${GITHUB_TEAMS[@]}"; do
    if [[ ! "${orgteam}" =~ "/" ]]; then
      errxit "team format should be <org>/<team>"
    fi
  done
fi

# Validate gh is available when -c flag is used
if [[ "${CREATE_NEW_REPOSITORY}" == "true" ]]; then
  if ! command -v gh &> /dev/null; then
    errxit "Error: -c flag requires gh (GitHub CLI) but it's not installed. Install from: https://cli.github.com/"
  fi
fi

# Validate author/committer options: require both name and email if either provided
if [[ -n "$GITMUX_AUTHOR_NAME" ]] && [[ -z "$GITMUX_AUTHOR_EMAIL" ]]; then
  errxit "--author-name requires --author-email to also be specified"
elif [[ -z "$GITMUX_AUTHOR_NAME" ]] && [[ -n "$GITMUX_AUTHOR_EMAIL" ]]; then
  errxit "--author-email requires --author-name to also be specified"
fi

if [[ -n "$GITMUX_COMMITTER_NAME" ]] && [[ -z "$GITMUX_COMMITTER_EMAIL" ]]; then
  errxit "--committer-name requires --committer-email to also be specified"
elif [[ -z "$GITMUX_COMMITTER_NAME" ]] && [[ -n "$GITMUX_COMMITTER_EMAIL" ]]; then
  errxit "--committer-email requires --committer-name to also be specified"
fi

# Validate coauthor-action value
if [[ -n "$GITMUX_COAUTHOR_ACTION" ]] && [[ "$GITMUX_COAUTHOR_ACTION" != "claude" ]] && [[ "$GITMUX_COAUTHOR_ACTION" != "all" ]] && [[ "$GITMUX_COAUTHOR_ACTION" != "keep" ]]; then
  errxit "--coauthor-action must be 'claude', 'all', or 'keep', got: ${GITMUX_COAUTHOR_ACTION}"
fi

# Default coauthor-action to 'claude' when author/committer options are used
if [[ -z "$GITMUX_COAUTHOR_ACTION" ]]; then
  if [[ -n "$GITMUX_AUTHOR_NAME" ]] || [[ -n "$GITMUX_COMMITTER_NAME" ]]; then
    GITMUX_COAUTHOR_ACTION="claude"
  fi
fi

# Sanitize author/committer values to prevent shell injection
# These values are used in filter-branch scripts executed via eval
# Reject values containing shell metacharacters that could enable injection
_validate_safe_string() {
  local value="$1"
  local field_name="$2"
  # Reject strings containing shell metacharacters: ' " $ ` \ ; | & ( ) < > newline
  if [[ "$value" =~ [\'\"\$\`\\\;\|\&\(\)\<\>] ]] || [[ "$value" == *$'\n'* ]]; then
    errxit "${field_name} contains invalid characters (shell metacharacters are not allowed)"
  fi
}

if [[ -n "$GITMUX_AUTHOR_NAME" ]]; then
  _validate_safe_string "$GITMUX_AUTHOR_NAME" "--author-name"
  _validate_safe_string "$GITMUX_AUTHOR_EMAIL" "--author-email"
fi
if [[ -n "$GITMUX_COMMITTER_NAME" ]]; then
  _validate_safe_string "$GITMUX_COMMITTER_NAME" "--committer-name"
  _validate_safe_string "$GITMUX_COMMITTER_EMAIL" "--committer-email"
fi

#
# </Argument validation.>
#


# Export this for `gh`.
export GH_HOST=${GH_HOST}

_append_to_pr_branch_name=''
if [[ -z "${REBASE_OPTIONS}" ]]; then
  # If REBASE_OPTIONS are not set by caller, *now* we set this default.
  if [[ -z "$MERGE_STRATEGY_OPTION_FOR_REBASE" ]]; then
          errxit "Merge strategy option (-X) is required. Value choices: ours, theirs, patience, diff-algorithm=[patience|minimal|histogram|myers]"
  fi
  REBASE_OPTIONS="--keep-empty --autostash --merge --strategy recursive --strategy-option ${MERGE_STRATEGY_OPTION_FOR_REBASE}"
  _append_to_pr_branch_name="${MERGE_STRATEGY_OPTION_FOR_REBASE}"
fi

if [ "${INTERACTIVE_REBASE}" = true ]; then
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
  source_repository=$(_realpath "${source_repository}")
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
# the 2nd sed here is to parse out user:<token>@ notations from the domain
# Matches username:token@ where token can be up to 200 chars (fine-grained PATs are long)
source_domain=$(echo "${source_url}" | sed -E "${REPO_REGEX}"'/\2/' | sed -E "s/^[a-zA-Z0-9_-]+:[a-zA-Z0-9_]+@//")
source_project=$(echo "${source_url}" | sed -E "${REPO_REGEX}"'/\6/')
source_owner=$(echo "${source_url}" | sed -E "${REPO_REGEX}"'/\4/')
source_uri="${source_owner}/${source_project}"


if [[ -d "${destination_repository}" ]]; then
  log "Destination repository [ ${destination_repository} ] is to a local path."
  destination_repository=$(_realpath "${destination_repository}")
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
# the 2nd sed here is to parse out user:<token>@ notations from the domain
# Matches username:token@ where token can be up to 200 chars (fine-grained PATs are long)
destination_domain=$(echo "${destination_url}" | sed -E "${REPO_REGEX}"'/\2/' | sed -E "s/^[a-zA-Z0-9_-]+:[a-zA-Z0-9_]+@//")
destination_project=$(echo "${destination_url}" | sed -E "${REPO_REGEX}"'/\6/')
destination_owner=$(echo "${destination_url}" | sed -E "${REPO_REGEX}"'/\4/')
destination_uri="${destination_owner}/${destination_project}"

# This is for `gh`, which only interacts with the destination.
export GH_HOST="${destination_domain}"

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
log "source_git_ref            ==> ${source_git_ref}"
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

gitmux_TMP_WORKSPACE=$(mktemp -t 'gitmux-XXXXXX' -d || errxit "Failed to create tmpdir.")
log "Working in tmpdir ${gitmux_TMP_WORKSPACE}"
_pushd "${gitmux_TMP_WORKSPACE}"
_GITDIR="tmp-${source_owner}_${source_project}"
git clone "${source_repository}" "${_GITDIR}"
_pushd "${_GITDIR}"
git fetch --all --tags
_WORKSPACE=$(pwd)

# The following is unnecessary when doing a full clone.
# Without a full clone, this procedure just doesnt work quite right.
#git fetch --update-shallow --shallow-since=1month --update-head-ok --progress origin trunk

# If a non-default ref is specified, fetch it explicitly and perform a checkout.
if [[ -n "${source_git_ref}" ]]; then
  log "A specific git ref was given; checking out ${source_git_ref}"
  for _remote in $(git remote show); do
    log "Running \'git fetch --verbose --tags --progress ""${_remote}"" ""${source_git_ref}""\' in $(pwd)"
    git fetch --verbose --tags --progress "${_remote}" "${source_git_ref}"
  done
  log "Checking out ${source_git_ref}"
  git checkout --guess "${source_git_ref}"
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
# *in advance*.

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
    _rname="$(echo $RANDOM$RANDOM | tr '0-9' '[:lower:]').txt"
    echo "Created by gitmux. Serves as a .gitkeep in case the directory is empty. Delete me." > "${_rname}"
    git add --force --intent-to-add "${_rname}"
    # Move everything except __tmp__ into __tmp__
    # shellcheck disable=SC2046
    git mv $(echo !(__tmp__)) __tmp__
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

# Build --env-filter for author/committer override
_env_filter_script=""
if [[ -n "$GITMUX_AUTHOR_NAME" ]] || [[ -n "$GITMUX_COMMITTER_NAME" ]]; then
  # Export for use in filter subprocess
  export GITMUX_AUTHOR_NAME GITMUX_AUTHOR_EMAIL
  export GITMUX_COMMITTER_NAME GITMUX_COMMITTER_EMAIL
  # shellcheck disable=SC2016  # Single quotes are intentional - script is evaluated by filter-branch
  _env_filter_script='
    if [ -n "${GITMUX_AUTHOR_NAME:-}" ]; then
      export GIT_AUTHOR_NAME="${GITMUX_AUTHOR_NAME}"
      export GIT_AUTHOR_EMAIL="${GITMUX_AUTHOR_EMAIL}"
    fi
    if [ -n "${GITMUX_COMMITTER_NAME:-}" ]; then
      export GIT_COMMITTER_NAME="${GITMUX_COMMITTER_NAME}"
      export GIT_COMMITTER_EMAIL="${GITMUX_COMMITTER_EMAIL}"
    fi
  '
  log "Author/committer override enabled"
  log "  GITMUX_AUTHOR_NAME=${GITMUX_AUTHOR_NAME:-<not set>}"
  log "  GITMUX_AUTHOR_EMAIL=${GITMUX_AUTHOR_EMAIL:-<not set>}"
  log "  GITMUX_COMMITTER_NAME=${GITMUX_COMMITTER_NAME:-<not set>}"
  log "  GITMUX_COMMITTER_EMAIL=${GITMUX_COMMITTER_EMAIL:-<not set>}"
fi

# Build --msg-filter for Co-authored-by handling
_msg_filter_script=""
if [[ "$GITMUX_COAUTHOR_ACTION" == "claude" ]]; then
  # Remove only Claude/Anthropic attribution (preserves human co-authors)
  # Patterns based on common Claude attribution formats:
  # - Co-authored-by: Claude <...> or Claude Code <...>
  # - Co-authored-by: *@anthropic.com
  # - Generated with [Claude Code]... or [Claude]...
  # Note: Patterns are ordered most-specific-first to ensure proper matching.
  # The "Claude Code" pattern requires whitespace between the words to avoid
  # false positives like "Claudette McCode".
  _msg_filter_script='sed -E \
    -e "/[Cc]o-[Aa]uthored-[Bb]y:[[:space:]]*[Cc]laude[[:space:]]+[Cc]ode/d" \
    -e "/[Cc]o-[Aa]uthored-[Bb]y:.*[Cc]laude/d" \
    -e "/[Cc]o-[Aa]uthored-[Bb]y:.*@anthropic\.com/d" \
    -e "/[Gg]enerated with.*[Cc]laude/d"'
  log "Claude/Anthropic attribution will be removed from commit messages (human co-authors preserved)"
elif [[ "$GITMUX_COAUTHOR_ACTION" == "all" ]]; then
  # Remove ALL Co-authored-by lines and Generated-with signatures
  # Note: No ^ anchor - trailers may have leading whitespace (consistent with claude mode)
  _msg_filter_script='sed -E \
    -e "/[Cc]o-[Aa]uthored-[Bb]y:/d" \
    -e "/[Gg]enerated with/d"'
  log "All Co-authored-by trailers and Generated-with lines will be removed from commit messages"
fi

# git filter-branch can take `git rev-list` options for
# additional filtering control. For example, advanced
# users can target specific files for their [new] repo.
# <rev-list options>...

log "rev-list options --> ${rev_list_files}"
log "subdirectory filter options --> ${_subdirectory_filter_options}"
# Might need --unshallow
#git filter-branch --prune-empty ${_subdirectory_filter_options}
log "git filter-branch --tag-name-filter cat ${_subdirectory_filter_options:-} [...] ${rev_list_files}"

# WARNING: git-filter-branch has a glut of gotchas...
# Yeah, we know.
export FILTER_BRANCH_SQUELCH_WARNING=1

# Dry-run mode: show what would happen without making changes
if [[ "${DRY_RUN}" == "true" ]]; then
  echo ""
  echo "═══════════════════════════════════════════════════════════════════════════════"
  echo "                              DRY RUN MODE"
  echo "═══════════════════════════════════════════════════════════════════════════════"
  echo ""
  echo "Source: ${source_repository}"
  echo "Destination: ${destination_repository}"
  echo "Branch: ${GIT_BRANCH} (${GIT_SHA})"
  if [[ -n "${subdirectory_filter}" ]]; then
    echo "Subdirectory filter: ${subdirectory_filter}"
  fi
  if [[ -n "${destination_path}" ]]; then
    echo "Destination path: ${destination_path}"
  fi
  echo ""

  # Show author/committer changes
  if [[ -n "$GITMUX_AUTHOR_NAME" ]] || [[ -n "$GITMUX_COMMITTER_NAME" ]]; then
    echo "┌─ Author/Committer Override ─────────────────────────────────────────────────┐"
    if [[ -n "$GITMUX_AUTHOR_NAME" ]]; then
      echo "│  Author will be changed to: ${GITMUX_AUTHOR_NAME} <${GITMUX_AUTHOR_EMAIL}>"
    fi
    if [[ -n "$GITMUX_COMMITTER_NAME" ]]; then
      echo "│  Committer will be changed to: ${GITMUX_COMMITTER_NAME} <${GITMUX_COMMITTER_EMAIL}>"
    fi
    echo "└──────────────────────────────────────────────────────────────────────────────┘"
    echo ""
  fi

  # Show coauthor-action effects
  if [[ -n "$GITMUX_COAUTHOR_ACTION" ]] && [[ "$GITMUX_COAUTHOR_ACTION" != "keep" ]]; then
    echo "┌─ Co-author Trailer Handling ────────────────────────────────────────────────┐"
    if [[ "$GITMUX_COAUTHOR_ACTION" == "claude" ]]; then
      echo "│  Mode: claude (remove Claude/Anthropic attribution only)"
      echo "│  Will remove:"
      echo "│    - Co-authored-by: Claude <...>"
      echo "│    - Co-authored-by: Claude Code <...>"
      echo "│    - Co-authored-by: *@anthropic.com"
      echo "│    - Generated with [Claude...]"
      echo "│  Will preserve: Human co-author trailers"
    elif [[ "$GITMUX_COAUTHOR_ACTION" == "all" ]]; then
      echo "│  Mode: all (remove ALL co-author trailers)"
      echo "│  Will remove:"
      echo "│    - ALL Co-authored-by: lines"
      echo "│    - ALL Generated with lines"
    fi
    echo "└──────────────────────────────────────────────────────────────────────────────┘"
    echo ""
  fi

  # Show sample of commits that would be affected
  echo "┌─ Commits to be processed ────────────────────────────────────────────────────┐"
  _commit_count=$(git rev-list --count HEAD)
  echo "│  Total commits: ${_commit_count}"
  echo "│"
  echo "│  Recent commits (up to 10):"
  git log --oneline -10 | while IFS= read -r line; do
    echo "│    $line"
  done
  echo "└──────────────────────────────────────────────────────────────────────────────┘"
  echo ""

  # Show sample commit messages with co-author trailers (if any)
  if [[ -n "$GITMUX_COAUTHOR_ACTION" ]] && [[ "$GITMUX_COAUTHOR_ACTION" != "keep" ]]; then
    _coauthor_commits=$(git log --all --format="%H" | head -50 | while read -r sha; do
      git log -1 --format="%B" "$sha" 2>/dev/null | grep -qi "co-authored-by\|generated with" && echo "$sha"
    done | head -3)

    if [[ -n "$_coauthor_commits" ]]; then
      echo "┌─ Sample commits with trailers that would be modified ────────────────────────┐"
      echo "$_coauthor_commits" | while read -r sha; do
        if [[ -n "$sha" ]]; then
          echo "│"
          echo "│  Commit: $(git log -1 --format="%h %s" "$sha" | cut -c1-70)"
          echo "│  Trailers found:"
          git log -1 --format="%B" "$sha" | grep -iE "co-authored-by|generated with" | while IFS= read -r trailer; do
            echo "│    → $trailer"
          done
        fi
      done
      echo "└──────────────────────────────────────────────────────────────────────────────┘"
      echo ""
    fi
  fi

  echo "═══════════════════════════════════════════════════════════════════════════════"
  echo "  To apply these changes, run without --dry-run"
  echo "═══════════════════════════════════════════════════════════════════════════════"
  echo ""

  # Cleanup and exit (absolute path, no cd needed)
  rm -rf "${gitmux_TMP_WORKSPACE}"
  exit 0
fi

# Build the filter-branch command dynamically based on which filters are needed
_filter_branch_cmd="git filter-branch --tag-name-filter cat"

if [ -n "${_env_filter_script}" ]; then
  _filter_branch_cmd="${_filter_branch_cmd} --env-filter '${_env_filter_script}'"
fi

if [ -n "${_msg_filter_script}" ]; then
  _filter_branch_cmd="${_filter_branch_cmd} --msg-filter '${_msg_filter_script}'"
fi

if [ -n "${rev_list_files}" ]; then
  log "Targeting paths/revisions: ${rev_list_files}"
  # shellcheck disable=SC2086  # Word splitting is intentional: _subdirectory_filter_options
  # and rev_list_files contain multiple space-separated arguments that must expand separately.
  # NOTE: File paths containing spaces are not supported due to this word splitting.
  _filter_branch_cmd="${_filter_branch_cmd} ${_subdirectory_filter_options} --index-filter \"
    git read-tree --empty
    git reset \\\$GIT_COMMIT -- ${rev_list_files}
   \" -- --all -- ${rev_list_files}"
  log "Running: ${_filter_branch_cmd}"
  # SAFETY: eval is safe here because all user-provided values (author/committer names/emails)
  # are validated by _validate_safe_string() which rejects shell metacharacters.
  # The filter scripts use only these validated values and git's own variables.
  eval "${_filter_branch_cmd}"
else
  # shellcheck disable=SC2086  # Word splitting is intentional: _subdirectory_filter_options
  # contains multiple space-separated arguments (e.g., "--subdirectory-filter path")
  _filter_branch_cmd="${_filter_branch_cmd} ${_subdirectory_filter_options}"
  log "Running: ${_filter_branch_cmd}"
  # SAFETY: eval is safe here - see comment above regarding input validation
  eval "${_filter_branch_cmd}"
fi

log "git filter-branch completed."
log "$(git status)"
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
  if [ "${CREATE_NEW_REPOSITORY}" = true ] && [[ "${_repo_existence}" =~ "Repository not found" ]]; then

    ########## <GH CREATE REPO> ################
    # `gh repo create` runs from inside a git repository. (weird)
    log "gh is creating your new repository now! ( ${destination_owner}/${destination_project} )"
    NEW_REPOSITORY_DESCRIPTION="New repository from ${source_url} (${subdirectory_filter:-/})"
    # gh repo create [<name>] [flags]
    TMPGHCREATEWORKDIR=$(mktemp -t 'gitmux-gh-create-destination-XXXXXX' -d || errxit "Failed to create tmpdir.")
    # Note: If you want to move the --orphan bits below, remove --bare from the next line.
    _pushd "${TMPGHCREATEWORKDIR}"
    # TODO: Make --private possible
    gh repo create "${destination_owner}/${destination_project}" --public --license=unlicense --gitignore 'VVVV' --clone --description "${NEW_REPOSITORY_DESCRIPTION}"
    _pushd "${destination_project}"
    git remote --verbose show
    # Rename default branch to trunk (gitmux convention) if needed
    _current_branch=$(git branch --show-current)
    if [[ "${_current_branch}" != "${destination_branch}" ]]; then
      log "Renaming branch ${_current_branch} to ${destination_branch}"
      git branch -m "${destination_branch}"
      git push origin "${destination_branch}:${destination_branch}"
      gh repo edit "${destination_owner}/${destination_project}" --default-branch "${destination_branch}"
    fi
    _popd && _popd
    log "cleaning up gh-create workdir"
    rm -rf "${TMPGHCREATEWORKDIR}"
    ########## </GH CREATE REPO> ################

    log "Attempting (again) to fetch remote 'destination' --> ${destination_repository}"
    git fetch destination
    # Our brand new repo destination branch needs at least one commit (to be the base branch of a PR).
    # This will also help remind us where this repository came from.
    git status
    # A local 'trunk' branch probably already exists
    git checkout -b "gitmux-dest-${destination_branch}" destination/trunk
    git pull destination trunk
    # Unstage everything (from ${DESTINATION_PR_BRANCH_NAME})
    git rm -r --cached .
    git status
    log "Creating empty commit for its own sake"
    git commit --message 'Hello: this repository was created by gitmux.' --allow-empty
    # git push destination "${destination_branch}"
    pwd
    git push destination "gitmux-dest-${destination_branch}:trunk"
    # Now go back to the build branch.
    log "Going back to build branch --> ${DESTINATION_PR_BRANCH_NAME}"
    git checkout --force "${DESTINATION_PR_BRANCH_NAME}"
  else
    errxit "${_repo_existence}"
  fi
elif [ "${CREATE_NEW_REPOSITORY}" = true ]; then
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

MAX_RETRIES=50

# Rebase filtered content onto destination branch.
# Handles interactive rebase, automatic conflict resolution, and retry logic.
# Uses REBASE_OPTIONS global variable for rebase strategy.
perform_rebase () {
 git config --worktree merge.renameLimit 999999999
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
    # Handle rebase failures: check for common error patterns and attempt recovery
    if [[ "${output}" =~ "invalid upstream" ]]; then
      errcho "${output}"
      errxit "Invalid upstream. Does '${destination_branch}' exist in '${destination_repository}'?"
    elif [[ "${output}" =~ ^fatal ]]; then
      errcho '📛 Something went wrong during rebase.'
      errcho "${output}"
      return 1
    fi
    errcho "${output}"
    errcho "Rebase incomplete, trying to --continue..."
    n=1
    while (( n < MAX_RETRIES )) && ! output="$(git rebase --continue 2>&1)";do
      errcho "_______________________________________________"
      errcho "${output}"
      if [[ "${output}" =~ "needs merge" ]]; then
        echo "Renamed/unchanged files need merge, using \`git add --all\`"
        export GIT_EDITOR=true
        git add --all
      elif [[ "${output}" =~ "If you wish to commit it anyway" ]]; then
        echo "Committing anyway with \`git commit --allow-empty --no-edit\`"
        git commit --allow-empty --no-edit
      elif [[ "${output}" =~ ^fatal ]]; then
        errcho '📛 Something went wrong during rebase.'
        errcho "${output}"
        return 1
      fi
      errcho "[${n}] Trying to --continue again..."
      (( n += 1 ))
      git rebase --continue && break
      errcho "_______________________________________________"
    done
    if (( n > MAX_RETRIES )); then
      errcho "Max retries exceeded on rebase. Aborting."
      git rebase --abort
      errcho "${output}"
      return 1
    fi

    log "Pushing to branch ${DESTINATION_PR_BRANCH_NAME}"
    git push --force-with-lease --tags destination
    git push --follow-tags --progress --atomic --verbose --force-with-lease destination "${DESTINATION_PR_BRANCH_NAME}"
  else
    # rebase in elif condition succeeded
    log "Rebase completed successfully."
    log "Pushing to branch ${DESTINATION_PR_BRANCH_NAME}"
    git push --force-with-lease --tags destination
    git push --follow-tags --progress --atomic --verbose --force-with-lease destination "${DESTINATION_PR_BRANCH_NAME}"
  fi
}


perform_rebase

#
# GitHub API functions
#

# Get GitHub team ID by organization and team name.
# Arguments:
#   $1 - Organization name
#   $2 - Team slug/name
# Returns:
#   Team ID to stdout
function get_team_id() {
  local _org_name="${1}"
  local _team_name="${2}"
  # GET /orgs/:org/teams/:team_slug
  gh api "orgs/${_org_name}/teams/${_team_name}" --method GET | jq --exit-status -r '.id'
}

# Add a GitHub team to a repository with specified permissions.
# Arguments:
#   $1 - Team ID
#   $2 - Repository owner
#   $3 - Repository name
#   $4 - Permission level (pull, push, admin). Default: admin
function add_team_to_repository() {
  local _team_id="${1}"
  local _owner="${2}"
  local _repository="${3}"
  # choices: pull, push, admin
  local _permission="${4:-admin}"
  # PUT /teams/:team_id/repos/:owner/:repo
  log "Adding ${_team_id} to ${_owner}/${_repository}"
  echo "{\"permission\": \"${_permission}\"}" | gh api "teams/${_team_id}/repos/${_owner}/${_repository}" --input - --method PUT
  echo "✅ Added ${_team_id} to ${_owner}/${_repository} with '${_permission}' permissions"
}

#
# </GitHub API Functions>
#

if _cmd_exists gh && [ ${#GITHUB_TEAMS[@]} -gt 0 ]; then
  # shellcheck disable=SC2016
  echo "\`gh\` is installed. Adding teams ( ${GITHUB_TEAMS[*]} ) to ${destination_repository}"
  for orgteam in "${GITHUB_TEAMS[@]}"; do
    _org=$(echo "${orgteam}" | sed -E 's/(.*)\/(.*)/\1/')
    _team=$(echo "${orgteam}" | sed -E 's/(.*)\/(.*)/\2/')
    team_id=$(get_team_id "${_org}" "${_team}")
    log "Adding ${orgteam} ( ${team_id} ) to ${destination_owner}/${destination_project}"
    add_team_to_repository "${team_id}" "${destination_owner}" "${destination_project}"
  done
fi

# TODO: interpolate url links
# e.g.
_canonical_source_https_url="https://${source_domain}/${source_owner}/${source_project}"
_canonical_destination_https_url="https://${destination_domain}/${destination_owner}/${destination_project}"

echo "Now create a pull request from ${DESTINATION_PR_BRANCH_NAME} into ${destination_branch}"

PR_TITLE="Sync from ${source_uri} \`${source_git_ref:-${GIT_BRANCH}}\` revision \`${GIT_SHA}\`"
PR_DESCRIPTION=$(printf "%s\n" \
  "${PR_TITLE}" \
  "" \
  "# Hello" \
  "This is an automated pull request created by \`gitmux\`." \
  "" \
  "## Source repository details" \
  "Source URL: [\`${_canonical_source_https_url}\`](${_canonical_source_https_url})" \
  "Source git ref (if provided): \`${source_git_ref:-n/a}\`" \
  "Source git branch: \`${source_git_ref:-${GIT_BRANCH}}\` (\`${GIT_SHA}\`)" \
  "Directory within source repository (if provided, else entire repository): \`${subdirectory_filter:-/}\`" \
  "Repository url: [\`https://${source_domain}/${source_owner}/${source_project}/tree/${GIT_SHA}/${SUBDIRECTORY_FILTER}\`](https://${source_domain}/${source_owner}/${source_project}/tree/${GIT_SHA}/${SUBDIRECTORY_FILTER})" \
  "" \
  "## Destination repository details" \
  "Destination URL: [\`${_canonical_destination_https_url}\`](${_canonical_destination_https_url})" \
  "PR Branch at Destination (head): \`${DESTINATION_PR_BRANCH_NAME}\`" \
  "Destination branch (base): \`${DESTINATION_BRANCH}\`" \
  "PR Branch URL: [\`https://${destination_domain}/${destination_owner}/${destination_project}/tree/${DESTINATION_PR_BRANCH_NAME}/${DESTINATION_PATH:-}\`](https://${destination_domain}/${destination_owner}/${destination_project}/tree/${DESTINATION_PR_BRANCH_NAME}/${DESTINATION_PATH:-})" \
  "Destination path (if applicable, or identical in structure to source): \`${DESTINATION_PATH:-n/a}\`" \
  "" \
  "------------------------------" \
)

if _cmd_exists gh && [ "${SUBMIT_PR}" = true ]; then
  # shellcheck disable=SC2016
  echo '`gh` is installed. Submitting PR'
  gh pr --repo "${destination_domain}/${destination_owner}/${destination_project}" \
    create \
    --title "${PR_TITLE}" \
    --body "${PR_DESCRIPTION}" \
    --assignee @me \
    --base "${destination_branch}" \
    --head "${destination_owner}:${DESTINATION_PR_BRANCH_NAME}"
else
  errcho "Please manually submit PR for branch ${DESTINATION_PR_BRANCH_NAME} to ${destination_repository}"
  errcho "auto-generated pull request description:" "" "${PR_DESCRIPTION}"
fi


_popd && _popd && cleanup
