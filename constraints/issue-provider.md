# Issue Provider Standard

QA Agent must not assume a single issue tracking platform. Issue submission is controlled by `.qa-agent.yml`.

## Supported Provider Modes

| Provider | Behavior |
|----------|----------|
| `manual` | Generate issue body only. The user submits it manually. |
| `github` | Use GitHub Issues adapter when available. |
| `gitlab` | Use GitLab Issues adapter when available. |
| `jira` | Use Jira adapter when available. |
| `gitee` | Use `ae git` adapter when available. |
| `zentao` | Use ZenTao adapter when available. |
| `testrail` | Use TestRail adapter when available. |

## Fallback Rule

If the configured provider is unavailable, missing credentials, or has no adapter, fall back to `manual`.

## Required Submission Confirmation

Before any external submission, show:

- Provider
- Target project/repository
- Issue title
- Full issue body
- Attachments to upload

Proceed only after user confirmation.

## Privacy Rule

Never upload logs, screenshots, customer data, or database extracts without explicit user confirmation.

