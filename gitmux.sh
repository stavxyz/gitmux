#!/usr/bin/env bash

# gitmux - Sync repository subsets while preserving full git history.
#
# What does this script do?
#   This script creates a pull request on a destination repository
#   with content from a source repository and maintains all commit
#   history for all synced/forked files.
#
#   Run ./gitmux.sh -h for usage information.
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

#
# Logging system with configurable log levels
#
# Log levels (in order of severity):
#   debug   - Detailed diagnostic information (command outputs, internal state)
#   info    - Key milestones and status updates (default)
#   warning - Non-fatal issues that may need attention
#   error   - Problems requiring user attention (always shown)
#
# Configuration precedence (highest to lowest):
#   1. CLI flag: --log-level / -L
#   2. Environment variable: GITMUX_LOG_LEVEL
#   3. Default: info
#
# The -v flag sets log level to debug for backwards compatibility.
#

# Default log level (can be overridden by env var, then CLI)
LOG_LEVEL="${GITMUX_LOG_LEVEL:-info}"

# ANSI color codes for log levels (used when stderr is a TTY)
_LOG_COLOR_RESET=''
_LOG_COLOR_DEBUG=''
_LOG_COLOR_INFO=''
_LOG_COLOR_WARN=''
_LOG_COLOR_ERROR=''

# Initialize colors if stderr is a TTY
if [[ -t 2 ]]; then
  _LOG_COLOR_RESET=$'\033[0m'
  _LOG_COLOR_DEBUG=$'\033[2m'      # dim/gray
  _LOG_COLOR_INFO=$'\033[0m'       # default
  _LOG_COLOR_WARN=$'\033[33m'      # yellow
  _LOG_COLOR_ERROR=$'\033[31m'     # red
fi

# ANSI color codes for help output (used when stdout is a TTY)
_HELP_RESET=''
_HELP_BOLD=''
_HELP_DIM=''
_HELP_CYAN=''
_HELP_GREEN=''

# Initialize help colors if stdout is a TTY
if [[ -t 1 ]]; then
  _HELP_RESET=$'\033[0m'
  _HELP_BOLD=$'\033[1m'
  _HELP_DIM=$'\033[2m'
  _HELP_CYAN=$'\033[36m'
  _HELP_GREEN=$'\033[32m'
fi

# Convert log level name to numeric value for comparison.
# Arguments:
#   $1 - Log level name (debug, info, warning, error)
# Returns:
#   Numeric value to stdout: 0=debug, 1=info, 2=warning, 3=error.
#   Unknown levels default to 1 (info) with a warning to stderr.
_log_level_to_num() {
  case "$1" in
    debug)   echo 0 ;;
    info)    echo 1 ;;
    warning) echo 2 ;;
    error)   echo 3 ;;
    *)
      # Warn about unknown level (can't use log_warn - would cause recursion)
      printf "[WARN] Unknown log level '%s', defaulting to 'info'\n" "$1" >&2
      echo 1
      ;;
  esac
}

# Check if a message at given level should be logged.
# Arguments:
#   $1 - Message level (debug, info, warning, error)
# Returns:
#   0 if should log, 1 if should suppress
_should_log() {
  local msg_level="$1"
  local current_num
  local msg_num
  current_num=$(_log_level_to_num "$LOG_LEVEL")
  msg_num=$(_log_level_to_num "$msg_level")
  [[ $msg_num -ge $current_num ]]
}

# Log a debug message (detailed diagnostic information).
# Only shown when LOG_LEVEL=debug.
# Arguments:
#   $@ - Message(s) to print
log_debug() {
  if _should_log debug; then
    printf "${_LOG_COLOR_DEBUG}[DEBUG]${_LOG_COLOR_RESET} %s\n" "$@" >&2
  fi
}

# Log an info message (key milestones and status updates).
# Shown when LOG_LEVEL is debug or info.
# Arguments:
#   $@ - Message(s) to print
log_info() {
  if _should_log info; then
    printf "${_LOG_COLOR_INFO}[INFO]${_LOG_COLOR_RESET} %s\n" "$@" >&2
  fi
}

# Log a warning message (non-fatal issues that may need attention).
# Shown when LOG_LEVEL is debug, info, or warning.
# Arguments:
#   $@ - Message(s) to print
log_warn() {
  if _should_log warning; then
    printf "${_LOG_COLOR_WARN}[WARN]${_LOG_COLOR_RESET} %s\n" "$@" >&2
  fi
}

# Log an error message.
# Always shown regardless of LOG_LEVEL - errors should never be suppressed
# as they indicate failures that users must see.
# Note: This does NOT exit the script. Use errxit() for fatal errors.
# Arguments:
#   $@ - Message(s) to print
log_error() {
  printf "${_LOG_COLOR_ERROR}[ERROR]${_LOG_COLOR_RESET} %s\n" "$@" >&2
}

# Print message to stderr (legacy function, kept for compatibility).
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
  log_error "$@"
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
    log_warn "$* command not installed"
    return 1
  fi
}

# Clean up temporary workspace.
# Removes the temp directory unless KEEP_TMP_WORKSPACE is true.
cleanup() {
  if [[ -d ${gitmux_TMP_WORKSPACE:-} ]]; then
    # shellcheck disable=SC2086
    if [ ${KEEP_TMP_WORKSPACE:-false} = true ]; then
      log_info "📁 Workspace preserved at: ${gitmux_TMP_WORKSPACE}"
      log_info "   You may navigate there to complete the workflow manually."
    else
      log_debug "Cleaning up temp workspace..."
      rm -rf "${gitmux_TMP_WORKSPACE}"
      log_debug "Deleted gitmux tmp workspace ${gitmux_TMP_WORKSPACE}"
    fi
  fi
}

# Handle error conditions: print error message, clean up, and exit.
# Arguments:
#   $1 - (optional) Line number where error occurred
# shellcheck disable=SC2120
errcleanup() {
  log_error "⛔️ gitmux execution failed."
  if [ -n "${1:-}" ]; then
    log_error "   Error occurred at line ${1}."
  fi
  cleanup
  exit 1
}

# Handle interrupt signals (SIGHUP, SIGINT, SIGTERM).
# Cleans up and exits gracefully.
intcleanup() {
  log_warn "🍿 Script interrupted."
  cleanup
  exit 1
}

trap 'errcleanup ${LINENO}' ERR
trap 'intcleanup' SIGHUP SIGINT SIGTERM

#
# Early validation: check for required commands
#
if ! command -v git &> /dev/null; then
  log_error "git is required but not installed."
  exit 1
fi

if ! command -v jq &> /dev/null; then
  log_error "jq is required but not installed."
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
    '--log-level')       set -- "$@" '-L' ;;
    '--skip-preflight')  set -- "$@" '-S' ;;
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
SKIP_PREFLIGHT="${SKIP_PREFLIGHT:-false}"

# Don't default these rebase options *yet*
MERGE_STRATEGY_OPTION_FOR_REBASE="${MERGE_STRATEGY_OPTION_FOR_REBASE:-theirs}"
REBASE_OPTIONS="${REBASE_OPTIONS:-}"
GH_HOST="${GH_HOST:-github.com}"
GITHUB_TEAMS=()
PATH_MAPPINGS=()

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

# Normalize path to canonical form.
# Converts ".", "/", or empty string to "" (meaning root).
# Also strips leading/trailing slashes.
# Arguments:
#   $1 - Path string to normalize
# Returns:
#   Normalized path to stdout ("" means root)
function normalize_path () {
  local path="$1"
  path="$(stripslashes "$path")"
  if [[ "$path" == "." ]]; then
    path=""
  fi
  echo "$path"
}

