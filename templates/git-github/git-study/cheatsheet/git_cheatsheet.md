# Git Cheatsheet — Thorough, Practical, 75% of Real-World Use

---

## 0) One-time setup (global)

```bash
git config --global user.name "John"
git config --global user.email "john@firebreaklabs.com"
git config --global init.defaultBranch main
git config --global pull.rebase true        # prefer linear history on pull
git config --global fetch.prune true        # auto prune deleted remote branches
git config --global rebase.autosquash true  # honors fixup!/squash! in rebase -i
git config --global color.ui auto
# Windows/WSL line endings – pick ONE and stick to it:
git config --global core.autocrlf input     # recommended across platforms
# Helpful aliases
git config --global alias.st "status -sb"
git config --global alias.lg "log --oneline --graph --decorate --all"
git config --global alias.co "checkout"
git config --global alias.unstage "reset --"
```

---

## 1) Start / Get Code

```bash
git init                      # new repo
git clone URL                 # clone (full)
git clone --depth 1 URL       # shallow (fast checkout)
git remote -v                 # list remotes
git remote add origin URL
git remote set-url origin NEW_URL
```

---

## 2) See What Changed

```bash
git status -sb                # concise status
git diff                      # unstaged changes
git diff --staged             # staged vs HEAD
git diff HEAD~1..HEAD         # last commit contents
git log --oneline --graph --decorate
git show <commit>             # commit info + patch
git blame path/to/file        # who/when lines changed
```

---

## 3) Stage & Commit Cleanly

```bash
git add file1 file2           # stage files
git add -p                    # interactive hunk staging
git restore --staged file     # unstage
git restore --source=HEAD file   # discard local edits to match HEAD
git commit -m "feat: message" # conventional commits recommended
git commit --amend            # edit last commit (message and/or staged changes)
```

**Tips**

* Commit **small, focused** diffs.
* Use `git add -p` to curate hunks.
* `--amend` only if you haven’t pushed (or you know the force-push implications).

---

## 4) Branching & Navigation

```bash
git branch                    # list local branches
git branch -vv                # with upstream tracking
git switch -c feature/x       # create & switch
git switch main               # switch branches
git branch -d feature/x       # delete merged branch
git branch -D feature/x       # force delete
git branch -m new-name        # rename current branch
```

---

## 5) Merge vs Rebase (and pulling)

**Pull (your choice):**

```bash
git pull                      # fetch + merge (default if pull.rebase false)
git pull --rebase             # fetch + rebase (clean, linear history)
```

**Merge a branch into current:**

```bash
git merge feature/x
git merge --no-ff feature/x   # always record a merge commit
```

**Rebase your branch onto updated main:**

```bash
git fetch origin
git rebase origin/main
# fix conflicts, then:
git rebase --continue
# give up:
git rebase --abort
```

**Interactive cleanup (squash/reorder):**

```bash
git rebase -i HEAD~6
# use: pick | squash | fixup | reword | drop
```

> Rule of thumb: **rebase your own feature branches**; **merge** when integrating others’ work to preserve history. Don’t rebase public commits unless the team agrees.

---

## 6) Work in Progress (stash)

```bash
git stash push -m "WIP auth form"   # stash tracked changes
git stash list
git stash show -p stash@{0}
git stash apply stash@{0}           # reapply, keep stash
git stash pop                       # reapply and drop
git stash -p                        # interactively stash hunks
git stash branch wip-fix stash@{0}  # new branch from a stash
```

---

## 7) Undo / Reset (choose the right level)

```bash
git restore file                 # discard local edits (to HEAD)
git restore --staged file        # unstage (keep worktree edits)

git reset --soft HEAD~1          # keep changes staged (undo last commit)
git reset --mixed HEAD~1         # keep changes in working dir (default)
git reset --hard HEAD~1          # nuke commit & changes (DANGEROUS)

git revert <commit>              # make a new commit that undoes <commit>
git revert -m 1 <merge-commit>   # revert a merge (specify parent)
```

**Rescue with reflog (safety net):**

```bash
git reflog                       # history of HEAD movements
git checkout HEAD@{3}            # view older position
git branch rescue HEAD@{3}       # recover lost work to branch
```

---

## 8) Remotes & Collaboration

```bash
git fetch origin                 # update remote tracking refs
git fetch -p                     # prune deleted remote branches
git push origin main
git push -u origin feature/x     # set upstream (enables plain `git push` later)
git push --force-with-lease      # safe force after rebase (don’t clobber others)
git branch -r                    # list remote branches
git push origin :old-branch      # delete remote branch
```

---

## 9) Conflicts & Resolution Flow

1. **See conflicts**:

```bash
git status
# files show "both modified"
```

2. **Open file → resolve** conflict markers:

```
<<<<<<< HEAD
yours
=======
theirs
>>>>>>> branch
```

3. **Mark resolved & continue**:

```bash
git add path/to/file
git merge --continue         # during merge
git rebase --continue        # during rebase
```

4. **Abort if needed**:

```bash
git merge --abort
git rebase --abort
```

**Helpers**

```bash
git mergetool                # launch configured mergetool (e.g., VS Code: 'code --wait')
git config --global rerere.enabled true   # remember conflict resolutions
```

---

## 10) Pick/Move Specific Commits

