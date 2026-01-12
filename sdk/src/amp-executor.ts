/**
 * Amp Executor
 * 
 * Executes Amp CLI directly using the global binary.
 * Works around @sourcegraph/amp-sdk's requirement for local npm package.
 */

import { spawn } from 'child_process';

export interface ExecuteOptions {
  cwd?: string;
  dangerouslyAllowAll?: boolean;
}

export interface SystemMessage {
  type: 'system';
  session_id: string;
}

export interface AssistantMessage {
  type: 'assistant';
  message: {
    content: Array<
      | { type: 'text'; text: string }
      | { type: 'tool_use'; name: string; input: unknown }
    >;
  };
}

export interface ResultMessage {
  type: 'result';
  result: string;
  is_error?: boolean;
  error?: string;
}

export type StreamMessage = SystemMessage | AssistantMessage | ResultMessage;

export interface ExecuteParams {
  prompt: string;
  options?: ExecuteOptions;
}

/**
 * Find the amp command - tries global binary first
 */
function findAmpCommand(): string {
  // Try common locations
  const candidates = [
    process.env.HOME + '/.local/bin/amp',
    process.env.HOME + '/.amp/bin/amp',
    '/usr/local/bin/amp',
    'amp', // PATH lookup
  ];

  for (const cmd of candidates) {
    try {
      const result = Bun.spawnSync(['which', cmd.startsWith('/') ? cmd : cmd]);
      if (result.exitCode === 0) {
        return cmd;
      }
    } catch {
      // Try next
    }
  }

  // Default to PATH lookup
  return 'amp';
}

/**
 * Execute a prompt using the Amp CLI
 */
export async function* execute(params: ExecuteParams): AsyncGenerator<StreamMessage> {
  const { prompt, options = {} } = params;

  const args = ['--execute', '--stream-json'];
  if (options.dangerouslyAllowAll) {
    args.push('--dangerously-allow-all');
  }

  const ampCmd = findAmpCommand();

  const proc = spawn(ampCmd, args, {
    cwd: options.cwd || process.cwd(),
    env: { ...process.env },
    stdio: ['pipe', 'pipe', 'pipe'],
  });

  // Send prompt to stdin
  proc.stdin.write(prompt);
  proc.stdin.end();

  let buffer = '';

  // Process stdout line by line
  for await (const chunk of proc.stdout) {
    buffer += chunk.toString();

    let newlineIdx: number;
    while ((newlineIdx = buffer.indexOf('\n')) !== -1) {
      const line = buffer.slice(0, newlineIdx).trim();
      buffer = buffer.slice(newlineIdx + 1);

      if (!line) continue;

      try {
        const msg = JSON.parse(line) as StreamMessage;
        yield msg;
      } catch {
        // Non-JSON output, ignore
      }
    }
  }

  // Wait for process to complete
  await new Promise<void>((resolve, reject) => {
    proc.on('close', (code) => {
      if (code !== 0) {
        reject(new Error(`Amp exited with code ${code}`));
      } else {
        resolve();
      }
    });
    proc.on('error', reject);
  });
}
