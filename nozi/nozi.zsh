#                 _
#  _ __   ___ ___(_)
# | '_ \ / _ \_  / |
# | | | | (_) / /| |
# |_| |_|\___/___|_|
#
# https://github.com/agkozak/dotfiles/nozi
#
# MIT License
#
# Copyright (c) 2021 Alexandros Kozak

# Find directory where the nozi.zsh script is
#
# Standarized $0 handling
# (See https://github.com/zdharma/Zsh-100-Commits-Club/blob/master/Zsh-Plugin-Standard.adoc)
0=${${ZERO:-${0:#$ZSH_ARGZERO}}:-${(%):-%N}}
NOZI_DIR=${${${(M)0:#/*}:-$PWD/$0}:A:h}

# This script requires Git
! (( ${+commands[git]} )) &&
  >&2 print 'nozi: Git not installed. Exiting...' &&
  return

# This script should not run if Zinit has been loaded
(( ${+functions[zinit]} )) &&
  >&2 print 'nozi: zinit function already loaded. Exiting...' &&
  return

# nozi provides a subset of Zinit's capabilities
nozi() {

  # Use Zinit custom paths, if they have been specified
  local home_dir plugins_dir snippets_dir
  home_dir=${ZINIT[HOME_DIR]:-${HOME}/.zinit}
  plugins_dir=${ZINIT[PLUGINS_DIR]:-${home_dir}/plugins}
  snippets_dir=${ZINIT[SNIPPETS_DIR]:-${home_dir}/snippets}

  typeset -gA NOZI
  typeset -ga NOZI_PLUGINS NOZI_SNIPPETS
  local orig_dir=$PWD i j
  local branch=${NOZI[BRANCH]} && NOZI[BRANCH]=''

  # Compile scripts to wordcode when necessary
  _nozi_zcompare() {
    while [[ $# > 0 ]]; do
      if [[ -s $1 && ( ! -s ${1}.zwc || $1 -nt ${1}.zwc) ]]; then
        zcompile $1
      fi
      shift
    done
  }

  case $1 in

    # The beginnings of a help command
    -h|--help|help)
      >&2 print -- '-h|--help|help    - usage information'
      >&2 print -- "ice               - add ICE to next command, e.g. ice ver'develop'"
      >&2 print -- 'load|light        - load plugin'
      >&2 print -- 'snippet           - source a snippet from Oh-My-ZSH'
      >&2 print -- 'update            - update plugin or snippet (or --all)'
      >&2 print -- 'loaded|list       - show which plugins are loaded'
      >&2 print -- 'ls                - list snippets'
      >&2 print -- 'self-update       - update nozi'
      ;;

    # ice only provides ver'...' at present
    ice)
      shift

      ! (( $# )) && return 1

      while [[ -n $@ ]]; do
        [[ $1 == ver* ]] && NOZI[BRANCH]=${1/ver/}
        shift
      done
      ;;

    # For our purposes, load and light do the same thing
    load|light)
      shift

      ! (( $# )) && return 1

      local repo=$1 repo_dir="${1%/*}---${1#*/}"

      # If a script exists, source it and add it to the plugin list
      _nozi_plugin_source() {
        if [[ -f $1 ]]; then
          source $1 && NOZI_PLUGINS+=( $repo )
        else
          return 1
        fi
      }

      if [[ ! -d "${plugins_dir}/${repo_dir}" ]]; then
          git clone "https://github.com/${repo}" \
            "${plugins_dir}/${repo_dir}"
          cd "${plugins_dir}/${repo_dir}" || exit
          if [[ -n $branch ]]; then
            git checkout $branch
          fi
          _nozi_zcompare *.zsh
          cd $orig_dir || exit
        fi
        _nozi_plugin_source "${plugins_dir}/${repo_dir}/${repo#*/}.plugin.zsh" ||
          _nozi_plugin_source "${plugins_dir}/${repo_dir}/init.zsh" ||
          # TODO: Rewrite
          _nozi_plugin_source ${plugins_dir}/${repo_dir}/*.zsh ||
          _nozi_plugin_source ${plugins_dir}/${repo_dir}/*.sh
        ;;

    # Clone and load snippets
    snippet)
      shift

      ! (( $# )) && return 1

      if [[ $1 == OMZ::* ]]; then
        if [[ ! -f ${snippets_dir}/${1/\//--}/${1##*/} ]]; then
          >&2 print "nozi: Installing snippet $1"
          mkdir -p "${snippets_dir}/${1%%/*}--${1#*/}"
          curl "https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/${1#OMZ::}" \
            > "${snippets_dir}/${1%%/*}--${1#*/}/${1##*/}"
        fi
        _nozi_zcompare "${snippets_dir}/${1%%/*}--${1#*/}/${1##*/}"
        source "${snippets_dir}/${1%%/*}--${1#*/}/${1##*/}" &&
          NOZI_SNIPPETS+=( $1 )
      else
        return 1
      fi
      ;;

    # Update individual plugins and snippets or all of them
    update)
      shift
      
      [[ -d $plugins_dir ]] && cd $plugins_dir || exit

      if [[ $1 == --all ]]; then
        >&2 print 'nozi: Updating all plugins and snippets.'
        for i in *; do
          if [[ $i != _local---zinit && -d ${i}/.git ]]; then
            cd $i || exit
            print -n "nozi: Updating plugin ${${PWD:t}%---*}/${${PWD:t}#*---}: "
            git pull
            _nozi_zcompare *.zsh
            cd .. || exit
          fi
        done
        [[ -d $snippets_dir ]] && cd $snippets_dir || exit
        i=''
        for i in */*/*; do
          [[ $i == *.zwc ]] && continue
          print "nozi: Updating snippet ${${i/--/\/}%/*}"
          nozi snippet ${${i/--/\/}%/*}
          _nozi_zcompare *.zsh
        done
      else
        while (( $# > 0 )); do
          if [[ $1 == OMZ:** ]]; then
            if [[ -f ${snippets_dir}/${1/\//--}/${1##*/} ]]; then
              >&2 print "nozi: Updating snippet $1"
              mkdir -p "${snippets_dir}/${1%%/*}--${1#*/}"
              curl "https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/${1#OMZ::}" \
                > "${snippets_dir}/${1%%/*}--${1#*/}/${1##*/}"
            else
              continue
            fi
            _nozi_zcompare "${snippets_dir}/${1%%/*}--${1#*/}/${1##*/}"
            source "${snippets_dir}/${1%%/*}--${1#*/}/${1##*/}" &&
          else
            local repo=$1 repo_dir="${1%/*}---${1#*/}"
            >&2 print -n "nozi: Updating $repo: "
            [[ -d $repo_dir ]] && cd $repo_dir || exit
            git pull
            _nozi_zcompare *.zsh
            cd .. || exit
            nozi load $repo
          fi
          shift
        done
      fi

      cd $orig_dir || exit
      ;;

    # List loaded plugins
    loaded|list)
      >&2 print 'nozi Plugins:'
      >&2 print -lf '  %s\n' $NOZI_PLUGINS
      ;;

    # List sourced snippets
    ls)
      >&2 print 'nozi Snippets:'
      >&2 print -lf '  %s\n' $NOZI_SNIPPETS
      ;;

    # TODO: Write this eventually.
    self-update)
      if [[ -d $NOZI_DIR ]]; then
        cd $NOZI_DIR || exit
        if [[ -d .git ]]; then
          git pull
        else
          >&2 print "nozi must be in a Git repository for \`self-update' to work"
        fi
        cd $orig_dir
      else
        return 1
      fi
      ;;

    *) return 1 ;;
  esac
}

zinit() { nozi $@; }
zi() { nozi $@; }