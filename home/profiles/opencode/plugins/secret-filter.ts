import type { Plugin } from "@opencode-ai/plugin";

const SECRET_PATTERN = /SeCrEt-[a-zA-Z0-9\-_?!@&*+]+/g;

function redactSecrets(text: string): string {
  // Reset regex lastIndex since global flag persists state
  SECRET_PATTERN.lastIndex = 0;
  return text.replace(SECRET_PATTERN, "[REDACTED]");
}

export const SecretFilterPlugin: Plugin = async () => {
  return {
    "tool.execute.after": async (_input, output) => {
      if (typeof output.output === "string") {
        output.output = redactSecrets(output.output);
      }
    },
  };
};
