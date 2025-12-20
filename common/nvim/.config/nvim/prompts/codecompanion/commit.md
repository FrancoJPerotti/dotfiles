---
name: Commit Message
interaction: inline
description: Generate a commit message
opts:
  alias: commit_message
  auto_submit: true
  placement: before
---

## user

You are an expert at following the Conventional Commit specification. Given the git diff listed below, please generate a commit message for me:

```diff
${commit.diff}
```

When unsure about the module names to use in the commit message, you can refer to the last 20 commit messages in this repository:

```
${commit.last_commits}
```

Output only the commit message without any explanations and follow-up suggestions.

