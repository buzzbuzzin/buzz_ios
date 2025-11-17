# Git Flow: Common Operations Guide

Git Flow is a branching model that helps structure work on a project. It
adds conventions on top of Git with dedicated commands for features,
releases, and hotfixes.\
This guide explains the most common Git Flow commands used in daily
development.

------------------------------------------------------------------------

## 1. Branch Roles in Git Flow

### **Main branches**

-   **`main`**\
    Always production-ready. Every commit corresponds to a released
    version.

-   **`develop`**\
    Integration branch for ongoing development. Features merge here.

### **Supporting branches**

-   **Feature branches:** `feature/xxx` -- new features\
-   **Release branches:** `release/x.y.z` -- prepare a new version\
-   **Hotfix branches:** `hotfix/x.y.z` -- urgent fixes for production

------------------------------------------------------------------------

## 2. Installing & Initializing Git Flow

### Install git-flow

**Mac (Homebrew):**

``` bash
brew install git-flow-avh
```

**Ubuntu:**

``` bash
sudo apt-get install git-flow
```

### Initialize

Run once per repository:

``` bash
git flow init
```

Press Enter for all defaults unless you need custom names.

------------------------------------------------------------------------

## 3. Working With Feature Branches

### 3.1 Start a feature

``` bash
git checkout develop
git pull
git flow feature start feature-name
```

Creates: `feature/feature-name`

### 3.2 Commit normally

``` bash
git add .
git commit -m "Implement feature"
git push -u origin feature/feature-name
```

### 3.3 Finish the feature

``` bash
git flow feature finish feature-name
```

This will: - Merge into `develop` - Delete the feature branch - Switch
back to `develop`

Push:

``` bash
git push origin develop
```

------------------------------------------------------------------------

## 4. Creating & Finishing a Release

### ⚠ IMPORTANT NOTE ABOUT TAGGING

When you start a release, **DO NOT include the "v" prefix**.\
Example:

    git flow release start 1.0.0

Git Flow will automatically create tag **`v1.0.0`** when finishing the
release.

------------------------------------------------------------------------

### 4.1 Start a release

``` bash
git checkout develop
git pull
git flow release start 1.0.0
```

Creates: `release/1.0.0`

### 4.2 Make release commits

-   Update version numbers\
-   Update changelog\
-   Fix small bugs

``` bash
git add .
git commit -m "Prepare release 1.0.0"
```

Push optional:

``` bash
git push -u origin release/1.0.0
```

### 4.3 Finish the release

``` bash
git flow release finish 1.0.0
```

Git Flow will automatically: - Merge to `main` - Tag **`v1.0.0`** -
Merge `main` → `develop` - Delete release branch locally

Push everything:

``` bash
git push origin main develop --tags
```

------------------------------------------------------------------------

## 5. Hotfixes (Urgent Production Fixes)

### 5.1 Start a hotfix

``` bash
git checkout main
git pull
git flow hotfix start 1.0.1
```

Creates: `hotfix/1.0.1`

### 5.2 Fix and commit

``` bash
git add .
git commit -m "Fix crash bug"
```

Push optional:

``` bash
git push -u origin hotfix/1.0.1
```

### 5.3 Finish the hotfix

``` bash
git flow hotfix finish 1.0.1
```

Git Flow will: - Merge hotfix → `main` - Tag **`v1.0.1`** - Merge fix
into `develop` - Delete hotfix branch locally

Push:

``` bash
git push origin main develop --tags
```

------------------------------------------------------------------------

## 6. Troubleshooting

### 6.1 Merge in progress

If you get:

    Error: a merge is already in progress

Check:

``` bash
git status
```

Abort merge:

``` bash
git merge --abort
```

Or finish merge:

``` bash
git add .
git commit
```

Then re-run your Git Flow command.

### 6.2 Pushing tags

Git Flow does not push tags automatically:

``` bash
git push origin --tags
```

------------------------------------------------------------------------

## 7. Git Flow Command Cheatsheet

### Initialize Git Flow

``` bash
git flow init
```

### Feature

``` bash
git flow feature start feature-name
git flow feature finish feature-name
```

### Release

``` bash
git flow release start 1.0.0   # no v prefix
git flow release finish 1.0.0  # creates tag v1.0.0
```

### Hotfix

``` bash
git flow hotfix start 1.0.1
git flow hotfix finish 1.0.1
```

### Push after finishing

``` bash
git push origin main develop --tags
```
