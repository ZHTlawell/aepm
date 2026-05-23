# Material-First Intake Standard

Product initialization must collect materials before asking detailed product questions.

## Required Order

1. Ask the user to provide or point to a product directory.
2. Ask the user to place available materials into the onboarding package.
3. Run material completeness scoring.
4. Only after materials are checked, ask targeted follow-up questions for missing or conflicting information.

## Material Checklist

| Material | Purpose |
|----------|---------|
| Product overview | Understand product positioning and users. |
| Product screens or flow diagrams | Understand pages, navigation, and user paths. |
| PRD / requirements / Speckit | Understand business rules and acceptance criteria. |
| API docs | Understand integrations, errors, and data flow. |
| Database or data model docs | Understand entities and state transitions. |
| Existing test cases | Understand current coverage. |
| Bug history | Understand regression hotspots. |
| Test reports | Understand recent quality status and unresolved risks. |
| Automation docs or scripts | Understand automated coverage and execution. |

## Follow-up Question Rule

Before materials are provided, ask for materials, not business details.

After materials are provided, ask targeted questions that improve readiness:

- Missing critical documents.
- Contradictions between documents.
- Unclear business rules.
- Unknown expected results.
- Unknown data state transitions.
- Unknown release risks.

## Product Summary Only Input

If the user only provides a short product summary, record it as initial identity but do not proceed as if the product is understood. Reply with the material checklist and ask the user to provide documents.

