> v1.0.1

# git-remerge

An addition for `git merge` to be able to re-calculate the "merge", when two branches have already been merged. `git remerge` will first perform a normal `merge`, and afterwards, will re-calculate the conflicted files.

## Why Use `git remerge`

Sometimes `git merge` will output a `"Already up-to-date"` message, even though there is actually a difference between some of the files, when you `git diff` them manually. So in this case, we need a tool that will perform a `git merge` as usual, but for those files with the actual difference we want git to **re-calculate** the conflicts between them, so we could re-merge them.

## Installation

### Clone This Repository As A Subtree In Your Project

Merge this repository to a new folder called `git-remerge` at the root folder of your project:
```
git subtree add -P git-remerge https://github.com/taljacob2/git-remerge master --squash
```

### Configure The Alias Of `git remerge`

Run the following command:
```
git config alias.remerge '!sh ./git-remerge/git-remerge.sh "${args[@]}"'
```

## How To Use

```
git remerge <FEATURE-BRANCH-NAME>
```

## Check For Updates

In case you already have an existing version of "git-remerge" and you want to update to the newest version available, you can merge the newest version of this repository to your existing `git-remerge` folder:
```
git subtree pull -P git-remerge https://github.com/taljacob2/git-remerge master --squash
```
