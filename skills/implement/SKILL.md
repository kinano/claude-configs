---
name: implement
description: Used to implement code changes by spinning up agents to execute an approved implementation plan
disable-model-invocation: false
---

# Best Practices for implementing code changes and pushing them using git

1. You will be provided with specific instructions to implement code changes to achieve specific outcomes.
2. Pull the base branch for the affected repos and create new branch using the following format `kinano/{jira-ticket-id}-{short-description-of-feature}`. `short-description-of-feature` should not exceed 40 characters. If no Jira ticket ID is available, prompt the human for one or use the format `kinano/{short-description-of-feature}`.
3. Depending on the scope of the changes, spin up an agent or a team of agents to implement the provided plan. Create a todo list for each agent. Kick off the execution.
4. Once the agent(s) are done, hand off the implementation plan and all the impacted repos to `/review-software` skill.
