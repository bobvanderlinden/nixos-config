import { tool } from "@opencode-ai/plugin";
import * as fs from "fs";
import * as path from "path";
import * as os from "os";
import { pathToFileURL } from "url";

interface SkillInfo {
  name: string;
  description: string;
  location: string;
  content: string;
}

function parseSkillFile(filepath: string): SkillInfo | undefined {
  const text = fs.readFileSync(filepath, "utf-8");

  // Parse YAML frontmatter
  const match = text.match(/^---\r?\n([\s\S]*?)\r?\n---\r?\n([\s\S]*)$/);
  if (!match) return undefined;

  const [, frontmatter, content] = match;

  // Simple YAML parsing for name and description
  const nameMatch = frontmatter.match(/^name:\s*(.+)$/m);
  const descMatch = frontmatter.match(/^description:\s*(.+)$/m);

  if (!nameMatch) return undefined;

  return {
    name: nameMatch[1].trim().replace(/^["']|["']$/g, ""),
    description: descMatch?.[1]?.trim().replace(/^["']|["']$/g, "") ?? "",
    location: filepath,
    content: content.trim(),
  };
}

function findSkillDirectories(): string[] {
  const home = os.homedir();
  const dirs: string[] = [];

  // OpenCode native paths
  const candidates = [
    path.join(home, ".config", "opencode", "skill"),
    path.join(home, ".config", "opencode", "skills"),
    path.join(home, ".opencode", "skill"),
    path.join(home, ".opencode", "skills"),
    // Claude-compatible paths
    path.join(home, ".claude", "skills"),
    // Agent-compatible paths
    path.join(home, ".agents", "skills"),
  ];

  for (const dir of candidates) {
    if (fs.existsSync(dir) && fs.statSync(dir).isDirectory()) {
      dirs.push(dir);
    }
  }

  return dirs;
}

function discoverSkills(): Map<string, SkillInfo> {
  const skills = new Map<string, SkillInfo>();
  const dirs = findSkillDirectories();

  for (const dir of dirs) {
    const entries = fs.readdirSync(dir, { withFileTypes: true });
    for (const entry of entries) {
      if (!entry.isDirectory()) continue;

      const skillPath = path.join(dir, entry.name, "SKILL.md");
      if (!fs.existsSync(skillPath)) continue;

      const skill = parseSkillFile(skillPath);
      if (skill && !skills.has(skill.name)) {
        skills.set(skill.name, skill);
      }
    }
  }

  return skills;
}

function listSkillFiles(dir: string, limit = 10): string[] {
  const files: string[] = [];

  function walk(current: string) {
    if (files.length >= limit) return;

    const entries = fs.readdirSync(current, { withFileTypes: true });
    for (const entry of entries) {
      if (files.length >= limit) return;

      const full = path.join(current, entry.name);
      if (entry.name === "SKILL.md") continue;

      if (entry.isDirectory()) {
        walk(full);
      } else {
        files.push(full);
      }
    }
  }

  walk(dir);
  return files;
}

// Discover skills at module load time
const allSkills = discoverSkills();
const skillList = Array.from(allSkills.values());

const examples = skillList
  .map((s) => `'${s.name}'`)
  .slice(0, 3)
  .join(", ");
const hint = examples.length > 0 ? ` (e.g., ${examples}, ...)` : "";

const description =
  skillList.length === 0
    ? "Load specialized skills that provide domain-specific instructions and workflows. No skills are currently available."
    : [
        "Load specialized skills that provide domain-specific instructions and workflows.",
        "",
        "When you recognize that a task matches one of the available skills listed below, use this tool to load the full skill instructions.",
        "",
        "The skill will inject detailed instructions, workflows, and access to bundled resources (scripts, references, templates) into the conversation context.",
        "",
        'Tool output includes `<skill_content name="...">` blocks with the loaded content.',
        "",
        "The following skills provide specialized sets of instructions for particular tasks.",
        "Invoke this tool to load skills when a task matches one of the available skills listed below:",
        "",
        "<available_skills>",
        ...skillList.flatMap((skill) => [
          `  <skill>`,
          `    <name>${skill.name}</name>`,
          `    <description>${skill.description}</description>`,
          `    <location>${pathToFileURL(skill.location).href}</location>`,
          `  </skill>`,
        ]),
        "</available_skills>",
      ].join("\n");

export default tool({
  description,
  args: {
    names: tool.schema
      .array(tool.schema.string())
      .describe(`The names of the skills to load from available_skills${hint}`),
  },
  async execute(params, ctx) {
    // Re-discover skills in case they changed
    const skills = discoverSkills();

    const results = params.names.map((name) => {
      const skill = skills.get(name);
      if (!skill) {
        const available = Array.from(skills.keys()).join(", ");
        return {
          name,
          error: `Skill "${name}" not found. Available skills: ${available || "none"}`,
        };
      }
      return { name, skill };
    });

    const errors = results.filter(
      (r): r is { name: string; error: string } => "error" in r,
    );
    if (errors.length === results.length) {
      throw new Error(errors.map((e) => e.error).join("\n"));
    }

    const valid = results.filter(
      (r): r is { name: string; skill: SkillInfo } => "skill" in r,
    );

    // Request permission for all skills
    await ctx.ask({
      permission: "skills",
      patterns: valid.map((r) => r.name),
      always: valid.map((r) => r.name),
      metadata: {},
    });

    const outputs = valid.map(({ skill }) => {
      const dir = path.dirname(skill.location);
      const base = pathToFileURL(dir).href;
      const files = listSkillFiles(dir)
        .map((f) => `<file>${f}</file>`)
        .join("\n");

      return [
        `<skill_content name="${skill.name}">`,
        `# Skill: ${skill.name}`,
        "",
        skill.content,
        "",
        `Base directory for this skill: ${base}`,
        "Relative paths in this skill (e.g., scripts/, reference/) are relative to this base directory.",
        "Note: file list is sampled.",
        "",
        "<skill_files>",
        files,
        "</skill_files>",
        "</skill_content>",
      ].join("\n");
    });

    const errorMessages =
      errors.length > 0
        ? [`\n<errors>\n${errors.map((e) => e.error).join("\n")}\n</errors>`]
        : [];

    return [...outputs, ...errorMessages].join("\n\n");
  },
});
