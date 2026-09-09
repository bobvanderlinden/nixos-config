import type { ExtensionAPI } from "@earendil-works/pi-coding-agent"

const SECRET_PATTERN = /SeCrEt-[a-zA-Z0-9\-_?!@&*+]+/g

function redactSecrets(text: string): string {
  SECRET_PATTERN.lastIndex = 0
  return text.replace(SECRET_PATTERN, "[REDACTED]")
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
