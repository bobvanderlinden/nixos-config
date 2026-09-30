import type { ExtensionAPI } from "@earendil-works/pi-coding-agent"
import { existsSync, readdirSync } from "node:fs"
import { dirname, join, resolve } from "node:path"

// Pi normally stops skill discovery at the first project boundary. Load
// .agents/skills from every parent directory instead.
function findSkillPaths(cwd: string): string[] {
  const skillPaths: string[] = []
  let directory = resolve(cwd)

  while (true) {
    const skillsDirectory = join(directory, ".agents", "skills")

    if (existsSync(skillsDirectory)) {
      // Add the nearest directory first, so its skills win name collisions.
      skillPaths.push(skillsDirectory)

      // Explicitly add root Markdown files because directory discovery only
      // finds nested SKILL.md files in this non-standard location.
      for (const entry of readdirSync(skillsDirectory, { withFileTypes: true })) {
        if (entry.isFile() && entry.name.endsWith(".md")) {
          skillPaths.push(join(skillsDirectory, entry.name))
        }
      }
    }

    const parentDirectory = dirname(directory)
    if (parentDirectory === directory) {
      return skillPaths
    }

    directory = parentDirectory
  }
}

export default function (pi: ExtensionAPI) {
  pi.on("resources_discover", (event) => ({
    skillPaths: findSkillPaths(event.cwd),
  }))
}
