# Branch hygiene

The repository accumulated **94 local + remote-tracking branches** by
2026-11-27, mostly because squash-merged feature branches are not ancestors of
`master` and therefore do not disappear with `git branch -d`.

## Policy

1. Enable **Automatically delete head branches** in GitHub repository settings.
2. Squash-merge feature branches; delete the remote branch immediately.
3. Keep only active release, hotfix and long-lived spike branches.
4. Prune remote-tracking refs after deleting branches.
5. A release branch is cut from a protected-branch commit, never from an
   unreviewed tag or feature branch.

## Safe audit before deleting

Squash merges make `git branch --merged master` unreliable. Confirm the PR is
merged first:

```bash
gh pr list --state merged --limit 200 --json headRefName --jq '.[].headRefName'
```

Then compare with local and remote branches:

```bash
git for-each-ref --format='%(refname:short)' refs/heads
git branch -r
git remote prune origin
```

## Cleanup (explicit confirmation required)

Do this only after the PR list above shows the branches are merged. There is no
undo for a deleted remote branch other than recreating it from its last commit.

```bash
# Dry run: show merged PR head branches still present locally
comm -12 \
  <(gh pr list --state merged --limit 200 --json headRefName --jq '.[].headRefName' | sort -u) \
  <(git for-each-ref --format='%(refname:short)' refs/heads | sort -u)

# Delete one confirmed-merged local branch
git branch -D <branch>

# Delete one confirmed-merged remote branch
git push origin --delete <branch>

# Remove stale remote-tracking refs
git remote prune origin
```

Never bulk-delete with a generated list without reviewing the dry-run output.
Branches without a merged PR may contain unmerged work.

## Review cadence

- Monthly: list branches older than 30 days and close or delete them.
- Quarterly: audit protected-branch rules and required checks.
- After each release: prune remote refs and remove temporary release branches.

## Current state

The 2026-11-27 audit counted 32 local and 62 remote-tracking branches. No bulk
deletion was performed by the audit because destructive branch operations need a
human confirmation. Use the policy above; target fewer than 20 branches.
