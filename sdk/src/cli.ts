#!/usr/bin/env bun
/**
 * Ralph 2.0 CLI
 * 
 * Usage:
 *   ralph plan              # Create/update implementation plan
 *   ralph build             # Execute tasks from plan  
 *   ralph auto              # Plan then build (default)
 *   ralph --help            # Show help
 * 
 * Options:
 *   --verbose, -v           # Show detailed output
 *   --project, -p <dir>     # Project directory (default: cwd)
 *   --validation <cmd>      # Validation command
 *   --max-iterations <n>    # Max build iterations
 */

import { RalphOrchestrator } from './orchestrator.js';
import type { RalphMode, RalphOptions } from './types.js';

function printHelp(): void {
  console.log(`
Ralph 2.0 - AI-Driven Development Orchestrator

Usage:
  ralph [mode] [options]

Modes:
  plan      Create or update IMPLEMENTATION_PLAN.md from specs
  build     Execute tasks from the implementation plan
  auto      Plan then build (default)

Options:
  -v, --verbose           Show detailed output
  -p, --project <dir>     Project directory (default: current directory)
  --specs <dir>           Specs directory (default: specs)
  --plan <file>           Plan file name (default: IMPLEMENTATION_PLAN.md)
  --validation <cmd>      Validation command (default: npm run check)
  --max-iterations <n>    Maximum build iterations (default: 50)
  -h, --help              Show this help message

Examples:
  ralph                   # Auto mode in current directory
  ralph build -v          # Build with verbose output
  ralph plan -p ./myapp   # Plan for specific project
  ralph build --validation "pnpm run check"
`);
}

function parseArgs(): RalphOptions {
  const args = process.argv.slice(2);
  
  let mode: RalphMode = 'auto';
  let verbose = false;
  let projectDir = process.cwd();
  let specsDir = 'specs';
  let planFile = 'IMPLEMENTATION_PLAN.md';
  let validationCommand = 'npm run check';
  let maxIterations = 50;

  for (let i = 0; i < args.length; i++) {
    const arg = args[i];
    const next = args[i + 1];

    switch (arg) {
      case 'plan':
      case 'build':
      case 'auto':
        mode = arg;
        break;
      case '-v':
      case '--verbose':
        verbose = true;
        break;
      case '-p':
      case '--project':
        projectDir = next;
        i++;
        break;
      case '--specs':
        specsDir = next;
        i++;
        break;
      case '--plan':
        planFile = next;
        i++;
        break;
      case '--validation':
        validationCommand = next;
        i++;
        break;
      case '--max-iterations':
        maxIterations = parseInt(next, 10);
        i++;
        break;
      case '-h':
      case '--help':
        printHelp();
        process.exit(0);
      default:
        if (arg.startsWith('-')) {
          console.error(`Unknown option: ${arg}`);
          process.exit(1);
        }
    }
  }

  return {
    mode,
    verbose,
    config: {
      projectDir,
      specsDir,
      planFile,
      validationCommand,
      maxIterations,
    },
  };
}

async function main(): Promise<void> {
  const options = parseArgs();
  const orchestrator = new RalphOrchestrator(options);
  await orchestrator.run(options.mode);
}

main().catch(error => {
  console.error('Fatal error:', error);
  process.exit(1);
});
