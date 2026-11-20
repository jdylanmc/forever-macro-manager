# Agent roles

- **Main orchestrator:** Clarify user intent and delegate implementation,
  documentation, and tests to scoped sub-agents. Integrate their changes, review
  evidence, validate the result, and publish only when authorized.
- **Scoped workers:** Do assigned work directly within the supplied scope and
  return changes and verification evidence. Do not recursively delegate or
  publish unless explicitly authorized.
