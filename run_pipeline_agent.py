#!/usr/bin/env python3
"""
E2E pipeline runner: deterministic execution + AI-powered error recovery.

Runs run_pipeline.py first. If it succeeds, done. If it fails, hands off to
a Cortex Code Agent that diagnoses the failure and attempts to fix it.

Requires: pip install cortex-code-agent-sdk

Usage:
  python run_pipeline_agent.py                    # run pipeline, agent on failure
  python run_pipeline_agent.py --agent-only       # skip deterministic run, go straight to agent
  python run_pipeline_agent.py --skip-streaming   # pass flags through to run_pipeline.py
  python run_pipeline_agent.py --dry-run          # dry-run the pipeline only
"""

import argparse
import asyncio
import subprocess
import sys
from pathlib import Path

from cortex_code_agent_sdk import query, AssistantMessage, CortexCodeAgentOptions

REPO_DIR = Path(__file__).parent
PIPELINE_SCRIPT = REPO_DIR / "run_pipeline.py"

RECOVERY_PROMPT = """\
The Automated Intelligence e2e pipeline (run_pipeline.py) just failed with exit code {exit_code}.

Here is the output:
{output}

Diagnose the failure. Check Snowflake state if needed (connection: dash-builder-si, database: AUTOMATED_INTELLIGENCE).
Attempt to fix the issue, then re-run the failed step. Give a summary of what went wrong and what you did.
"""

FULL_RUN_PROMPT = """\
Run the Automated Intelligence e2e pipeline. Execute:

  python run_pipeline.py {flags}

After each step completes, give a one-sentence summary of what happened.
If any step fails, diagnose the issue by checking Snowflake state and attempt to fix it.
At the end, give an overall summary of the pipeline run.
"""


async def run_agent(prompt: str, cwd: str):
    """Stream agent responses to stdout."""
    options = CortexCodeAgentOptions(cwd=cwd)

    async for message in query(prompt=prompt, options=options):
        if isinstance(message, AssistantMessage):
            for block in message.content:
                if hasattr(block, "text"):
                    print(block.text, end="", flush=True)
    print()


def run_pipeline(extra_args: list[str]) -> subprocess.CompletedProcess:
    """Run run_pipeline.py and return the result."""
    cmd = [sys.executable, str(PIPELINE_SCRIPT)] + extra_args
    print(f"  Running: {' '.join(cmd)}\n")
    return subprocess.run(cmd, cwd=str(REPO_DIR), capture_output=True, text=True)


def main():
    parser = argparse.ArgumentParser(
        description="E2E pipeline with AI error recovery",
        formatter_class=argparse.RawDescriptionHelpFormatter,
    )
    parser.add_argument("--agent-only", action="store_true",
                        help="Skip deterministic run, go straight to agent")
    # Pass-through flags for run_pipeline.py
    parser.add_argument("--interactive", action="store_true")
    parser.add_argument("--skip-streaming", action="store_true")
    parser.add_argument("--dry-run", action="store_true")
    parser.add_argument("--step", type=int, default=None)
    parser.add_argument("--connection", default=None)
    parser.add_argument("--orders", type=int, default=None)
    parser.add_argument("--staging-orders", type=int, default=None)
    args = parser.parse_args()

    # Build pass-through flags
    flags = []
    if args.interactive:
        flags.append("--interactive")
    if args.skip_streaming:
        flags.append("--skip-streaming")
    if args.dry_run:
        flags.append("--dry-run")
    if args.step is not None:
        flags.extend(["--step", str(args.step)])
    if args.connection:
        flags.extend(["--connection", args.connection])
    if args.orders is not None:
        flags.extend(["--orders", str(args.orders)])
    if args.staging_orders is not None:
        flags.extend(["--staging-orders", str(args.staging_orders)])

    print("  Automated Intelligence — Pipeline + Agent Runner")
    print()

    # ── Agent-only mode ──────────────────────────────────────────────────
    if args.agent_only:
        print("  Mode: agent-only (skipping deterministic run)\n")
        prompt = FULL_RUN_PROMPT.format(flags=" ".join(flags) or "--interactive")
        try:
            asyncio.run(run_agent(prompt, str(REPO_DIR)))
        except KeyboardInterrupt:
            print("\n  Agent interrupted.")
            return 1
        return 0

    # ── Phase 1: Deterministic run ───────────────────────────────────────
    print("  Phase 1: Deterministic pipeline run\n")
    result = run_pipeline(flags)

    # Print stdout live (it was captured)
    if result.stdout:
        print(result.stdout)
    if result.stderr:
        print(result.stderr, file=sys.stderr)

    if result.returncode == 0:
        print("  Phase 1 succeeded. No agent recovery needed.")
        return 0

    # ── Phase 2: Agent recovery ──────────────────────────────────────────
    print(f"\n  Phase 1 failed (exit code {result.returncode}).")
    print("  Phase 2: Launching Cortex Code Agent for diagnosis and recovery...\n")

    # Combine stdout+stderr, truncate to last 3000 chars for prompt context
    output = (result.stdout or "") + "\n" + (result.stderr or "")
    if len(output) > 3000:
        output = "...(truncated)...\n" + output[-3000:]

    prompt = RECOVERY_PROMPT.format(exit_code=result.returncode, output=output)

    try:
        asyncio.run(run_agent(prompt, str(REPO_DIR)))
    except KeyboardInterrupt:
        print("\n  Agent interrupted.")
        return 1

    return 0


if __name__ == "__main__":
    sys.exit(main())
