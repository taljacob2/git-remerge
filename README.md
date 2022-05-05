> v1.0.0

# git-remerge

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
