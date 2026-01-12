/**
 * Ralph 2.0 Orchestrator
 * 
 * Coordinates planning and build threads using the Amp SDK.
 */

import { execute, type StreamMessage } from './amp-executor.js';
import { join } from 'path';
import { existsSync } from 'fs';
import type { RalphConfig, RalphOptions, Task, ThreadResult } from './types.js';
import { getNextTask, getIncompleteTasks, parsePlan } from './plan-parser.js';
import { planPrompt, buildPrompt, validationPrompt } from './prompts.js';

// Colors for terminal output
const c = {
  reset: '\x1b[0m',
  green: '\x1b[32m',
  yellow: '\x1b[33m',
  cyan: '\x1b[36m',
  red: '\x1b[31m',
  dim: '\x1b[2m',
};

export class RalphOrchestrator {
  private config: RalphConfig;
  private verbose: boolean;
  private coordinatorThreadId?: string;

  constructor(options: RalphOptions) {
    this.verbose = options.verbose ?? false;
    this.config = {
      projectDir: options.config?.projectDir || process.cwd(),
      specsDir: options.config?.specsDir || 'specs',
      planFile: options.config?.planFile || 'IMPLEMENTATION_PLAN.md',
      validationCommand: options.config?.validationCommand || 'npm run check',
      maxIterations: options.config?.maxIterations || 50,
      maxConsecutiveFailures: options.config?.maxConsecutiveFailures || 3,
    };
  }

  private log(msg: string, color: string = c.reset): void {
    console.log(`${color}${msg}${c.reset}`);
  }

  private logVerbose(msg: string): void {
    if (this.verbose) {
      console.log(`${c.dim}${msg}${c.reset}`);
    }
  }

  private get planPath(): string {
    return join(this.config.projectDir, this.config.planFile);
  }

  private threadUrl(sessionId: string): string {
    return `https://ampcode.com/threads/${sessionId}`;
  }

  /**
   * Execute a prompt and stream results
   */
  private async runThread(prompt: string): Promise<ThreadResult> {
    const stream = execute({
      prompt,
      options: {
        cwd: this.config.projectDir,
        dangerouslyAllowAll: true,
      },
    });

    let threadId = '';
    let result = '';
    let success = true;

    try {
      for await (const msg of stream) {
        switch (msg.type) {
          case 'system':
            threadId = msg.session_id;
            this.log(`  Thread: ${this.threadUrl(threadId)}`, c.cyan);
            break;

          case 'assistant':
            for (const content of msg.message.content) {
              if (content.type === 'text') {
                // Only show text if verbose, otherwise just show we got a response
                if (this.verbose) {
                  process.stdout.write(content.text);
                }
              } else if (content.type === 'tool_use') {
                this.logVerbose(`    [${content.name}]`);
              }
            }
            break;

          case 'result':
            if (msg.is_error) {
              success = false;
              result = 'error' in msg ? msg.error : 'Unknown error';
              this.log(`  Error: ${result}`, c.red);
            } else {
              result = msg.result;
              // Show condensed result
              const lines = result.split('\n').filter(l => l.trim());
              const summary = lines.slice(0, 3).join(' ').slice(0, 200);
              this.log(`  ${summary}${lines.length > 3 ? '...' : ''}`);
            }
            break;
        }
      }
    } catch (error) {
      success = false;
      result = error instanceof Error ? error.message : String(error);
      this.log(`  Error: ${result}`, c.red);
    }

    return {
      threadId,
      threadUrl: this.threadUrl(threadId),
      result,
      success,
      tasksCompleted: [], // Will be determined by checking plan
    };
  }

  /**
   * Planning phase: create or update implementation plan
   */
  async plan(): Promise<ThreadResult> {
    this.log('\n=== Planning Phase ===', c.green);

    const prompt = planPrompt(this.config);
    const result = await this.runThread(prompt);
    
    this.coordinatorThreadId = result.threadId;
    
    // Verify plan was created
    if (!existsSync(this.planPath)) {
      this.log('Warning: Plan file not created', c.yellow);
    } else {
      const tasks = parsePlan(this.planPath);
      this.log(`\n  Plan created with ${tasks.length} tasks`, c.green);
    }

    return result;
  }

  /**
   * Build phase: execute tasks from the plan
   */
  async build(): Promise<void> {
    this.log('\n=== Build Phase ===', c.green);

    let iteration = 0;
    let consecutiveFailures = 0;

    while (iteration < this.config.maxIterations) {
      // Check remaining tasks
      const remaining = getIncompleteTasks(this.planPath);
      
      if (remaining.length === 0) {
        this.log('\n✓ All tasks complete!', c.green);
        break;
      }

      // Get next task (respecting dependencies)
      const task = getNextTask(this.planPath);
      if (!task) {
        this.log('\nNo available tasks (all blocked by dependencies)', c.yellow);
        break;
      }

      iteration++;
      this.log(`\n--- Iteration ${iteration}: ${task.id} ---`, c.green);
      this.log(`  ${task.description}`, c.dim);

      // Run build thread
      const prompt = buildPrompt(task, this.config, this.coordinatorThreadId);
      const result = await this.runThread(prompt);

      if (!result.success) {
        consecutiveFailures++;
        if (consecutiveFailures >= this.config.maxConsecutiveFailures) {
          this.log(`\nToo many consecutive failures (${consecutiveFailures}). Stopping.`, c.red);
          break;
        }
        this.log(`  Failure ${consecutiveFailures}/${this.config.maxConsecutiveFailures}`, c.yellow);
        continue;
      }

      consecutiveFailures = 0;

      // Check if task was actually completed
      const stillIncomplete = getIncompleteTasks(this.planPath);
      if (stillIncomplete.length === remaining.length) {
        this.log('  Warning: Task may not have been marked complete', c.yellow);
      }

      // Small delay between iterations
      await new Promise(r => setTimeout(r, 500));
    }

    if (iteration >= this.config.maxIterations) {
      this.log(`\nReached max iterations (${this.config.maxIterations})`, c.yellow);
    }
  }

  /**
   * Validation phase: final checks and cleanup
   */
  async validate(): Promise<ThreadResult> {
    this.log('\n=== Validation Phase ===', c.green);

    const prompt = validationPrompt(this.config);
    const result = await this.runThread(prompt);

    if (result.result.includes('RALPH_COMPLETE')) {
      this.log('\n✓ RALPH_COMPLETE', c.green);
    }

    return result;
  }

  /**
   * Run the full workflow
   */
  async run(mode: 'plan' | 'build' | 'auto'): Promise<void> {
    this.log(`Ralph 2.0 Orchestrator - ${mode.toUpperCase()} mode`, c.green);
    this.log(`Project: ${this.config.projectDir}`);

    try {
      if (mode === 'plan' || mode === 'auto') {
        await this.plan();
      }

      if (mode === 'build' || mode === 'auto') {
        await this.build();
        await this.validate();
      }

      this.log('\n=== Ralph Complete ===', c.green);
    } catch (error) {
      this.log(`\nFatal error: ${error}`, c.red);
      process.exit(1);
    }
  }
}
