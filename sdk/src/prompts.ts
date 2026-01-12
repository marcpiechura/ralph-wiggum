/**
 * Ralph 2.0 Prompt Templates
 */

import type { Task, RalphConfig } from './types.js';

export function planPrompt(config: RalphConfig): string {
  return `# Planning Mode

You are creating an implementation plan for this project.

## Instructions

1. Read @AGENTS.md for project conventions
2. Read all files in ${config.specsDir}/ for requirements
3. Create/update ${config.planFile} with prioritized tasks

## Plan Format

For each task use this format:

\`\`\`markdown
- [ ] P0.1 Short task description
  - scope: path/to/files
  - validation: ${config.validationCommand}
  - assigned_thread:
  - status: not_started
  - depends_on: P0.0 (if applicable)
\`\`\`

## Priority Levels

- **P0**: Must have - core functionality
- **P1**: Should have - important enhancements  
- **P2**: Nice to have - polish and extras

## Guardrails

- Each task should be completable in 1-2 minutes
- Tasks touching same files should be sequential (use depends_on)
- Include validation command for each task
- Do NOT implement any code - planning only

## When Done

Summarize the plan with task count per priority level.
`;
}

export function buildPrompt(task: Task, config: RalphConfig, coordinatorThreadId?: string): string {
  const parentLink = coordinatorThreadId 
    ? `\nCoordinator: https://ampcode.com/threads/${coordinatorThreadId}\n`
    : '';

  return `# Build: ${task.id}
${parentLink}
## Task
${task.description}

## Context
- **Scope**: ${task.scope}
- **Validation**: ${task.validation || config.validationCommand}
${task.dependsOn ? `- **Depends on**: ${task.dependsOn} (already completed)` : ''}

## Instructions

1. Read @AGENTS.md for project conventions
2. Read @${config.planFile} to understand context
3. Implement the task (stay within scope: ${task.scope})
4. Run validation: \`${task.validation || config.validationCommand}\`
5. Update ${config.planFile}:
   - Change \`- [ ] ${task.id}\` to \`- [x] ${task.id}\`
   - Set \`status: completed\`
6. Commit: \`feat(${task.scope.split('/').pop() || 'core'}): ${task.description.toLowerCase()}\`

## Guardrails

- Stay within scope - only modify files in: ${task.scope}
- Validation MUST pass before committing
- Update the plan before finishing
- One focused commit for this task
`;
}

export function validationPrompt(config: RalphConfig): string {
  return `# Validation Mode

Run final validation and cleanup.

## Instructions

1. Read @${config.planFile} to check all tasks are complete
2. Run full validation: \`${config.validationCommand}\`
3. If validation fails:
   - Fix the issues
   - Re-run validation
4. Check for uncommitted changes: \`git status --porcelain\`
5. If there are changes, commit them: \`chore: final cleanup\`

## When Complete

If all tasks are done and validation passes, output: **RALPH_COMPLETE**
`;
}

export function workPackagePrompt(tasks: Task[], config: RalphConfig): string {
  const taskList = tasks.map(t => `- ${t.id}: ${t.description}`).join('\n');
  const taskIds = tasks.map(t => t.id).join(', ');
  
  return `# Build Work Package

## Tasks
${taskList}

## Context
- **Scope**: ${tasks[0].scope}
- **Validation**: ${tasks[0].validation || config.validationCommand}

## Instructions

1. Read @AGENTS.md for project conventions
2. Read @${config.planFile} to understand context
3. Implement all tasks in order: ${taskIds}
4. After each task:
   - Run validation
   - Update plan (mark complete)
5. When all done, commit: \`feat(${tasks[0].scope.split('/').pop() || 'core'}): implement ${taskIds}\`

## Guardrails

- Stay within scope: ${tasks[0].scope}
- Validation must pass before committing
- Update plan status for each completed task
`;
}
