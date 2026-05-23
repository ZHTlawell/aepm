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

