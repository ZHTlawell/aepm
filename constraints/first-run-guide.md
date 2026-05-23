# First Run Guide

When a user asks the agent to read this open-source project for the first time, the agent should not only summarize the repository. It must tell the user what to do next.

## Progressive First Response Shape

After reading this repository for the first time, use progressive guidance. The first response must solve only one problem: help the user choose the product directory.

1. What this project is: a product-specific QA Agent framework.
2. The immediate next step: create or choose one product directory.
3. Ask one question only: which product directory should this Agent bind to?
4. Warn briefly that one product should own one QA Agent.

Do not show the full onboarding directory tree in the first response. Do not ask the user to provide PRD, screenshots, API docs, database docs, test cases, bug history, reports, and automation all at once.

## Step Sequence

### Step 1: Choose Product Directory

Goal: determine the product directory.

Allowed response shape:

```text
I have read this repository. It is a product-specific QA Agent framework.

Next, do only one thing: choose the product directory this QA Agent should bind to.

Please provide the product directory path, for example:
<product_dir>

One product should use one QA Agent. Do not mix materials from multiple products in the same directory.
```

### Step 2: Initialize Product Agent

After the user provides the directory, the next response solves only initialization:

```bash
ae qa product-init <product_dir>
```

Explain that initialization creates `.qa-agent.yml`, `qa-onboarding-input/`, `qa/`, and `.qa-memory/`.

### Step 3: Collect First Material

After initialization, ask for one next action only: provide the first product material.

Recommended wording:

```text
Initialization is complete.

Next, do only one thing: provide the first product material.

Prefer PRD or product screenshots. You can upload a file, paste content, or provide an existing file path.
```

The default post-initialization response must not show the full material directory list. Show the directory list only when the user explicitly asks where to place materials, or when generating a material completeness report.

## Do Not

- Do not stop at a repository summary.
- Do not ask for product business details before asking the user to prepare product materials.
- Do not claim the product Agent is ready before the readiness score reaches 85/100.
- Do not present multiple next steps in one turn.
- Do not ask multiple questions in one turn.
- Do not surface CLI or environment issues unless they block the current step.
- Do not show all material categories immediately after initialization.

## Suggested User Guidance

Only show the full onboarding structure after Step 2 or when the user explicitly asks where to put materials:

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
