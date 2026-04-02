---
name: plan-my-shit
description: Used to gather requirements, clarify scope, and create implementation plans for new feature requests or bug fixes
---

# Planning Skill for Software Changes

1. Prompt the human to provide details of the task using one of the following options:

- JIRA ticket ID
- Link to markdown file on the filesystem
- Written text in the chat interface

2. If needed, fetch the JIRA ticket ID details from your Atlassian connector (prompt the human to setup the Atlassian connector if it is not available).
3. Ask the human clarifying questions to remove all ambiguous details. You will hand off the task to teams and other skills. You must have mastery of all the edge cases and all the requirements to be successful.
4. Identify the git repos that should be used to implement changes from the task description or from the current folder contents. If that is not possible, prompt the human to enter the paths to the relevant repos.
5. Once you have 100% task clarity, create an implementation plan (ideally markdown file) and include necessary artifacts (e.g. visualizations) that describe the code and architecture change and makes it easy to review by humans and other skills. Leverage `/secure-my-shit` skill to validate security of the proposed changes.
6. Prompt the human to review the implementation plan and prompt them to either request changes in the chat interface or by adjusting the implementation plan files themselves.
7. Once the implementation plan is approved, you will pass a summary of the task details, the implementation plan files and all the generated artifacts to the `/build-my-shit` skill.
