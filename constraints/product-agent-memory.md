# Product Agent Memory Standard

QA Agent is product-bound. One product repository or directory should own one product QA Agent memory.

## Product Boundary

If the user provides documents or requirements for a different product, do not merge them into the current memory. Tell the user to create a new product agent directory and run:

```bash
ae qa product-init <new_product_dir>
```

## Readiness Threshold

The product agent can enter product-specific mode only when readiness score is at least 85/100.

| Score | Behavior |
|-------|----------|
| 85-100 | Product-specific QA Agent mode is allowed. |
| 60-84 | Assist with testing, but mark uncertainty and ask follow-up questions. |
| 40-59 | Generate only partial onboarding and gap analysis. |
| <40 | Stop and ask the user to provide missing materials. |

## 85-Point Confirmation Gate

When readiness reaches 85/100 or higher, do not automatically continue into test case generation, risk scanning, release checks, or new-module planning.

Use a confirmation gate:

1. Tell the user the readiness score has reached 85/100.
2. Ask one question only: whether to freeze/update the current product knowledge into QA Memory.
3. Show only the memory files that will be created or updated.
4. Wait for user confirmation.
5. After confirmation, update `.qa-memory/` and append `.qa-memory/changelog.md`.
6. Then present a selectable task menu and ask the user to choose one task.

Allowed wording:

```text
The product readiness score has reached 85/100.

Next, do only one thing: confirm whether to save the current product knowledge into QA Memory.
```

After memory is saved, a task menu is allowed because it is a single choice point, not multiple simultaneous tasks.

Default task menu:

1. Generate product understanding package.
2. Check material consistency.
3. Scan high-risk modules.
4. Generate test cases.
5. Plan a new-module test.
6. Run release quality gate.

## Memory Layout

```text
.qa-memory/
  product-profile.md
  module-map.md
  user-journeys.md
  business-rules.md
  api-map.md
  data-model.md
  risk-model.md
  test-coverage.md
  bug-patterns.md
  glossary.md
  open-questions.md
  changelog.md
```

## Update Rule

Use versioned memory updates:

1. Keep old facts and record the proposed change.
2. Show evidence and impact.
3. Ask the user to confirm critical changes.
4. After confirmation, update memory and append `.qa-memory/changelog.md`.

Critical changes include product positioning, core workflow, module ownership, business rules, API contracts, data state transitions, release gates, and high-risk areas.

## Anti-Hallucination Rule

Every important conclusion must include source and confidence:

- `confirmed`: explicit source exists.
- `extracted`: extracted from code, API, UI, or tests.
- `inferred`: inferred from context and must be stated as uncertain.
- `missing`: cannot determine from available material.

Release decisions, defect severity, and core workflow claims cannot rely only on `inferred` evidence.