# Parse a path mapping in "source:dest" format.
# Handles escaped colons (\:) in paths.
# Arguments:
#   $1 - Mapping string (e.g., "src/foo:dest/bar" or "path\:with\:colons:dest")
# Returns:
#   Sets global variables PARSED_SOURCE and PARSED_DEST
#   Returns 0 on success, 1 on validation error
function parse_path_mapping () {
  local mapping="$1"

  # Initialize globals to prevent stale values from previous calls
  PARSED_SOURCE=""
  PARSED_DEST=""

  # Replace escaped colons with a placeholder (ASCII unit separator)
  local placeholder=$'\x1f'
  local escaped_mapping="${mapping//\\:/$placeholder}"

  # Count unescaped colons
  local colon_count
  colon_count=$(echo "$escaped_mapping" | tr -cd ':' | wc -c | tr -d ' ')

  if [[ "$colon_count" -eq 0 ]]; then
    log_error "Invalid path mapping: '$mapping' - missing colon separator"
    log_error "Format: source:dest (use \\: to escape literal colons)"
    return 1
  elif [[ "$colon_count" -gt 1 ]]; then
    log_error "Invalid path mapping: '$mapping' - multiple unescaped colons"
    log_error "Format: source:dest (use \\: to escape literal colons)"
    return 1
  fi

  # Split on the single unescaped colon
  local source_part="${escaped_mapping%%:*}"
  local dest_part="${escaped_mapping#*:}"

  # Restore escaped colons
  source_part="${source_part//$placeholder/:}"
  dest_part="${dest_part//$placeholder/:}"

  # Normalize paths
  PARSED_SOURCE="$(normalize_path "$source_part")"
  PARSED_DEST="$(normalize_path "$dest_part")"

  return 0
}

# Validate that destination paths don't overlap.
# Two paths overlap if one is a prefix of the other.
# Arguments:
#   $@ - Array of destination paths to check
# Returns:
#   0 if no overlaps, 1 if overlaps detected
function validate_no_dest_overlap () {
  local -a paths=("$@")
  local i j path1 path2

  for ((i = 0; i < ${#paths[@]}; i++)); do
    for ((j = i + 1; j < ${#paths[@]}; j++)); do
      path1="${paths[i]}"
      path2="${paths[j]}"

      # Empty paths (root) overlap with everything
      if [[ -z "$path1" ]] || [[ -z "$path2" ]]; then
        if [[ ${#paths[@]} -gt 1 ]]; then
          log_error "Destination path conflict: root (empty) path cannot be used with other paths"
          return 1
        fi
      fi

      # Check if paths are identical
      if [[ "$path1" == "$path2" ]]; then
        log_error "Destination path conflict: '$path1' specified multiple times"
        return 1
      fi

      # Check if one is a prefix of the other (with path separator awareness)
      if [[ "$path1/" == "${path2:0:$((${#path1}+1))}" ]]; then
        log_error "Destination path conflict: '$path1' is a parent of '$path2'"
        return 1
      fi
      if [[ "$path2/" == "${path1:0:$((${#path2}+1))}" ]]; then
        log_error "Destination path conflict: '$path2' is a parent of '$path1'"
        return 1
      fi
    done
  done

  return 0
}

# DEPRECATED: Legacy verbose logging function.
# Internal uses remain for backwards compatibility, but new code should use
# the log_debug(), log_info(), log_warn(), or log_error() functions instead.
# Removal planned for v2.0.
# Arguments:
#   $@ - Message(s) to print
function log () {
  # Legacy log() maps to log_debug() for backwards compatibility
  log_debug "$@"
}

# Display usage information and available options.
function show_help()
{
  # Helper functions for formatted output (scoped to show_help to avoid global namespace pollution)
  _help_header() { printf '\n%s%s%s\n' "${_HELP_BOLD}${_HELP_CYAN}" "$1" "${_HELP_RESET}"; }
  _help_flag() { printf '  %s%-28s%s %s\n' "${_HELP_BOLD}${_HELP_GREEN}" "$1" "${_HELP_RESET}" "$2"; }
  _help_cont() { printf '  %-28s %s%s%s\n' "" "${_HELP_DIM}" "$1" "${_HELP_RESET}"; }

  echo
  printf '%sgitmux%s - Sync repository subsets while preserving full git history\n' \
    "${_HELP_BOLD}" "${_HELP_RESET}"
  echo
  printf '%sUsage:%s %s %s-r%s SOURCE %s-t%s DESTINATION [OPTIONS]\n' \
    "${_HELP_DIM}" "${_HELP_RESET}" "${0##*/}" "${_HELP_GREEN}" "${_HELP_RESET}" "${_HELP_GREEN}" "${_HELP_RESET}"

  _help_header "Required"
  _help_flag "-r <url|path>" "Source repository"
  _help_flag "-t <url|path>" "Destination repository"

  _help_header "Path Filtering"
  _help_flag "-m <src:dest>" "Map source path to destination (repeatable)"
  _help_cont "Use \\: for literal colons. Empty or '.' means root"
  _help_cont "Examples: -m src/lib:pkg/lib  -m src/app:"
  _help_flag "-d <path>" "Extract only this subdirectory from source"
  _help_flag "-p <path>" "Place content at this path in destination"
  _help_flag "-g <ref>" "Source git ref: branch, tag, or commit"
  _help_flag "-l <rev-list>" "Extract specific files (git rev-list format)"

  _help_header "Destination"
  _help_flag "-b <branch>" "Target branch in destination (default: trunk)"
  _help_flag "-c" "Create destination repo if missing (requires gh)"

  _help_header "Rebase"
  _help_flag "-X <strategy>" "Strategy: theirs|ours|patience (default: theirs)"
  _help_flag "-o <options>" "Custom git rebase options (mutex with -X)"
  _help_flag "-i" "Interactive rebase mode"

  _help_header "GitHub Integration"
  _help_flag "-s" "Submit PR automatically (requires gh)"
  _help_flag "-z <org/team>" "Add team to destination repo (repeatable)"

  _help_header "Author Rewriting"
  _help_flag "-N, --author-name <name>" "Override author name for all commits"
  _help_flag "-E, --author-email <email>" "Override author email for all commits"
  _help_flag "-n, --committer-name <name>" "Override committer name"
  _help_flag "-e, --committer-email <email>" "Override committer email"
  _help_flag "-C, --coauthor-action <act>" "Co-authored-by: claude|all|keep"
  _help_cont "claude: remove Claude/Anthropic attribution only"
  _help_cont "all: remove all Co-authored-by trailers"
  _help_cont "keep: preserve all trailers (default)"
  _help_flag "-D, --dry-run" "Preview changes without modifying anything"

  _help_header "Logging & Debug"
  _help_flag "-L, --log-level <level>" "debug|info|warning|error (default: info)"
  _help_flag "-S, --skip-preflight" "Skip pre-flight validation checks"
  _help_flag "-k" "Keep temp workspace for debugging"
  _help_flag "-v" "Verbose output (sets log level to debug)"
  _help_flag "-h" "Show this help"

  echo
  printf '%s"The life of a repo man is always intense."%s\n' "${_HELP_DIM}" "${_HELP_RESET}"
  echo
}

# Rebase option related flags are mutually exclusive
_rebase_option_flags=''
# Track usage of -m vs -d/-p for mutual exclusivity validation
_used_m_flag=false
_used_legacy_flags=false

# Show help if no arguments provided
if [[ $# -eq 0 ]]; then
  show_help
  exit 0
fi

while getopts "hvr:d:g:t:p:z:b:l:o:X:m:sickDSL:N:E:n:e:C:" OPT; do
  case "$OPT" in
    r)  source_repository=$OPTARG
      ;;
    d)  subdirectory_filter="$(stripslashes "${OPTARG}")" # Is relative to the git repo, should not have leading slashes.
        _used_legacy_flags=true
      ;;
    l)  rev_list_files=$OPTARG
      ;;
    g)  source_git_ref=$OPTARG
      ;;
    t)  destination_repository=$OPTARG
      ;;
    p)  destination_path="$(stripslashes "${OPTARG}")" # Is relative to the git repo, should not have leading slashes.
        _used_legacy_flags=true
      ;;
    m)  PATH_MAPPINGS+=("$OPTARG")
        _used_m_flag=true
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
    S)  SKIP_PREFLIGHT=true
      ;;
    L)  LOG_LEVEL=$OPTARG
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
    v)  _verbose=1
        LOG_LEVEL=debug
      ;;
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

# Validate log level value
case "$LOG_LEVEL" in
  debug|info|warning|error) ;; # Valid values
  *) errxit "--log-level must be 'debug', 'info', 'warning', or 'error', got: ${LOG_LEVEL}" ;;
