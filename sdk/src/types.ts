/**
 * Ralph 2.0 Types
 */

export interface Task {
  id: string;
  description: string;
  scope: string;
  status: 'not_started' | 'in_progress' | 'completed' | 'blocked';
  validation: string;
  assignedThread?: string;
  dependsOn?: string;
}

export interface WorkPackage {
  tasks: Task[];
  scope: string;
  validation: string;
}

export interface RalphConfig {
  projectDir: string;
  specsDir: string;
  planFile: string;
  validationCommand: string;
  maxIterations: number;
  maxConsecutiveFailures: number;
}

export interface ThreadResult {
  threadId: string;
  threadUrl: string;
  result: string;
  success: boolean;
  tasksCompleted: string[];
}

export type RalphMode = 'plan' | 'build' | 'auto';

export interface RalphOptions {
  mode: RalphMode;
  config?: Partial<RalphConfig>;
  verbose?: boolean;
  dryRun?: boolean;
}
