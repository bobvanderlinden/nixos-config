#!/usr/bin/env python3
"""Update and merge approved GitHub PRs one-by-one.

The script intentionally processes only open, non-draft, APPROVED PRs whose base
branch is the configured base branch (main by default). That keeps stacked PRs
safe: a stacked PR is skipped until its base is main.
"""

from __future__ import annotations

import argparse
import asyncio
import json
import os
import shutil
import sys
import tempfile
from dataclasses import dataclass
from pathlib import Path


@dataclass(frozen=True)
class PullRequest:
    number: int
    title: str
    base: str
    head: str
    url: str


class CommandError(RuntimeError):
    def __init__(self, command: tuple[str, ...], returncode: int, stdout: str, stderr: str):
        super().__init__(f"command failed ({returncode}): {' '.join(command)}\n{stderr or stdout}")
        self.command = command
        self.returncode = returncode
        self.stdout = stdout
        self.stderr = stderr


async def run(*command: str, cwd: Path | None = None, check: bool = True) -> str:
    print(f"$ {' '.join(command)}", flush=True)
    process = await asyncio.create_subprocess_exec(
        *command,
        cwd=str(cwd) if cwd else None,
        stdout=asyncio.subprocess.PIPE,
        stderr=asyncio.subprocess.PIPE,
    )
    stdout_bytes, stderr_bytes = await process.communicate()
    stdout = stdout_bytes.decode()
    stderr = stderr_bytes.decode()
    if stdout:
        print(stdout, end="")
    if stderr:
        print(stderr, end="", file=sys.stderr)
    if check and process.returncode != 0:
        raise CommandError(command, process.returncode, stdout, stderr)
    return stdout


async def list_pull_requests(author: str, base: str) -> list[PullRequest]:
    raw = await run(
        "gh",
        "pr",
        "list",
        "--author",
        author,
        "--state",
        "open",
        "--limit",
        "100",
        "--json",
        "number,title,baseRefName,headRefName,reviewDecision,isDraft,url",
    )
    pull_requests: list[PullRequest] = []
    for item in json.loads(raw):
        if item["isDraft"]:
            continue
        if item["reviewDecision"] != "APPROVED":
            continue
        if item["baseRefName"] != base:
            print(
                f"Skipping #{item['number']} ({item['headRefName']}): base is {item['baseRefName']!r}, not {base!r}",
                flush=True,
            )
            continue
        pull_requests.append(
            PullRequest(
                number=item["number"],
                title=item["title"],
                base=item["baseRefName"],
                head=item["headRefName"],
                url=item["url"],
            ),
        )
    return pull_requests


async def update_pull_request(pull_request: PullRequest, remote: str, worktree_root: Path) -> str:
    worktree = worktree_root / f"pr-{pull_request.number}"
    if worktree.exists():
        shutil.rmtree(worktree)

    await run("git", "fetch", remote, f"{pull_request.base}:refs/remotes/{remote}/{pull_request.base}")
    await run("git", "worktree", "add", "--detach", str(worktree), f"{remote}/{pull_request.base}")
    try:
        await run(
            "git",
            "fetch",
            remote,
            f"pull/{pull_request.number}/head:refs/remotes/{remote}/pr/{pull_request.number}",
            cwd=worktree,
        )
        await run("git", "checkout", "--detach", f"refs/remotes/{remote}/pr/{pull_request.number}", cwd=worktree)
        await run("git", "rebase", f"{remote}/{pull_request.base}", cwd=worktree)
        head_sha = (await run("git", "rev-parse", "HEAD", cwd=worktree)).strip()
        await run("git", "push", "--force-with-lease", remote, f"HEAD:{pull_request.head}", cwd=worktree)
        return head_sha
    finally:
        await run("git", "worktree", "remove", "--force", str(worktree), check=False)


async def latest_run_for_branch(branch: str) -> dict[str, str] | None:
    raw = await run(
        "gh",
        "run",
        "list",
        "--branch",
        branch,
        "--limit",
        "1",
        "--json",
        "databaseId,status,conclusion,headSha,workflowName,url",
        check=False,
    )
    try:
        runs = json.loads(raw or "[]")
    except json.JSONDecodeError:
        return None
    return runs[0] if runs else None