esac

if [[ -z "$source_repository" ]]; then
  errxit "Source repository url or path (-r) is required"
elif [[ -z "$destination_repository" ]]; then
  errxit "Destination repository url or path (-t) is required"
elif [[ -z "${GH_HOST:-}" ]]; then
  errxit "GH_HOST must be set."
fi

# Validate mutual exclusivity of -m and -d/-p
if [[ "$_used_m_flag" == "true" ]] && [[ "$_used_legacy_flags" == "true" ]]; then
  errxit "-m cannot be used with -d or -p. Use -m for all path mappings, or -d/-p for a single mapping."
fi

# Parse and validate -m mappings
if [[ ${#PATH_MAPPINGS[@]} -gt 0 ]]; then
  # Parse each mapping and collect destinations for overlap validation
  declare -a _parsed_sources=()
  declare -a _parsed_dests=()

  for mapping in "${PATH_MAPPINGS[@]}"; do
    if ! parse_path_mapping "$mapping"; then
      errxit "Failed to parse path mapping: $mapping"
    fi
    _parsed_sources+=("$PARSED_SOURCE")
    _parsed_dests+=("$PARSED_DEST")
  done

  # Validate no destination overlaps
  if ! validate_no_dest_overlap "${_parsed_dests[@]}"; then
    errxit "Path mapping validation failed"
  fi

  log "Parsed ${#PATH_MAPPINGS[@]} path mapping(s):"
  for ((i = 0; i < ${#_parsed_sources[@]}; i++)); do
    log "  [${i}] '${_parsed_sources[i]:-<root>}' -> '${_parsed_dests[i]:-<root>}'"
  done

  # Store parsed values for later use (we'll re-parse in the loop, but this validates upfront)
  unset _parsed_sources _parsed_dests
elif [[ -n "$subdirectory_filter" ]] || [[ -n "$destination_path" ]]; then
  # Convert legacy -d/-p to PATH_MAPPINGS format for unified processing
  PATH_MAPPINGS+=("${subdirectory_filter}:${destination_path}")
  log "Using legacy -d/-p flags, converted to mapping: '${subdirectory_filter:-<root>}' -> '${destination_path:-<root>}'"
else
  # No mappings specified - entire repo to root (fork behavior)
  PATH_MAPPINGS+=(":")
  log_info "No subdirectory filter or path mappings specified! Entire source repository will be extracted."
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

# Validate coauthor-action value (must be one of: claude, all, keep)
if [[ -n "$GITMUX_COAUTHOR_ACTION" ]]; then
  case "$GITMUX_COAUTHOR_ACTION" in
    claude|all|keep) ;; # Valid values
    *) errxit "--coauthor-action must be 'claude', 'all', or 'keep', got: ${GITMUX_COAUTHOR_ACTION}" ;;
  esac
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
#
# SECURITY NOTE: This validation is CRITICAL for safe eval usage later in the script.
# The validated values are interpolated into shell scripts passed to git filter-branch.
# Any shell metacharacter could enable command injection. The blocklist includes:
#   ' " $ ` \ ; | & ( ) < > and newlines
# This is a defense-in-depth measure - values should also only come from trusted sources.
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

#
# Pre-flight checks
#
# Validates that all required tools and permissions are available before
# starting long-running operations. Fails fast with actionable error messages.
#

# Print a check result with pass/fail/warn indicator.
# Arguments:
#   $1 - "pass", "fail", or "warn"
#   $2 - Check description
_preflight_result() {
  local check_status="$1"
  local desc="$2"
  case "$check_status" in
    pass) echo "  ✅ ${desc}" >&2 ;;
    fail) echo "  ❌ ${desc}" >&2 ;;
    warn) echo "  ⚠️  ${desc}" >&2 ;;
    *)    echo "  ❓ ${desc} (unknown status: ${check_status})" >&2 ;;
  esac
}

