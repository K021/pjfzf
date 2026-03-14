#!/usr/bin/env zsh
# pj - Project directory navigator with fuzzy finding
# https://github.com/<user>/pjfzf

zmodload -F zsh/datetime b:strftime p:EPOCHSECONDS 2>/dev/null

# --- Configuration -----------------------------------------------------------

_PJ_CONFIG_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/pj"
_PJ_CONFIG_FILE="${_PJ_CONFIG_DIR}/config"
_PJ_HISTORY_FILE="${_PJ_CONFIG_DIR}/history"

# --- Internal helpers ---------------------------------------------------------

# Ensure config directory and default config exist
_pj_init() {
  if [[ ! -d "$_PJ_CONFIG_DIR" ]]; then
    mkdir -p "$_PJ_CONFIG_DIR"
  fi
  if [[ ! -f "$_PJ_CONFIG_FILE" ]]; then
    echo "$HOME/projects" > "$_PJ_CONFIG_FILE"
  fi
  if [[ ! -f "$_PJ_HISTORY_FILE" ]]; then
    touch "$_PJ_HISTORY_FILE"
  fi
}

# Collect base dirs + their 1-depth subdirectories
_pj_list() {
  _pj_init
  local line expanded
  while IFS= read -r line || [[ -n "$line" ]]; do
    # skip empty lines and comments
    [[ -z "$line" || "$line" == \#* ]] && continue
    # expand tilde
    expanded="${line/#\~/$HOME}"
    if [[ -d "$expanded" ]]; then
      echo "$expanded"
      for d in "$expanded"/*(N/); do
        echo "$d"
      done
    fi
  done < "$_PJ_CONFIG_FILE"
}

# Calculate frecency score for a given path
# Arguments: $1=last_access_epoch  $2=access_count
_pj_score() {
  local last_access=$1 count=$2
  local now=${EPOCHSECONDS:-$(date +%s)}
  local age=$(( now - last_access ))
  local weight=1

  if (( age < 3600 )); then         # 1 hour
    weight=16
  elif (( age < 86400 )); then      # 1 day
    weight=8
  elif (( age < 604800 )); then     # 1 week
    weight=4
  elif (( age < 2592000 )); then    # 1 month
    weight=2
  fi

  echo $(( count * weight ))
}

# Output sorted directory list: history entries by frecency desc, then rest alphabetically
_pj_sorted() {
  _pj_init
  local -A hist_score  # path -> score
  local -A hist_seen   # path -> 1

  # Read history and compute scores
  if [[ -s "$_PJ_HISTORY_FILE" ]]; then
    local name fpath epoch count
    while IFS='|' read -r name fpath epoch count || [[ -n "$name" ]]; do
      [[ -z "$fpath" ]] && continue
      [[ ! -d "$fpath" ]] && continue
      local score=$(_pj_score "$epoch" "$count")
      hist_score[$fpath]=$score
      hist_seen[$fpath]=1
    done < "$_PJ_HISTORY_FILE"
  fi

  # Collect all directories
  local -a all_dirs
  all_dirs=("${(@f)$(_pj_list)}")

  # Separate into scored and unscored
  local -a scored unsorted
  for d in "${all_dirs[@]}"; do
    [[ -z "$d" ]] && continue
    if [[ -n "${hist_seen[$d]}" ]]; then
      scored+=("${hist_score[$d]}|$d")
    else
      unsorted+=("$d")
    fi
  done

  # Sort scored by score descending
  if (( ${#scored} > 0 )); then
    printf '%s\n' "${scored[@]}" | sort -t'|' -k1 -nr | cut -d'|' -f2-
  fi

  # Sort unsorted alphabetically
  if (( ${#unsorted} > 0 )); then
    printf '%s\n' "${unsorted[@]}" | sort
  fi
}

# Update history file after cd
_pj_update() {
  local target="$1"
  local name="${target:t}"  # basename
  local now=${EPOCHSECONDS:-$(date +%s)}
  local -a new_lines
  local found=0

  if [[ -s "$_PJ_HISTORY_FILE" ]]; then
    local hname hpath hepoch hcount
    while IFS='|' read -r hname hpath hepoch hcount || [[ -n "$hname" ]]; do
      if [[ "$hpath" == "$target" ]]; then
        found=1
        new_lines+=("${name}|${target}|${now}|$(( hcount + 1 ))")
      else
        [[ -n "$hpath" ]] && new_lines+=("${hname}|${hpath}|${hepoch}|${hcount}")
      fi
    done < "$_PJ_HISTORY_FILE"
  fi

  if (( ! found )); then
    new_lines+=("${name}|${target}|${now}|1")
  fi

  printf '%s\n' "${new_lines[@]}" > "$_PJ_HISTORY_FILE"
}

# --- Subcommands --------------------------------------------------------------

_pj_add_base() {
  local new_path="$1"
  if [[ -z "$new_path" ]]; then
    echo "Usage: pj add <path>" >&2
    return 1
  fi

  _pj_init

  # Expand tilde and resolve
  new_path="${new_path/#\~/$HOME}"
  new_path="${new_path:A}"  # resolve to absolute

  if [[ ! -d "$new_path" ]]; then
    echo "pj: directory not found: $new_path" >&2
    return 1
  fi

  # Check for duplicates
  local line expanded
  while IFS= read -r line || [[ -n "$line" ]]; do
    [[ -z "$line" || "$line" == \#* ]] && continue
    expanded="${line/#\~/$HOME}"
    expanded="${expanded:A}"
    if [[ "$expanded" == "$new_path" ]]; then
      echo "pj: already registered: $new_path" >&2
      return 1
    fi
  done < "$_PJ_CONFIG_FILE"

  echo "$new_path" >> "$_PJ_CONFIG_FILE"
  echo "pj: added $new_path"
}

_pj_remove_base() {
  local rm_path="$1"
  if [[ -z "$rm_path" ]]; then
    echo "Usage: pj remove <path>" >&2
    return 1
  fi

  _pj_init

  rm_path="${rm_path/#\~/$HOME}"
  rm_path="${rm_path:A}"

  local -a new_lines
  local found=0
  local line expanded
  while IFS= read -r line || [[ -n "$line" ]]; do
    [[ -z "$line" ]] && continue
    if [[ "$line" == \#* ]]; then
      new_lines+=("$line")
      continue
    fi
    expanded="${line/#\~/$HOME}"
    expanded="${expanded:A}"
    if [[ "$expanded" == "$rm_path" ]]; then
      found=1
    else
      new_lines+=("$line")
    fi
  done < "$_PJ_CONFIG_FILE"

  if (( ! found )); then
    echo "pj: not found in config: $rm_path" >&2
    return 1
  fi

  printf '%s\n' "${new_lines[@]}" > "$_PJ_CONFIG_FILE"
  echo "pj: removed $rm_path"
}

_pj_show_config() {
  _pj_init
  echo "Base directories:"
  local line
  while IFS= read -r line || [[ -n "$line" ]]; do
    [[ -z "$line" || "$line" == \#* ]] && continue
    echo "  $line"
  done < "$_PJ_CONFIG_FILE"
}

_pj_help() {
  cat <<'EOF'
pj - Project directory navigator

Usage:
  pj              Select project interactively with fzf
  pj <query>      Select project with initial search query
  pj add <path>   Add a base directory
  pj remove <path> Remove a base directory
  pj list         Show registered base directories
  pj help         Show this help message

Config: ~/.config/pj/config
History: ~/.config/pj/history
EOF
}

# --- Main function ------------------------------------------------------------

pj() {
  # Check fzf dependency
  if ! command -v fzf &>/dev/null; then
    echo "pj: fzf is required. Install with: brew install fzf" >&2
    return 1
  fi

  _pj_init

  case "${1:-}" in
    add)
      _pj_add_base "$2"
      return $?
      ;;
    remove)
      _pj_remove_base "$2"
      return $?
      ;;
    list)
      _pj_show_config
      return 0
      ;;
    help)
      _pj_help
      return 0
      ;;
  esac

  local query="${*:-}"

  # Direct absolute path: cd without fzf (used by Tab widget)
  if [[ "$query" == /* && -d "$query" ]]; then
    cd "$query" || return 1
    _pj_update "$query"
    return 0
  fi

  local selected
  selected=$(_pj_sorted | fzf \
    --query="$query" \
    --select-1 \
    --exit-0 \
    --preview 'ls -la {}' \
    --preview-window=right:40% \
    --height=40% \
    --reverse \
    --prompt='pj> '
  )

  if [[ -n "$selected" ]]; then
    cd "$selected" || return 1
    _pj_update "$selected"
  fi
}

# --- pjmk: create project directory -------------------------------------------

# List only base directories
_pj_base_dirs() {
  _pj_init
  local line expanded
  while IFS= read -r line || [[ -n "$line" ]]; do
    [[ -z "$line" || "$line" == \#* ]] && continue
    expanded="${line/#\~/$HOME}"
    [[ -d "$expanded" ]] && echo "$expanded"
  done < "$_PJ_CONFIG_FILE"
}

pjmk() {
  if ! command -v fzf &>/dev/null; then
    echo "pjmk: fzf is required. Install with: brew install fzf" >&2
    return 1
  fi

  _pj_init

  local name="${1:-}"

  # 1. Select base directory
  local base
  base=$(_pj_base_dirs | fzf \
    --height=40% \
    --reverse \
    --prompt='base> ' \
    --select-1 \
    --exit-0 \
  )

  if [[ -z "$base" ]]; then
    return 0
  fi

  # 2. Read project name if not given as argument
  if [[ -z "$name" ]]; then
    echo -n "Project name: "
    read -r name
  fi

  if [[ -z "$name" ]]; then
    echo "pjmk: name required" >&2
    return 1
  fi

  local target="${base}/${name}"

  if [[ -d "$target" ]]; then
    echo "pjmk: already exists: $target" >&2
    return 1
  fi

  mkdir -p "$target"
  cd "$target" || return 1
  _pj_update "$target"
  echo "pjmk: created $target"
}

# --- Tab completion (zle widget + fzf) ----------------------------------------

# Subcommand completion only (for pj add/remove <Tab>)
_pj() {
  case "${words[2]}" in
    add|remove)
      (( CURRENT >= 3 )) && _directories
      ;;
  esac
}

# Tab handler: intercept "pj " to launch fzf, otherwise default completion
_pj_fzf_complete() {
  # Only intercept when buffer starts with "pj " (with space)
  if [[ "${LBUFFER}" != "pj "* ]]; then
    zle expand-or-complete
    return
  fi

  local tokens=(${(z)LBUFFER})

  # Subcommands: fall back to default completion
  if (( ${#tokens} >= 2 )) && [[ "${tokens[2]}" == (add|remove|list|help)* ]]; then
    zle expand-or-complete
    return
  fi

  local query=""
  (( ${#tokens} >= 2 )) && query="${tokens[2]}"

  local selected
  selected=$(_pj_sorted | fzf \
    --height=40% \
    --reverse \
    --prompt='pj> ' \
    --select-1 \
    --exit-0 \
    --preview 'ls -la {}' \
    --preview-window=right:40% \
    --query="$query" \
  )

  if [[ -n "$selected" ]]; then
    cd "$selected" 2>/dev/null && _pj_update "$selected"
    BUFFER=""
  fi
  zle reset-prompt
}

zle -N _pj_fzf_complete
bindkey '^I' _pj_fzf_complete

if (( $+functions[compdef] )); then
  compdef _pj pj
fi