async def wait_for_ci(branch: str, head_sha: str, interval_seconds: int, timeout_seconds: int) -> None:
    deadline = asyncio.get_running_loop().time() + timeout_seconds
    while True:
        run_data = await latest_run_for_branch(branch)
        if run_data:
            print(
                "CI:",
                run_data.get("workflowName"),
                run_data.get("status"),
                run_data.get("conclusion") or "",
                run_data.get("headSha"),
                run_data.get("url"),
                flush=True,
            )
            if run_data.get("headSha") == head_sha and run_data.get("status") == "completed":
                if run_data.get("conclusion") == "success":
                    return
                raise RuntimeError(f"CI failed for {branch}: {run_data.get('url')}")
        if asyncio.get_running_loop().time() >= deadline:
            raise TimeoutError(f"Timed out waiting for CI on {branch}")
        await asyncio.sleep(interval_seconds)


async def queue_merge(pull_request: PullRequest) -> None:
    result = await asyncio.create_subprocess_exec(
        "gh",
        "pr",
        "merge",
        str(pull_request.number),
        stdout=asyncio.subprocess.PIPE,
        stderr=asyncio.subprocess.PIPE,
    )
    stdout_bytes, stderr_bytes = await result.communicate()
    stdout = stdout_bytes.decode()
    stderr = stderr_bytes.decode()
    if stdout:
        print(stdout, end="")
    if stderr:
        print(stderr, end="", file=sys.stderr)
    if result.returncode != 0 and "already queued to merge" not in (stdout + stderr):
        raise CommandError(("gh", "pr", "merge", str(pull_request.number)), result.returncode, stdout, stderr)


async def wait_for_merge(number: int, interval_seconds: int, timeout_seconds: int) -> None:
    deadline = asyncio.get_running_loop().time() + timeout_seconds
    while True:
        raw = await run("gh", "pr", "view", str(number), "--json", "state,mergeStateStatus,mergedAt,url")
        data = json.loads(raw)
        print(f"PR #{number}: {data['state']} {data.get('mergeStateStatus')} {data.get('mergedAt') or ''}", flush=True)
        if data["state"] == "MERGED":
            return
        if asyncio.get_running_loop().time() >= deadline:
            raise TimeoutError(f"Timed out waiting for PR #{number} to merge: {data.get('url')}")
        await asyncio.sleep(interval_seconds)


async def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--author", default="@me")
    parser.add_argument("--base", default="main")
    parser.add_argument("--remote", default="origin")
    parser.add_argument("--interval", type=int, default=30)
    parser.add_argument("--ci-timeout", type=int, default=60 * 60)
    parser.add_argument("--merge-timeout", type=int, default=60 * 60)
    parser.add_argument("--dry-run", action="store_true")
    args = parser.parse_args()

    pull_requests = await list_pull_requests(args.author, args.base)
    if not pull_requests:
        print("No open approved non-draft PRs to merge.")
        return

    print("Will process:")
    for pull_request in pull_requests:
        print(f"  #{pull_request.number} {pull_request.head} -> {pull_request.base}: {pull_request.title}")
    if args.dry_run:
        return

    with tempfile.TemporaryDirectory(prefix="gh-batch-merge-") as temporary_directory:
        worktree_root = Path(temporary_directory)
        for pull_request in pull_requests:
            print(f"\n=== #{pull_request.number}: {pull_request.title} ===", flush=True)
            head_sha = await update_pull_request(pull_request, args.remote, worktree_root)
            await wait_for_ci(pull_request.head, head_sha, args.interval, args.ci_timeout)
            await queue_merge(pull_request)
            await wait_for_merge(pull_request.number, args.interval, args.merge_timeout)


if __name__ == "__main__":
    try:
        asyncio.run(main())
    except KeyboardInterrupt:
        raise SystemExit(130)