# Run pre-flight checks to validate environment before starting work.
# Checks are conditional based on which flags are used.
# Note: SKIP_PREFLIGHT and DRY_RUN are evaluated by the caller before
# invoking this function; this function assumes it should run.
# Globals required (must be set before calling):
#   source_repository, destination_repository, source_git_ref
#   destination_owner, destination_project, destination_branch
#   SUBMIT_PR, CREATE_NEW_REPOSITORY, GITHUB_TEAMS
# Returns:
#   0 if all checks pass, 1 if any check fails
preflight_checks() {
  local _checks_passed=true
  local _gh_needed=false
  local _source_is_url=false
  local _dest_is_url=false

  # Determine if gh is needed based on flags
  if [[ "${SUBMIT_PR}" == "true" ]] || [[ "${CREATE_NEW_REPOSITORY}" == "true" ]] || [[ ${#GITHUB_TEAMS[@]} -gt 0 ]]; then
    _gh_needed=true
  fi

  # Determine if source/destination are URLs (treat non-directories as remote repos)
  if [[ ! -d "${source_repository}" ]]; then
    _source_is_url=true
  fi
  if [[ ! -d "${destination_repository}" ]]; then
    _dest_is_url=true
  fi

  log_info "🔍 Running pre-flight checks..."

  # Verify git is installed (always required)
  if command -v git &> /dev/null; then
    _preflight_result pass "git installed"
  else
    _preflight_result fail "git not installed"
    _checks_passed=false
  fi

  # Verify gh is installed (if needed)
  if [[ "$_gh_needed" == "true" ]]; then
    if command -v gh &> /dev/null; then
      _preflight_result pass "gh CLI installed"
    else
      _preflight_result fail "gh CLI not installed (required for -s, -c, or -z flags)"
      log_error ""
      log_error "  📦 Install from: https://cli.github.com/"
      _checks_passed=false
    fi
  fi

  # Verify gh is authenticated (if gh is needed)
  if [[ "$_gh_needed" == "true" ]] && command -v gh &> /dev/null; then
    local _gh_auth_output
    local _gh_auth_status
    _gh_auth_output=$(gh auth status 2>&1)
    _gh_auth_status=$?

    if [[ $_gh_auth_status -eq 0 ]]; then
      # Extract username from auth status - try multiple patterns
      local _gh_user=""
      _gh_user=$(echo "$_gh_auth_output" | grep -oE "Logged in to [^ ]+ account [^ ]+ " | head -1 | awk '{print $NF}' | tr -d '()')
      if [[ -z "$_gh_user" ]]; then
        _gh_user=$(echo "$_gh_auth_output" | grep -oE "account [^ ]+" | head -1 | awk '{print $2}')
      fi
      if [[ -z "$_gh_user" ]]; then
        log_debug "Could not parse username from gh auth output, showing as 'authenticated'"
        _gh_user="authenticated"
      fi
      _preflight_result pass "gh authenticated (${_gh_user})"
    else
      _preflight_result fail "gh not authenticated"
      log_error ""
      log_error "  🔐 gh cannot authenticate. This may be because:"
      log_error "    - You haven't logged in: run 'gh auth login'"
      if [[ -n "${GH_TOKEN:-}" ]]; then
        log_error "    - GH_TOKEN is set but may be invalid or expired"
        log_error "    - Try: unset GH_TOKEN && gh auth status"
      fi
      log_error ""
      _checks_passed=false
    fi
  fi

  # Verify source repository is accessible
  if [[ "$_source_is_url" == "true" ]]; then
    local _ls_remote_output
    local _ls_remote_status
    _ls_remote_output=$(git ls-remote --exit-code "${source_repository}" HEAD 2>&1)
    _ls_remote_status=$?

    if [[ $_ls_remote_status -eq 0 ]]; then
      _preflight_result pass "source repo accessible"
    else
      _preflight_result fail "source repo not accessible"
      log_error ""
      log_error "  📂 Cannot access source repository: ${source_repository}"
      log_error "  Git error: ${_ls_remote_output}"
      log_error ""
      _checks_passed=false
    fi
  else
    # Local repository - verify git can actually read it
    local _git_check_output
    if [[ -d "${source_repository}/.git" ]]; then
      if _git_check_output=$(git -C "${source_repository}" rev-parse --git-dir 2>&1); then
        _preflight_result pass "source repo accessible (local)"
      else
        _preflight_result fail "source .git directory exists but repository is not readable"
        log_error ""
        log_error "  📂 The .git directory exists but git cannot read it: ${source_repository}"
        log_error "  Git error: ${_git_check_output}"
        log_error ""
        _checks_passed=false
      fi
    elif _git_check_output=$(git -C "${source_repository}" rev-parse --git-dir 2>&1); then
      # Bare repository or non-standard git directory
      _preflight_result pass "source repo accessible (local)"
    else
      log_debug "git rev-parse output: ${_git_check_output}"
      _preflight_result fail "source path is not a git repository"
      log_error ""
      log_error "  📂 Path exists but is not a git repository: ${source_repository}"
      log_error ""
      _checks_passed=false
    fi
  fi

  # Verify source git ref exists (if -g specified)
  if [[ -n "${source_git_ref}" ]] && [[ "$_source_is_url" == "true" ]]; then
    local _ref_output
    local _ref_status
    _ref_output=$(git ls-remote --exit-code "${source_repository}" "${source_git_ref}" 2>&1)
    _ref_status=$?

    if [[ $_ref_status -eq 0 ]]; then
      _preflight_result pass "source git ref exists (${source_git_ref})"
    else
      # ls-remote can't verify commit hashes directly - need to clone first
      log_debug "git ls-remote could not verify ref '${source_git_ref}': ${_ref_output}"
      _preflight_result warn "source git ref '${source_git_ref}' (deferred verification - may be commit hash)"
    fi
  fi

  # Verify destination repo is accessible with write access (if gh needed and dest is URL)
  if [[ "$_gh_needed" == "true" ]] && [[ "$_dest_is_url" == "true" ]] && command -v gh &> /dev/null; then
    # Verify destination_owner and destination_project are set
    if [[ -z "${destination_owner:-}" ]] || [[ -z "${destination_project:-}" ]]; then
      log_error "Internal error: destination_owner/destination_project not set before preflight checks"
      return 1
    fi

    local _dest_api_path="${destination_owner}/${destination_project}"
    local _dest_perms_output
    local _dest_api_status
    local _can_push=false

    # Use proper jq to extract push permission directly
    _dest_perms_output=$(gh api "repos/${_dest_api_path}" --jq '.permissions.push // "null"' 2>&1)
    _dest_api_status=$?

    if [[ $_dest_api_status -eq 0 ]]; then
      if [[ "$_dest_perms_output" == "true" ]]; then
        _can_push=true
        _preflight_result pass "destination repo accessible with push access"
      elif [[ "$_dest_perms_output" == "false" ]]; then
        _preflight_result fail "destination repo accessible but no push access"
        log_error ""
        log_error "  🔒 You can access ${_dest_api_path} but don't have push permissions."
        log_error ""
        _checks_passed=false
      else
        # Permissions field might be null or missing
        _preflight_result warn "destination repo accessible (permissions unclear)"
        log_debug "Unexpected permissions response: ${_dest_perms_output}"
        # Don't fail - let the actual push operation determine if we have access
        _can_push=true
      fi
    else
      # Repo not accessible - analyze the error
      if [[ "${CREATE_NEW_REPOSITORY}" == "true" ]]; then
        _preflight_result pass "destination repo will be created"
      else
        _preflight_result fail "destination repo not accessible (${_dest_api_path})"
        log_error ""
        log_error "  📂 gh cannot access this repository. This may be because:"
        log_error "    - The repository doesn't exist (use -c to create it)"
        log_error "    - You don't have permission to access it"
        if [[ -n "${GH_TOKEN:-}" ]]; then
          log_error "    - GH_TOKEN is set to a token without access"
          log_error "    - Try: unset GH_TOKEN && gh auth status"
        fi
        if [[ "$_dest_perms_output" =~ "rate limit" ]] || [[ "$_dest_perms_output" =~ "403" ]]; then
          log_error "    - API rate limit may have been exceeded"
        fi
        log_error ""
        _checks_passed=false
      fi
    fi

    # Verify destination branch exists (unless creating new repo)
    if [[ "${CREATE_NEW_REPOSITORY}" != "true" ]] && [[ "$_can_push" == "true" ]]; then
      local _branch_output
      local _branch_status
      _branch_output=$(gh api "repos/${_dest_api_path}/branches/${destination_branch}" --jq '.name' 2>&1)
      _branch_status=$?

      if [[ $_branch_status -eq 0 ]]; then
        _preflight_result pass "destination branch exists (${destination_branch})"
      else
        # Analyze the error
        if [[ "$_branch_output" =~ "404" ]] || [[ "$_branch_output" =~ "Branch not found" ]] || [[ "$_branch_output" =~ "Not Found" ]]; then
          _preflight_result fail "destination branch not found (${destination_branch})"
          log_error ""
          log_error "  🌿 Branch '${destination_branch}' does not exist in ${_dest_api_path}"
          log_error "  Use -b to specify a different branch, or check the repository's default branch."
          log_error ""
        else
          _preflight_result fail "destination branch check failed (${destination_branch})"
          log_error ""
          log_error "  🌿 Failed to verify branch: ${_branch_output}"
          log_error ""
        fi
        _checks_passed=false
      fi
    fi
  fi

  # Verify teams exist (if -z used)
  if [[ ${#GITHUB_TEAMS[@]} -gt 0 ]] && command -v gh &> /dev/null; then
    for orgteam in "${GITHUB_TEAMS[@]}"; do
      local _org="${orgteam%%/*}"
      local _team="${orgteam#*/}"
      local _team_api_output
      local _team_api_status

      _team_api_output=$(gh api "orgs/${_org}/teams/${_team}" --jq '.id' 2>&1)
      _team_api_status=$?

      if [[ $_team_api_status -eq 0 ]] && [[ -n "$_team_api_output" ]] && [[ "$_team_api_output" != "null" ]]; then
        _preflight_result pass "team exists (${orgteam})"
      else
        _preflight_result fail "team check failed (${orgteam})"
        log_error ""
        if [[ "$_team_api_output" =~ "404" ]] || [[ "$_team_api_output" =~ "Not Found" ]]; then
          log_error "  👥 Team '${_team}' not found in organization '${_org}'"
          log_error "  Verify the team name and your permissions."
        elif [[ "$_team_api_output" =~ "403" ]] || [[ "$_team_api_output" =~ "rate limit" ]]; then
          log_error "  👥 API rate limit or permission issue for team '${orgteam}'"
          log_error "  Response: ${_team_api_output}"
        else
          log_error "  👥 Unexpected error checking team '${orgteam}': ${_team_api_output}"
        fi
        log_error ""
        _checks_passed=false
      fi
    done
  fi

  if [[ "$_checks_passed" == "true" ]]; then
    log_info "✅ All pre-flight checks passed!"
    return 0
  else
    log_error ""
    log_error "❌ Pre-flight checks failed. Aborting."
    return 1
  fi
}

# Export this for `gh`.
export GH_HOST=${GH_HOST}

_append_to_pr_branch_name=''
if [[ -z "${REBASE_OPTIONS}" ]]; then
  # If REBASE_OPTIONS are not set by caller, *now* we set this default.
  if [[ -z "$MERGE_STRATEGY_OPTION_FOR_REBASE" ]]; then
          errxit "Merge strategy option (-X) is required. Value choices: ours, theirs, patience, diff-algorithm=[patience|minimal|histogram|myers]"
  fi
  REBASE_OPTIONS="--keep-empty --autostash --merge --strategy recursive --strategy-option ${MERGE_STRATEGY_OPTION_FOR_REBASE}"
  # Use histogram diff algorithm by default - extends patience algorithm to
  # support low-occurrence common elements (see: git diff-options docs)
  # Skip if user explicitly chose a diff algorithm via -X (patience or diff-algorithm=*)
  if [[ "${MERGE_STRATEGY_OPTION_FOR_REBASE}" != "patience" ]] && \
     [[ ! "${MERGE_STRATEGY_OPTION_FOR_REBASE}" =~ ^diff-algorithm= ]]; then
    REBASE_OPTIONS="${REBASE_OPTIONS} --strategy-option diff-algorithm=histogram"
  fi
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
  log_warn "⚠️  Source domain (${source_domain}) does not match destination domain (${destination_domain})."
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

# Run pre-flight checks unless skipped
# This must happen AFTER URL parsing (so destination_owner/project are available)
# but BEFORE temp workspace creation (so we fail fast before expensive operations)
if [[ "${SKIP_PREFLIGHT}" != "true" ]] && [[ "${DRY_RUN}" != "true" ]]; then
  if ! preflight_checks; then
    exit 1
  fi
fi

log_info "🚀 Starting gitmux sync..."
log_info "   📦 Source: ${source_repository}"
log_info "   📥 Destination: ${destination_repository}"

gitmux_TMP_WORKSPACE=$(mktemp -t 'gitmux-XXXXXX' -d || errxit "Failed to create tmpdir.")
log "Working in tmpdir ${gitmux_TMP_WORKSPACE}"
_pushd "${gitmux_TMP_WORKSPACE}"
_GITDIR="tmp-${source_owner}_${source_project}"
log_info "📥 Cloning source repository..."
if ! git clone "${source_repository}" "${_GITDIR}"; then
  errxit "Failed to clone source repository: ${source_repository}"
fi
_pushd "${_GITDIR}"
if ! git fetch --all --tags; then
  errxit "Failed to fetch tags from source repository"
fi
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

# Save original state for multi-mapping support
# We need to reset to this state before processing each subsequent mapping
ORIGINAL_HEAD=$(git rev-parse HEAD)
log "Saved original HEAD: ${ORIGINAL_HEAD}"

# Process a single source:dest mapping.
# Performs file reorganization and git filter-branch for one path mapping.
# Arguments:
#   $1 - Source path (subdirectory to extract, empty for root)
#   $2 - Destination path (where to place content, empty for root)
#   $3 - Mapping index (0-based, for logging)
#   $4 - Total mapping count (for logging)
# Globals used:
#   source_uri, GIT_BRANCH, rev_list_files
#   GITMUX_AUTHOR_NAME, GITMUX_AUTHOR_EMAIL, GITMUX_COMMITTER_NAME, GITMUX_COMMITTER_EMAIL
#   GITMUX_COAUTHOR_ACTION
# Returns:
#   0 on success, non-zero on failure
process_single_mapping() {
  local _source_path="$1"
  local _dest_path="$2"
  local _mapping_idx="$3"
  local _mapping_total="$4"

  log_info "📁 Processing mapping $((_mapping_idx + 1))/${_mapping_total}: '${_source_path:-<root>}' → '${_dest_path:-<root>}'"

  # File reorganization: if destination path is specified, restructure files
  if [[ -n "$_dest_path" ]] && ! [[ "${_dest_path}" == '/' ]]; then
    log "Destination path ( ${_dest_path} ) was specified. Do a tango."
    # ( Must use an intermediate temporary directory )
    if ! mkdir -p __tmp__; then
      log_error "Failed to create temporary directory __tmp__"
      return 1
    fi
    log "Temp dir created."

    if [ -n "${_source_path}" ]; then
      log "Moving files from ${_source_path} into tempdir."
      # Validate source path exists and has content
      if [[ ! -d "${_source_path}" ]]; then
        log_error "Source path '${_source_path}' does not exist"
        return 1
      fi
      # Check if source has files (use nullglob to handle empty case)
      shopt -s nullglob
      local _src_files=("${_source_path}"/*)
      shopt -u nullglob
      if [[ ${#_src_files[@]} -eq 0 ]]; then
        log_error "Source path '${_source_path}' is empty - nothing to migrate"
        return 1
      fi
      local _mv_output
      if ! _mv_output=$(git mv "${_src_files[@]}" __tmp__ 2>&1); then
        log_error "Failed to move files from '${_source_path}' to temp directory"
        log_error "Git error: ${_mv_output}"
        return 1
      fi
      log "Creating destination path ${_source_path}/${_dest_path}."
      if ! mkdir -p "${_source_path}/${_dest_path}"; then
        log_error "Failed to create destination path '${_source_path}/${_dest_path}'"
        return 1
      fi
      log "Moving content from tempdir into ${_source_path}/${_dest_path}."
      shopt -s nullglob
      local _tmp_files=(__tmp__/*)
      shopt -u nullglob
      if ! _mv_output=$(git mv "${_tmp_files[@]}" "${_source_path}/${_dest_path}/" 2>&1); then
        log_error "Failed to move files from temp directory to '${_source_path}/${_dest_path}/'"
        log_error "Git error: ${_mv_output}"
        return 1
      fi
      log "Cleaning up tempdir."
      if [[ -d __tmp__ ]] && ! rm -rf __tmp__; then
        log_warn "Failed to clean up temp directory __tmp__"
      fi
      if ! git add --update "${_source_path:-.}"; then
        log_error "Failed to stage updated files in '${_source_path:-.}'"
        return 1
      fi
    else
      log "Moving repository files into tempdir."
      # First create a random file in case the directory is empty
      # For some odd reason. (Delete afterward)
      local _rname
      _rname="$(echo $RANDOM$RANDOM | tr '0-9' 'a-j').txt"
      echo "Created by gitmux. Serves as a .gitkeep in case the directory is empty. Delete me." > "${_rname}"
      git add --force --intent-to-add "${_rname}"
      # Move everything except __tmp__ into __tmp__
      # Loop through files to avoid extglob issues in functions
      # Enable nullglob to handle empty directories gracefully
      local _moved_count=0
      local _mv_output
      shopt -s nullglob
      for _item in *; do
        if [[ "$_item" != "__tmp__" ]]; then
          if ! _mv_output=$(git mv "$_item" __tmp__/ 2>&1); then
            shopt -u nullglob
            log_error "Failed to move '$_item' to temp directory"
            log_error "Git error: ${_mv_output}"
            return 1
          fi
          _moved_count=$((_moved_count + 1))
        fi
      done
      shopt -u nullglob
      if [[ $_moved_count -eq 0 ]]; then
        log_error "Source repository appears empty - nothing to migrate"
        return 1
      fi
      if ! mkdir -p "${_dest_path}"; then
        log_error "Failed to create destination path '${_dest_path}'"
        return 1
      fi
      # Move files from temp to destination (use array to handle nullglob properly)
      shopt -s nullglob
      local _tmp_files=(__tmp__/*)
      shopt -u nullglob
      if ! _mv_output=$(git mv "${_tmp_files[@]}" "${_dest_path}/" 2>&1); then
        log_error "Failed to move files from temp directory to '${_dest_path}/'"
        log_error "Git error: ${_mv_output}"
        return 1
      fi
      # Trying to ensure we get all the commit history...
      if ! git add --update .; then
        log_error "Failed to stage updated files"
        return 1
      fi
      log "Cleaning up ${_rname}"
      if ! _mv_output=$(git rm -f "${_dest_path}/${_rname}" 2>&1); then
        log_warn "Failed to clean up temporary file '${_dest_path}/${_rname}'"
        log_debug "Git error: ${_mv_output}"
      fi
      log "Cleaning up tempdir."
      if [[ -d __tmp__ ]] && ! rm -rf __tmp__; then
        log_warn "Failed to clean up temp directory __tmp__"
      fi
    fi
  fi

  if ! git commit --allow-empty -m "Bring in changes from ${source_uri} ${GIT_BRANCH} [mapping $((_mapping_idx + 1))/${_mapping_total}]"; then
    log_error "Failed to commit file reorganization for mapping $((_mapping_idx + 1))"
    return 1
  fi

  # Build subdirectory filter options
  local _subdirectory_filter_options=""
  if [ -n "${_source_path}" ]; then
    _subdirectory_filter_options="--subdirectory-filter ${_source_path}"
  fi

  # Build --env-filter for author/committer override
  local _env_filter_script=""
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
  fi

  # Build --msg-filter for Co-authored-by handling
  local _msg_filter_script=""
  if [[ "$GITMUX_COAUTHOR_ACTION" == "claude" ]]; then
    _msg_filter_script='sed -E \
      -e "/[Cc]o-[Aa]uthored-[Bb]y:[[:space:]]*[Cc]laude[[:space:]]+[Cc]ode/d" \
      -e "/[Cc]o-[Aa]uthored-[Bb]y:[[:space:]]*[Cc]laude[[:space:]]*</d" \
      -e "/[Cc]o-[Aa]uthored-[Bb]y:.*@anthropic\.com/d" \
      -e "/[Gg]enerated with.*[Cc]laude/d"'
  elif [[ "$GITMUX_COAUTHOR_ACTION" == "all" ]]; then
    _msg_filter_script='sed -E \
      -e "/[Cc]o-[Aa]uthored-[Bb]y:/d" \
      -e "/[Gg]enerated with[[:space:]]*\[/d"'
  fi

  # Build the filter-branch command dynamically
  local _filter_branch_cmd="git filter-branch --tag-name-filter cat"

  if [ -n "${_env_filter_script}" ]; then
    _filter_branch_cmd="${_filter_branch_cmd} --env-filter '${_env_filter_script}'"
  fi

  if [ -n "${_msg_filter_script}" ]; then
    _filter_branch_cmd="${_filter_branch_cmd} --msg-filter '${_msg_filter_script}'"
  fi

  log "rev-list options --> ${rev_list_files}"
  log "subdirectory filter options --> ${_subdirectory_filter_options}"

  # WARNING: git-filter-branch has a glut of gotchas...
  # Yeah, we know.
  export FILTER_BRANCH_SQUELCH_WARNING=1

  if [ -n "${rev_list_files}" ]; then
    log "Targeting paths/revisions: ${rev_list_files}"
    # shellcheck disable=SC2086
    _filter_branch_cmd="${_filter_branch_cmd} ${_subdirectory_filter_options} --index-filter \"
      git read-tree --empty
      git reset \\\$GIT_COMMIT -- ${rev_list_files}
     \" -- --all -- ${rev_list_files}"
    log "Running: ${_filter_branch_cmd}"
    # SAFETY: eval is safe here because all user-provided values (author/committer names/emails)
    # are validated by _validate_safe_string() which rejects shell metacharacters.
    if ! eval "${_filter_branch_cmd}"; then
      log_error "git filter-branch failed for mapping $((_mapping_idx + 1))"
      log_debug "Command was: ${_filter_branch_cmd}"
      return 1
    fi
  else
    # shellcheck disable=SC2086
    _filter_branch_cmd="${_filter_branch_cmd} ${_subdirectory_filter_options}"
    log "Running: ${_filter_branch_cmd}"
    # SAFETY: eval is safe here - see comment above regarding input validation
    if ! eval "${_filter_branch_cmd}"; then
      log_error "git filter-branch failed for mapping $((_mapping_idx + 1))"
      log_debug "Command was: ${_filter_branch_cmd}"
      return 1
    fi
  fi

  # Count commits in the filtered history
  local _commit_count
  local _count_output
  if ! _count_output=$(git rev-list --count HEAD 2>&1); then
    log_warn "Could not count commits: ${_count_output}"
    _commit_count="?"
  else
    _commit_count="$_count_output"
  fi
  log_info "✨ Filter completed for mapping $((_mapping_idx + 1)) (${_commit_count} commits preserved)"
  log "$(git status)"
  return 0
}

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
  echo ""

  # Show path mappings
  echo "┌─ Path Mappings ──────────────────────────────────────────────────────────────┐"
  echo "│  Total mappings: ${#PATH_MAPPINGS[@]}"
  for ((i = 0; i < ${#PATH_MAPPINGS[@]}; i++)); do
    if ! parse_path_mapping "${PATH_MAPPINGS[i]}"; then
      echo "│  [$(( i + 1 ))] ERROR: Invalid mapping '${PATH_MAPPINGS[i]}'"
      continue
    fi
    echo "│  [$(( i + 1 ))] '${PARSED_SOURCE:-<root>}' -> '${PARSED_DEST:-<root>}'"
  done
  echo "└──────────────────────────────────────────────────────────────────────────────┘"
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

  echo "═══════════════════════════════════════════════════════════════════════════════"
  echo "  To apply these changes, run without --dry-run"
  echo "═══════════════════════════════════════════════════════════════════════════════"
  echo ""

  # Cleanup and exit (reuse cleanup() to avoid duplicating KEEP_TMP_WORKSPACE logic)
  cleanup
  exit 0
fi

# Process all path mappings
# For multi-path migrations, we:
# 1. Process the first mapping on the current branch
# 2. For subsequent mappings, reset to original state, process on a temp branch, then merge
INTEGRATION_BRANCH="__gitmux_integration__"
MAPPING_COUNT=${#PATH_MAPPINGS[@]}

log_info "📂 Processing ${MAPPING_COUNT} path mapping(s)..."

for ((mapping_idx = 0; mapping_idx < MAPPING_COUNT; mapping_idx++)); do
  # Parse the current mapping
  if ! parse_path_mapping "${PATH_MAPPINGS[mapping_idx]}"; then
    errxit "Failed to parse path mapping at index ${mapping_idx}: ${PATH_MAPPINGS[mapping_idx]}"
  fi
  current_source="$PARSED_SOURCE"
  current_dest="$PARSED_DEST"

  if [[ $mapping_idx -eq 0 ]]; then
    # First mapping: process directly on current branch
    log "Processing first mapping on main branch..."
    if ! process_single_mapping "$current_source" "$current_dest" "$mapping_idx" "$MAPPING_COUNT"; then
      errxit "Failed to process mapping $(( mapping_idx + 1 )): '${current_source:-<root>}' -> '${current_dest:-<root>}'"
    fi

    # Create integration branch from the result
    if ! git checkout -b "${INTEGRATION_BRANCH}"; then
      errxit "Failed to create integration branch '${INTEGRATION_BRANCH}'"
    fi
    log_info "🌿 Created integration branch: ${INTEGRATION_BRANCH}"
  else
    # Subsequent mappings: reset to original, process on temp branch, merge
    log "Processing mapping $(( mapping_idx + 1 )) on temporary branch..."

    # Create a temp branch for this mapping
    TEMP_BRANCH="__gitmux_mapping_${mapping_idx}__"

    # Reset to original state
    if ! git checkout --force "${ORIGINAL_HEAD}"; then
      errxit "Failed to checkout original HEAD '${ORIGINAL_HEAD}'"
    fi
    if ! git checkout -b "${TEMP_BRANCH}"; then
      errxit "Failed to create temporary branch '${TEMP_BRANCH}'"
    fi

    # Remove filter-branch backup refs to allow re-running filter-branch
    # Use process substitution to avoid subshell issues with pipelines
    _ref_delete_output=""
    if refs_to_delete=$(git for-each-ref --format='%(refname)' refs/original/ 2>&1); then
      if [[ -n "$refs_to_delete" ]]; then
        while IFS= read -r ref; do
          if [[ -n "$ref" ]] && ! _ref_delete_output=$(git update-ref -d "$ref" 2>&1); then
            log_warn "Failed to delete backup ref: $ref"
            log_debug "Error: ${_ref_delete_output}"
          fi
        done <<< "$refs_to_delete"
      fi
    fi

    # Process this mapping
    if ! process_single_mapping "$current_source" "$current_dest" "$mapping_idx" "$MAPPING_COUNT"; then
      errxit "Failed to process mapping $(( mapping_idx + 1 )): '${current_source:-<root>}' -> '${current_dest:-<root>}'"
    fi

    # Merge into integration branch
    if ! git checkout "${INTEGRATION_BRANCH}"; then
      errxit "Failed to checkout integration branch '${INTEGRATION_BRANCH}'"
    fi
    log "Merging mapping $(( mapping_idx + 1 )) into integration branch..."

    # Use --allow-unrelated-histories since each filter-branch creates independent history
    _merge_output=""
    if ! git merge --allow-unrelated-histories -m "Merge mapping $(( mapping_idx + 1 )): ${current_source:-<root>} -> ${current_dest:-<root>}" "${TEMP_BRANCH}"; then
      # Merge conflict: auto-resolve by preferring incoming changes (theirs)
      # This is appropriate because each mapping targets different destination paths,
      # so conflicts indicate the temp branch has the desired new content.
      # Note: This may overwrite integration branch changes to conflicting files.
      log_info "⚡ Merge conflict detected for mapping $(( mapping_idx + 1 )). Resolving with --theirs strategy..."
      if ! _merge_output=$(git checkout --theirs . 2>&1); then
        log_error "Failed to checkout --theirs. Complex conflict requires manual resolution."
        log_error "Git error: ${_merge_output}"
        log_error "Workspace: ${_WORKSPACE}"
        errxit "Merge resolution failed"
      fi
      # Use 'git add .' to stage all changes including new files from --theirs
      # (git add --update would miss new files, causing incomplete merges)
      if ! _merge_output=$(git add . 2>&1); then
        log_error "Failed to stage resolved files."
        log_error "Git error: ${_merge_output}"
        errxit "Merge resolution failed"
      fi
      if ! _merge_output=$(git commit -m "Merge mapping $(( mapping_idx + 1 )): ${current_source:-<root>} -> ${current_dest:-<root>}" 2>&1); then
        log_error "Failed to commit merge resolution."
        log_error "Git error: ${_merge_output}"
        errxit "Merge resolution failed"
      fi
      log_info "✅ Merge conflict resolved using --theirs strategy."
    fi

    # Clean up temp branch
    _cleanup_output=""
    if ! _cleanup_output=$(git branch -D "${TEMP_BRANCH}" 2>&1); then
      log_warn "Failed to delete temporary branch '${TEMP_BRANCH}'"
      log_debug "Git error: ${_cleanup_output}"
    fi
    log "Merged and cleaned up temporary branch."
  fi
done

log_info "✅ All ${MAPPING_COUNT} mapping(s) processed successfully!"
log "$(git status)"
log "Adding 'destination' remote --> ${destination_repository}"
if ! git remote add destination "${destination_repository}"; then
  errxit "Failed to add destination remote. A remote named 'destination' may already exist from a previous run."
fi

DESTINATION_PR_BRANCH_NAME="update-from-${GIT_BRANCH}-${GIT_SHA}"
if [[ -n "${_append_to_pr_branch_name}" ]]; then
  DESTINATION_PR_BRANCH_NAME="${DESTINATION_PR_BRANCH_NAME}-rebase-strategy-${_append_to_pr_branch_name}"
fi

# Rename integration branch to the PR branch name
if ! git branch -m "${INTEGRATION_BRANCH}" "${DESTINATION_PR_BRANCH_NAME}"; then
  log_error "Failed to rename integration branch to '${DESTINATION_PR_BRANCH_NAME}'"
  log_error "A branch with this name may already exist from a previous run."
  errxit "Branch rename failed"
fi
log_info "🏷️  Renamed integration branch to: ${DESTINATION_PR_BRANCH_NAME}"
log "Status after processing mappings:"
log "$(git status)"
# Must exist in order to set-upstream-to.
# git branch --set-upstream-to=destination/${DESTINATION_PR_BRANCH_NAME}


# Fetch commits from the destination remote
log_info "🔄 Fetching destination remote..."
if ! _repo_existence="$(git fetch destination 2>&1)"; then
  log "Destination repository (${destination_repository}) doesn't exist. If -c supplied, create it"
  if [ "${CREATE_NEW_REPOSITORY}" = true ] && [[ "${_repo_existence}" =~ "Repository not found" ]]; then

    ########## <GH CREATE REPO> ################
    # `gh repo create` runs from inside a git repository. (weird)
    log_info "🆕 Creating new repository: ${destination_owner}/${destination_project}"
    NEW_REPOSITORY_DESCRIPTION="New repository from ${source_url} (${MAPPING_COUNT} path mapping(s))"
    # gh repo create [<name>] [flags]
    TMPGHCREATEWORKDIR=$(mktemp -t 'gitmux-gh-create-destination-XXXXXX' -d || errxit "Failed to create tmpdir.")
    # Note: If you want to move the --orphan bits below, remove --bare from the next line.
    _pushd "${TMPGHCREATEWORKDIR}"
    # TODO: Make --private possible
    if ! gh repo create "${destination_owner}/${destination_project}" --public --license=unlicense --gitignore 'VVVV' --clone --description "${NEW_REPOSITORY_DESCRIPTION}"; then
      errxit "Failed to create destination repository: ${destination_owner}/${destination_project}"
    fi
    _pushd "${destination_project}"
    # Configure git to use gh CLI for authentication (needed for git push)
    if ! gh auth setup-git; then
      errxit "Failed to configure git authentication via gh CLI"
    fi
    git remote --verbose show
    # Rename default branch to trunk (gitmux convention) if needed
    _current_branch=$(git branch --show-current)
    if [[ "${_current_branch}" != "${destination_branch}" ]]; then
      log "Renaming branch ${_current_branch} to ${destination_branch}"
      git branch -m "${destination_branch}"
      if ! git push origin "${destination_branch}:${destination_branch}"; then
        errxit "Failed to push initial branch to new repository"
      fi
      if ! gh repo edit "${destination_owner}/${destination_project}" --default-branch "${destination_branch}"; then
        log_warn "Failed to set default branch to '${destination_branch}'. You may need to set it manually."
      fi
    fi
    _popd && _popd
    log "cleaning up gh-create workdir"
    rm -rf "${TMPGHCREATEWORKDIR}"
    ########## </GH CREATE REPO> ################

    log "Attempting (again) to fetch remote 'destination' --> ${destination_repository}"
    if ! git fetch destination; then
      errxit "Failed to fetch from newly created destination repository"
    fi
    # Our brand new repo destination branch needs at least one commit (to be the base branch of a PR).
    # This will also help remind us where this repository came from.
    git status
    # A local 'trunk' branch probably already exists
    if ! git checkout -b "gitmux-dest-${destination_branch}" destination/trunk; then
      errxit "Failed to checkout destination branch from new repository"
    fi
    if ! git pull destination trunk; then
      errxit "Failed to pull from destination trunk"
    fi
    # Unstage everything (from ${DESTINATION_PR_BRANCH_NAME})
    if ! _rm_output=$(git rm -r --cached . 2>&1); then
      log_warn "Could not clear staging area: ${_rm_output}"
      # Non-fatal - continue with empty commit
    fi
    git status
    log "Creating empty commit for its own sake"
    if ! git commit --message 'Hello: this repository was created by gitmux.' --allow-empty; then
      log_warn "Failed to create initial commit - continuing anyway"
    fi
    if ! git push destination "gitmux-dest-${destination_branch}:trunk"; then
      errxit "Failed to push initial commit to destination repository"
    fi
    # Now go back to the build branch.
    log "Going back to build branch --> ${DESTINATION_PR_BRANCH_NAME}"
    if ! git checkout --force "${DESTINATION_PR_BRANCH_NAME}"; then
      errxit "Failed to checkout build branch '${DESTINATION_PR_BRANCH_NAME}'"
    fi
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
    log_info "🎛️  Interactive rebase detected."
    if ! git rebase "${REBASE_OPTIONS}" "destination/${destination_branch}"; then
      log_error "Interactive rebase failed or was aborted."
      log_info "📂 Navigate to the temp workspace to resolve manually:"
      log_info "   cd ${_WORKSPACE}"
      return 1
    fi
    log_info "✅ Rebase completed successfully!"
    log_info "📋 After rebasing, you may want to run:"
    log_info "   git push destination ${DESTINATION_PR_BRANCH_NAME}"
    log_info "📂 Navigate to the temp workspace to complete the workflow:"
    log_info "   cd ${_WORKSPACE}"
  elif ! output="$(git rebase ${REBASE_OPTIONS} "destination/${destination_branch}" 2>&1)"; then
    # Handle rebase failures: check for common error patterns and attempt recovery
    if [[ "${output}" =~ "invalid upstream" ]]; then
      log_error "${output}"
      errxit "Invalid upstream. Does '${destination_branch}' exist in '${destination_repository}'?"
    elif [[ "${output}" =~ ^fatal ]]; then
      log_error '📛 Something went wrong during rebase.'
      log_debug "${output}"
      return 1
    fi
    log_debug "${output}"
    log_warn "⚠️  Rebase incomplete, trying to --continue..."
    n=1
    while (( n < MAX_RETRIES )) && ! output="$(git rebase --continue 2>&1)";do
      log_debug "───────────────────────────────────────────────"
      log_debug "${output}"
      if [[ "${output}" =~ "needs merge" ]]; then
        log_info "🔀 Renamed/unchanged files need merge, using git add --all"
        export GIT_EDITOR=true
        git add --all
      elif [[ "${output}" =~ "If you wish to commit it anyway" ]]; then
        log_info "📝 Committing anyway with git commit --allow-empty --no-edit"
        git commit --allow-empty --no-edit
      elif [[ "${output}" =~ ^fatal ]]; then
        log_error '📛 Something went wrong during rebase.'
        log_debug "${output}"
        return 1
      fi
      log_warn "🔄 [${n}/${MAX_RETRIES}] Trying to --continue again..."
      (( n += 1 ))
      git rebase --continue && break
      log_debug "───────────────────────────────────────────────"
    done
    if (( n > MAX_RETRIES )); then
      log_error "❌ Max retries exceeded on rebase. Aborting."
      git rebase --abort
      log_debug "${output}"
      return 1
    fi

    log_info "✅ Rebase completed successfully after retry!"
    log_info "🚀 Pushing to branch ${DESTINATION_PR_BRANCH_NAME}..."
    if ! _push_output=$(git push --force-with-lease --tags destination 2>&1); then
      log_error "Failed to push tags to destination"
      log_debug "Git error: ${_push_output}"
      return 1
    fi
    if ! _push_output=$(git push --follow-tags --progress --atomic --verbose --force-with-lease destination "${DESTINATION_PR_BRANCH_NAME}" 2>&1); then
      log_error "Failed to push branch '${DESTINATION_PR_BRANCH_NAME}' to destination"
      log_debug "Git error: ${_push_output}"
      return 1
    fi
  else
    # rebase in elif condition succeeded
    log_info "✅ Rebase completed successfully!"
    log_info "🚀 Pushing to branch ${DESTINATION_PR_BRANCH_NAME}..."
    if ! _push_output=$(git push --force-with-lease --tags destination 2>&1); then
      log_error "Failed to push tags to destination"
      log_debug "Git error: ${_push_output}"
      return 1
    fi
    if ! _push_output=$(git push --follow-tags --progress --atomic --verbose --force-with-lease destination "${DESTINATION_PR_BRANCH_NAME}" 2>&1); then
      log_error "Failed to push branch '${DESTINATION_PR_BRANCH_NAME}' to destination"
      log_debug "Git error: ${_push_output}"
      return 1
    fi
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

# Build path mappings table for PR description
_path_mappings_table="| Source | Destination |
|--------|-------------|"
for mapping in "${PATH_MAPPINGS[@]}"; do
  parse_path_mapping "$mapping"
  _path_mappings_table="${_path_mappings_table}
| \`${PARSED_SOURCE:-<root>}\` | \`${PARSED_DEST:-<root>}\` |"
done

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
  "" \
  "## Path mappings" \
  "${_path_mappings_table}" \
  "" \
  "## Destination repository details" \
  "Destination URL: [\`${_canonical_destination_https_url}\`](${_canonical_destination_https_url})" \
  "PR Branch at Destination (head): \`${DESTINATION_PR_BRANCH_NAME}\`" \
  "Destination branch (base): \`${DESTINATION_BRANCH}\`" \
  "" \
  "------------------------------" \
)

if _cmd_exists gh && [ "${SUBMIT_PR}" = true ]; then
  log_info "📤 Submitting pull request..."
  if ! _pr_output=$(gh pr --repo "${destination_domain}/${destination_owner}/${destination_project}" \
    create \
    --title "${PR_TITLE}" \
    --body "${PR_DESCRIPTION}" \
    --assignee @me \
    --base "${destination_branch}" \
    --head "${destination_owner}:${DESTINATION_PR_BRANCH_NAME}" 2>&1); then
    log_error "Failed to create pull request"
    log_error "gh error: ${_pr_output}"
    log_info "📋 You can manually create the PR for branch ${DESTINATION_PR_BRANCH_NAME}"
    errxit "PR creation failed"
  fi
  log_info "✅ Pull request created successfully!"
else
  log_info "📋 Please manually submit PR for branch ${DESTINATION_PR_BRANCH_NAME} to ${destination_repository}"
  log_info "Auto-generated pull request description:"
  echo "${PR_DESCRIPTION}" >&2
fi

log_info "🎉 gitmux sync complete!"

_popd && _popd && cleanup