```bash
git cherry-pick <hash>               # apply commit onto current branch
git cherry-pick A..B                 # apply range (A exclusive, B inclusive)
git cherry-pick --no-commit <hash>   # bring changes unstaged
```

---

## 11) Tags & Releases

```bash
git tag -a v1.2.0 -m "Release 1.2.0"  # annotated tag (preferred)
git show v1.2.0
git push origin v1.2.0
git push origin --tags
```

---

## 12) Multi-task with Worktrees (parallel branches without re-clone)

```bash
git worktree add ../wt-fix bugfix/login      # create worktree at path
git worktree list
git worktree remove ../wt-fix
```

---

## 13) Cleaning & Housekeeping

```bash
git clean -n                   # preview untracked deletion
git clean -fd                  # delete untracked files/dirs
git gc --aggressive            # deep cleanup (rarely needed)
git fsck                       # repo integrity check
```

---

## 14) Search History Quickly

```bash
git grep -n "needle"                # search tracked files
git log -S "needle" -- path/file    # find commits adding/removing the string
git log -G "regex" -- path/file     # regex version
git log -- path/file                # history for a file
```

---

## 15) Bisect (find the commit that broke it)

```bash
git bisect start
git bisect bad                    # current commit is bad
git bisect good <known-good-hash>
# run your test (manual or script); mark results:
git bisect good
git bisect bad
# repeat until culprit found
git bisect reset
```

*Automate with a script that returns 0=good, non-zero=bad:*

```bash
git bisect run ./test_script.sh
```

---

## 16) Common “How do I…?” Recipes

* **Rename current branch**:
  
  ```bash
  git branch -m new-name
  git push origin -u new-name
  git push origin :old-name
  ```

* **Change last commit message** (unpushed):
  
  ```bash
  git commit --amend -m "better message"
  ```

* **Split one big commit into two**:
  
  ```bash
  git reset HEAD~1        # keep changes
  git add -p              # stage subset
  git commit -m "part 1"
  git add -A
  git commit -m "part 2"
  ```

* **Combine last N commits into one**:
  
  ```bash
  git reset --soft HEAD~N
  git commit -m "squashed"
  ```

* **Move last commit to a new branch**:
  
  ```bash
  git branch tmp HEAD~1
  git reset --hard HEAD~1
  git switch -c new-branch
  git cherry-pick <hash-of-last-commit>
  ```

* **Track a remote branch after clone**:
  
  ```bash
  git switch -c feature/x origin/feature/x
  ```

* **Keep local only certain folders (large monorepo)**:
  
  ```bash
  git sparse-checkout init --cone
  git sparse-checkout set src/ tools/
  ```

* **Fix “diverged” on push (you rebased locally)**:
  
  ```bash
  git push --force-with-lease
  # Only if you’re sure others didn’t build on the old remote commits
  ```

* **Delete a file from history (accidental secret)**:
  
  ```bash
  git filter-repo --path path/secret.txt --invert-paths   # (install git-filter-repo)
  git push --force --all
  git push --force --tags
  ```

---

## 17) `.gitignore` & Line Endings

**Ignore patterns**

```
# .gitignore
node_modules/
dist/
*.log
.env
```

**Normalize line endings (cross-platform teams)**

```bash
# .gitattributes
* text=auto
*.sh text eol=lf
*.bat text eol=crlf
```

---

## 18) Useful Logs (human-friendly)

```bash
git log --oneline --decorate --graph --all
git log --stat                 # file changes summary
git log --pretty=format:"%C(yellow)%h %Cgreen%ad %Creset%s %Cblue(%an)" --date=short
git show --name-only <hash>    # files touched
```

---

## 19) Safer Force & Collaboration Etiquette

* Prefer `--force-with-lease` over `--force`.
* Rebase your own feature branch; avoid rewriting shared history.
* Use PRs for merges to `main`; protect `main` in your remote.
* Pull before push; resolve conflicts locally, not in the web UI when complex.

---

## 20) Quick Reference Table

| Goal                          | Command                                        |
| ----------------------------- | ---------------------------------------------- |
| Stage changes interactively   | `git add -p`                                   |
| Undo staged (keep edits)      | `git restore --staged <file>`                  |
| Discard local edits           | `git restore <file>`                           |
| See concise status            | `git status -sb`                               |
| Linearize your branch         | `git pull --rebase` / `git rebase origin/main` |
| Integrate feature into main   | `git merge --no-ff feature`                    |
| Undo last commit keep changes | `git reset --soft HEAD~1`                      |
| Hard reset to previous commit | `git reset --hard HEAD~1`                      |
| Revert a bad commit safely    | `git revert <hash>`                            |
| Find breaking commit          | `git bisect start / good / bad`                |
| Recover lost work             | `git reflog` → `git branch rescue HEAD@{N}`    |
| Stash WIP                     | `git stash push -m "WIP"`                      |
| Apply stash                   | `git stash apply` / `pop`                      |
| Create annotated tag          | `git tag -a vX.Y.Z -m "release"`               |

---

### Optional: Editor/Mergetool (VS Code)

```bash
git config --global core.editor "code --wait"
git config --global merge.tool vscode
git config --global mergetool.vscode.cmd "code --wait $MERGED"
```
