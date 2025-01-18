# description: figure out if the main branch is either master or main
_resolve_master() {
    if git rev-parse --verify origin/master >/dev/null 2>&1; then
        echo "master"
    elif git rev-parse --verify origin/main >/dev/null 2>&1; then
        echo "main"
    else
        echo "Error: Neither 'master' nor 'main' branch found in origin." >&2
        return 1
    fi
}

# description: enable branch autocompletion
# complete -F _branch_autocomplete vcheckout  --- enable autocompletion for vcheckout
_branch_autocomplete() {
    # Use git's branch completion for the first argument
    local cur_word="${COMP_WORDS[COMP_CWORD]}"
    local branches
    branches=$(git branch --all | sed 's/^[* ]*//; s/remotes\/origin\///' | sort -u)

    COMPREPLY=($(compgen -W "$branches" -- "$cur_word"))
}

# vclean        delete all remote branches except for origin/master and origin/main
vclean() {
    git branch -r | grep 'origin/' | grep -Ev 'origin/(master|main)$' | sed 's/origin\///' | xargs -I {} git branch -r -d origin/{}
    git tag -d $(git tag)
    echo ">>> $(date +"%Y-%m-%d %H:%M:%S") Cleaned up remote branches/tags ====="
}

# vpull        update the local master, and merge with the current branch
vpull() {
    local master
    master=$(_resolve_master) || return 1 
    git fetch origin "$master:$master" --no-tags
    git merge "$master" --no-edit
    echo ">>> $(date +"%Y-%m-%d %H:%M:%S") Merged with the latest $master"
}

# vpull        update the local master
vupdate() {
    local master
    master=$(_resolve_master) || return 1 
    git fetch origin "$master:$master" --no-tags
    echo ">>> $(date +"%Y-%m-%d %H:%M:%S") $master updated"
}

##
# vcheckout test-branch             update the local master. If test-branch doesn't exist, create it off the latest master
# vcheckout test-branch             update the local master, If test-branch exists, merge with the last master, then switch
# vcheckout test-branch -off        The -off flag skips the master update in case it takes too long, or internet is unavailable
# vcheckout test-branch -cur        The -cur flag performs creating/merging the test-branch with the current branch
# vcheckout test-branch -c -o       The -o, -c are short forms of -off, -cur. They can be inputted in any order as long as after the branch
vcheckout() {
    local target_branch="$1" # Get the branch name from the first argument
    shift                    # Shift to handle the rest of the arguments (flags)

    local skip_fetch=false   # Default: fetch is not skipped
    local use_current=false  # Default: do not use the current branch

    # Parse flags
    while [[ $# -gt 0 ]]; do
        case "$1" in
            -off|-o)
                skip_fetch=true
                ;;
            -cur|-c)
                use_current=true
                ;;
            *)
                echo ">>> Unknown option: $1"
                return 1
                ;;
        esac
        shift
    done

    # Resolve master branch
    local master
    master=$(_resolve_master) || return 1

    # Skip fetch if -off flag is set
    if ! $skip_fetch; then
        git fetch origin "$master:$master" --no-tags
    else
        echo ">>> Skipping fetch due to -off flag"
    fi

    # Handle -cur flag
    if $use_current; then
        local current_branch
        current_branch=$(git rev-parse --abbrev-ref HEAD)

        # Merge master into the current branch
        git merge "$master" "$current_branch" || return 1
        echo ">>> $(date +"%Y-%m-%d %H:%M:%S") Merged $master into $current_branch"

        # Handle target branch
        if git rev-parse --verify "$target_branch" >/dev/null 2>&1; then
            # Target branch exists, merge the current branch into it
            git merge "$current_branch" "$target_branch"
            git checkout "$target_branch"
            echo ">>> $(date +"%Y-%m-%d %H:%M:%S") Merged $current_branch into $target_branch and checked out"
        else
            # Target branch doesn't exist, create it off the current branch
            git checkout -b "$target_branch" "$current_branch"
            echo ">>> $(date +"%Y-%m-%d %H:%M:%S") $target_branch branch created off $current_branch and checked out"
        fi
        return 0
    fi

    # Default behavior (without -cur)
    if git rev-parse --verify "$target_branch" >/dev/null 2>&1; then
        # Target branch exists, merge master into it
        git merge "$master" "$target_branch"
        git checkout "$target_branch"
        echo ">>> $(date +"%Y-%m-%d %H:%M:%S") Merged $master into $target_branch and checked out"
    else
        # Target branch doesn't exist, create it off master
        git checkout -b "$target_branch" "$master"
        echo ">>> $(date +"%Y-%m-%d %H:%M:%S") $target_branch branch created off $master and checked out"
    fi
}

# Register the completion function for vcheckout
complete -F _branch_autocomplete vcheckout
