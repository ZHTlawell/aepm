# Contributing

QA Agent is intended to be a general, configurable testing workflow agent. Contributions should improve reusable QA workflows instead of encoding one team's private process.

## What to Contribute

- New QA skills with clear input, output, and stop conditions.
- Better test case, risk, release, or bug report standards.
- Issue provider adapters such as GitHub, GitLab, Jira, Gitee, Linear, ZenTao, or TestRail.
- Sample onboarding packages and expected outputs.
- Bug fixes that make CLI behavior more portable.

## Skill Design Rules

1. One skill should transform one human-reviewable artifact into the next.
2. Every important conclusion must be traceable to a source.
3. Missing information must be marked as missing, not guessed.
4. Output should be useful to a tester on the next working day.
5. Avoid vendor-specific assumptions unless they are behind configuration.

## Required Checks

Run these before opening a pull request:

```bash
bash -n cli/ae cli/lib/qa/commands.sh cli/lib/link.sh
git diff --check
ae qa help
ae link qa /tmp/qa-agent-link-test
```

## Adding a Skill

1. Create `.agents/skills/<skill-name>/SKILL.md`.
2. Add the skill to `manifest.yml`.
3. Add a CLI command in `cli/lib/qa/commands.sh` if it should be executable.
4. Update `README.md` and `AGENTS.md`.
5. Add or update constraints under `constraints/` when the skill depends on a standard.

