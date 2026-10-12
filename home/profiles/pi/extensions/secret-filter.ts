import type { ExtensionAPI } from "@earendil-works/pi-coding-agent"

const SECRET_PATTERNS = [
  /SeCrEt-[a-zA-Z0-9\-_?!@&*+]+/g, // Locally generated secrets.
  /\bghp_[a-zA-Z0-9]{36}\b/g, // GitHub personal access tokens.
  /\bgithub_pat_[a-zA-Z0-9_]{22,}\b/g, // GitHub fine-grained tokens.
  /\bglpat-[a-zA-Z0-9\-_]{20,}\b/g, // GitLab personal access tokens.
  /\bsk-ant-[a-zA-Z0-9\-_]{20,}\b/g, // Anthropic API keys.
  /\bsk(?:-proj)?-[a-zA-Z0-9\-_]{20,}\b/g, // OpenAI API keys.
  /\bxox(?:[abprs]|app)-[a-zA-Z0-9\-]+\b/g, // Slack tokens.
  /\b(?:sk|rk)_live_[a-zA-Z0-9]+\b/g, // Stripe live keys.
  /\bAIza[a-zA-Z0-9\-_]{35}\b/g, // Google API keys.
  /\b(?:AKIA|ASIA)[A-Z0-9]{16}\b/g, // AWS access key IDs.
  /\bnpm_[a-zA-Z0-9]{36}\b/g, // npm access tokens.
  /\bpypi-[a-zA-Z0-9\-_]{20,}\b/g, // PyPI API tokens.
  /\bdckr_pat_[a-zA-Z0-9\-_]{20,}\b/g, // Docker personal access tokens.
  /\beyJ[a-zA-Z0-9_-]+\.[a-zA-Z0-9_-]+\.[a-zA-Z0-9_-]+\b/g, // JSON Web Tokens.
  /-----BEGIN(?: [A-Z]+)? PRIVATE KEY-----[\s\S]*?-----END(?: [A-Z]+)? PRIVATE KEY-----/g, // PEM private keys.
]

function redactSecrets(text: string): string {
  let redacted = text
  for (const pattern of SECRET_PATTERNS) {
    pattern.lastIndex = 0
    redacted = redacted.replace(pattern, "[REDACTED]")
  }
  return redacted
}

function redactValue(value: unknown): unknown {
  if (typeof value === "string") {
    return redactSecrets(value)
  }

  if (Array.isArray(value)) {
    return value.map(redactValue)
  }

  if (value && typeof value === "object") {
    return Object.fromEntries(
      Object.entries(value).map(([key, nestedValue]) => [key, redactValue(nestedValue)]),
    )
  }

  return value
}

function redactContent(content: unknown): unknown {
  if (!Array.isArray(content)) return content

  return content.map((part) => {
    if (!part || typeof part !== "object") return part

    const partRecord = part as Record<string, unknown>
    if (partRecord.type === "text" && typeof partRecord.text === "string") {
      return { ...partRecord, text: redactSecrets(partRecord.text) }
    }

    return redactValue(part)
  })
}

export default function (pi: ExtensionAPI) {
  pi.on("tool_result", async (event) => {
    return {
      content: redactContent(event.content) as typeof event.content,
      details: redactValue(event.details),
    }
  })
}
