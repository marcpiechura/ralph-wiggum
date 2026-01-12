/**
 * IMPLEMENTATION_PLAN.md Parser
 */

import { readFileSync, existsSync, writeFileSync } from 'fs';
import type { Task, WorkPackage } from './types.js';

export function parsePlan(planFile: string): Task[] {
  if (!existsSync(planFile)) return [];

  const content = readFileSync(planFile, 'utf-8');
  const tasks: Task[] = [];

  // Match task blocks: - [ ] P0.1 Description
  const lines = content.split('\n');
  let currentTask: Partial<Task> | null = null;

  for (const line of lines) {
    // Task header: - [ ] P0.1 Description
    const taskMatch = line.match(/^- \[( |x|~|!)\] (P\d+\.\d+)\s+(.+)$/);
    if (taskMatch) {
      if (currentTask?.id) {
        tasks.push(currentTask as Task);
      }
      const [, statusChar, id, description] = taskMatch;
      currentTask = {
        id,
        description: description.trim(),
        status: statusChar === ' ' ? 'not_started' 
              : statusChar === 'x' ? 'completed'
              : statusChar === '~' ? 'in_progress'
              : 'blocked',
        scope: '',
        validation: '',
      };
      continue;
    }

    // Task properties: - key: value
    if (currentTask && line.match(/^\s+- \w+:/)) {
      const propMatch = line.match(/^\s+- (\w+):\s*(.*)$/);
      if (propMatch) {
        const [, key, value] = propMatch;
        switch (key) {
          case 'scope':
            currentTask.scope = value;
            break;
          case 'validation':
            currentTask.validation = value;
            break;
          case 'assigned_thread':
            currentTask.assignedThread = value;
            break;
          case 'status':
            // Already parsed from checkbox
            break;
          case 'depends_on':
            currentTask.dependsOn = value;
            break;
        }
      }
    }
  }

  // Don't forget the last task
  if (currentTask?.id) {
    tasks.push(currentTask as Task);
  }

  return tasks;
}

export function getIncompleteTasks(planFile: string): Task[] {
  return parsePlan(planFile).filter(t => t.status === 'not_started');
}

export function getNextTask(planFile: string): Task | null {
  const incomplete = getIncompleteTasks(planFile);
  if (incomplete.length === 0) return null;

  // Sort by priority (P0 before P1 before P2)
  incomplete.sort((a, b) => {
    const priorityA = parseInt(a.id.match(/P(\d+)/)?.[1] || '99');
    const priorityB = parseInt(b.id.match(/P(\d+)/)?.[1] || '99');
    return priorityA - priorityB;
  });

  // Check dependencies
  const completed = parsePlan(planFile)
    .filter(t => t.status === 'completed')
    .map(t => t.id);

  for (const task of incomplete) {
    if (!task.dependsOn || completed.includes(task.dependsOn)) {
      return task;
    }
  }

  return incomplete[0]; // Fallback to first if all blocked
}

export function groupIntoWorkPackages(tasks: Task[]): WorkPackage[] {
  // Group tasks by overlapping scope
  const packages: WorkPackage[] = [];
  const assigned = new Set<string>();

  for (const task of tasks) {
    if (assigned.has(task.id)) continue;

    // Find all tasks with same scope
    const related = tasks.filter(t => 
      !assigned.has(t.id) && 
      (t.scope === task.scope || scopesOverlap(t.scope, task.scope))
    );

    if (related.length > 0) {
      packages.push({
        tasks: related,
        scope: task.scope,
        validation: task.validation,
      });
      related.forEach(t => assigned.add(t.id));
    }
  }

  return packages;
}

function scopesOverlap(a: string, b: string): boolean {
  if (!a || !b) return false;
  // Simple check: same file or same directory
  const dirA = a.split('/').slice(0, -1).join('/');
  const dirB = b.split('/').slice(0, -1).join('/');
  return a === b || dirA === dirB || a.startsWith(dirB) || b.startsWith(dirA);
}

export function updateTaskStatus(
  planFile: string,
  taskId: string,
  status: 'completed' | 'in_progress',
  threadUrl?: string
): void {
  if (!existsSync(planFile)) return;

  let content = readFileSync(planFile, 'utf-8');
  
  // Update checkbox
  const checkbox = status === 'completed' ? '[x]' : '[~]';
  content = content.replace(
    new RegExp(`- \\[[ ~!]\\] ${taskId}\\b`),
    `- ${checkbox} ${taskId}`
  );

  // Update status field
  content = content.replace(
    new RegExp(`(${taskId}[\\s\\S]*?- status:)\\s*\\w+`),
    `$1 ${status}`
  );

  // Update assigned_thread if provided
  if (threadUrl) {
    content = content.replace(
      new RegExp(`(${taskId}[\\s\\S]*?- assigned_thread:)\\s*`),
      `$1 ${threadUrl}`
    );
  }

  writeFileSync(planFile, content, 'utf-8');
}
