#!/usr/bin/env python3
import json
import subprocess
import time

QUERY = '''query {
  viewer {
    login
  }
  authored: search(query: "is:open is:pr archived:false author:@me", type: ISSUE, first: 40) {
    nodes {
      ... on PullRequest {
        number
        title
        url
        updatedAt
        isDraft
        reviewDecision
        mergeable
        mergeStateStatus
        repository {
          name
          isArchived
        }
        statusCheckRollup {
          state
        }
        reviewThreads(first: 100) {
          nodes {
            isResolved
          }
        }
        reviewRequests(first: 1) {
          totalCount
        }
      }
    }
  }
  reviewRequested: search(query: "is:open is:pr archived:false review-requested:@me", type: ISSUE, first: 100) {
    nodes {
      ... on PullRequest {
        number
        title
        url
        updatedAt
        repository {
          name
          isArchived
        }
        reviewRequests(first: 100) {
          nodes {
            requestedReviewer {
              __typename
              ... on User {
                login
              }
            }
          }
        }
      }
    }
  }
}'''

CATEGORY_ORDER = (
    "reviewRequests",
    "teamReviewRequests",
    "drafts",
    "needsReviewers",
    "waitingForReview",
    "needsAction",
    "approvedNeedsAction",
    "readyToMerge",
)


def summary(pull_request):
    return {
        "number": pull_request["number"],
        "title": pull_request["title"],
        "repository": pull_request["repository"]["name"],
        "url": pull_request["url"],
        "updatedAt": pull_request["updatedAt"],
    }


def has_unresolved_review_threads(pull_request):
    return any(
        not thread["isResolved"]
        for thread in pull_request["reviewThreads"]["nodes"]
    )


def needs_action(pull_request):
    check_rollup = pull_request["statusCheckRollup"] or {}
    return (
        pull_request["mergeable"] == "CONFLICTING"
        or pull_request["mergeStateStatus"] in ("DIRTY", "BEHIND")
        or pull_request["reviewDecision"] == "CHANGES_REQUESTED"
        or check_rollup.get("state") in ("FAILURE", "ERROR")
        or has_unresolved_review_threads(pull_request)
    )


def ready_to_merge(pull_request):
    check_rollup = pull_request["statusCheckRollup"]
    return (
        pull_request["reviewDecision"] == "APPROVED"
        and pull_request["mergeable"] == "MERGEABLE"
        and pull_request["mergeStateStatus"] == "CLEAN"
        and (check_rollup is None or check_rollup["state"] == "SUCCESS")
    )


def classify_authored_pull_request(pull_request):
    if pull_request["isDraft"]:
        return "drafts"
    if needs_action(pull_request):
        if pull_request["reviewDecision"] == "APPROVED":
            return "approvedNeedsAction"
        return "needsAction"
    if ready_to_merge(pull_request):
        return "readyToMerge"
    if pull_request["reviewRequests"]["totalCount"] == 0:
        return "needsReviewers"
    return "waitingForReview"


def is_archived(pull_request):
    return pull_request["repository"]["isArchived"]


def build_inbox(data):
    inbox = {category: [] for category in CATEGORY_ORDER}
    seen_urls = set()

    def add(category, pull_request):
        if pull_request["url"] in seen_urls:
            return
        inbox[category].append(summary(pull_request))
        seen_urls.add(pull_request["url"])

    viewer_login = data["viewer"]["login"]
    for pull_request in data["reviewRequested"]["nodes"]:
        if is_archived(pull_request):
            continue
        reviewers = [
            request["requestedReviewer"]
            for request in pull_request["reviewRequests"]["nodes"]
        ]
        if any(
            reviewer["__typename"] == "User"
            and reviewer["login"] == viewer_login
            for reviewer in reviewers
        ):
            add("reviewRequests", pull_request)
        elif any(reviewer["__typename"] == "Team" for reviewer in reviewers):
            add("teamReviewRequests", pull_request)

    for pull_request in data["authored"]["nodes"]:
        if not is_archived(pull_request):
            add(classify_authored_pull_request(pull_request), pull_request)

    return inbox


def main():
    for attempt in range(3):
        response = subprocess.run(
            ["gh", "api", "graphql", "--raw-field", f"query={QUERY}"],
            capture_output=True,
            text=True,
        )
        if response.returncode == 0:
            print(json.dumps(build_inbox(json.loads(response.stdout)["data"])))
            return
        if attempt < 2:
            time.sleep(attempt + 1)

    message = response.stderr.strip() or "gh api graphql failed"
    raise SystemExit(f"gh-inbox: {message}")


if __name__ == "__main__":
    main()
