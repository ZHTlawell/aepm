# First Run Guide

When a user asks the agent to read this open-source project for the first time, the agent should not only summarize the repository. It must tell the user what to do next.

## Required First Response Shape

After reading this repository, respond with:

1. What this project is: a product-specific QA Agent framework.
2. The immediate next step: create or choose one product directory.
3. Explain that product initialization creates the product Agent skeleton automatically.
4. The exact command to run:

```bash
ae qa product-init <product_dir>
```

5. Tell the user they can provide product materials by uploading files, pasting content, or providing existing paths.
6. A warning: do not mix documents from multiple products in one product Agent.

## Do Not

- Do not stop at a repository summary.
- Do not ask for product business details before asking the user to prepare product materials.
- Do not claim the product Agent is ready before the readiness score reaches 85/100.

## Suggested User Guidance

Tell the user that `ae qa product-init <product_dir>` creates this structure:

```text
<product_dir>/
  .qa-agent.yml
  qa-onboarding-input/
    00-project-structure.md
    01-product-overview.md
    02-product-screens/
    03-product-docs/
    04-api-docs/
    05-database-docs/
    06-test-cases/
    07-bug-history/
    08-test-reports/
    09-automation/
  qa/
  .qa-memory/
```
