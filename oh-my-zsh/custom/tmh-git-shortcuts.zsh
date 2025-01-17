resolve_master_branch() {
    if git rev-parse --verify origin/master >/dev/null 2>&1; then
        echo "master"
    elif git rev-parse --verify origin/main >/dev/null 2>&1; then
        echo "main"
    else
        echo "Error: Neither 'master' nor 'main' branch found in origin." >&2
        return 1
    fi
}

# vclean        delete all remote branches except for origin/master and origin/main
vclean() {
    git branch -r | grep 'origin/' | grep -Ev 'origin/(master|main)$' | sed 's/origin\///' | xargs -I {} git branch -r -d origin/{}
    echo ">>> $(date +"%Y-%m-%d %H:%M:%S") Cleaned up remote branches ====="
}

# vpull        update the local master, and merge with the current branch
vpull() {
    local master
    master=$(resolve_master_branch) || return 1 
    git fetch origin "$master:$master"
    git merge "$master" --no-edit
    echo ">>> $(date +"%Y-%m-%d %H:%M:%S") Merged with the latest $master"
}

# vupdate        update the local master
vupdate() {
    local master
    master=$(resolve_master_branch) || return 1 
    git fetch origin "$master:$master"
    echo ">>> $(date +"%Y-%m-%d %H:%M:%S") $master updated"
}

##
# vcheckout test-branch         update the local master. If test-branch doesn't exist, create it off the latest master
# vcheckout test-branch         update the local master, If test-branch exists, merge with the last master, then switch
# vcheckout test-branch -off    The -off flag skips the master update in case it takes too long, or internet is unavailable
vcheckout() {
    local target_branch="$1"  # Get the branch name from the first argument
    local skip_fetch="$2"     # Get the optional second argument (-off)

    local master
    master=$(resolve_master_branch) || return 1 

    # Skip fetch if the -off flag is passed
    if [[ "$skip_fetch" != "-off" && "$skip_fetch" != "-o" ]]; then
        git fetch origin "$master:$master"
    else
        echo ">>> Skipping fetch due to -off flag"
    fi

    if git rev-parse --verify "$target_branch" >/dev/null 2>&1; then
        # Branch exists, merge master into it
        git merge "$master" "$target_branch"
        git checkout "$target_branch"
        echo ">>> $(date +"%Y-%m-%d %H:%M:%S") $target_branch branch checked out"
    else
        # Branch doesn't exist, create it off master
        git checkout -b "$target_branch" "$master"
        echo ">>> $(date +"%Y-%m-%d %H:%M:%S") $target_branch branch created"
    fi
}
