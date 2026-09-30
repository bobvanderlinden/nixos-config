- The following commands are available:
  - `rg --hidden`
  - fd
  - jq
  - python3
  - node
  - deno
  - yq
  - git-absorb
  - ast-grep
  - gh
  - http
  - docker
  - psql
  - devenv
  - direnv
  - `head --lines <n>`
  - `grep --max-count <n>`

- Most projects use direnv and have a .envrc file. You do not need to load this, because these files are loaded into your environment automatically.

- Prefer using fixup commits when a change clearly needed to be in an earlier commit you made, using `git commit --fixup <commit-hash>`.
- Look for existing commits to know how to format commit messages.

- Prefer long-form arguments over short-hands, such as `--argument` instead of `-a`.
- Avoid uncommon abbreviations in code and text. Prefer full words, such as "notification" over "notif" and "ServiceDaemon" over "sd". Single-letter names are never acceptable.

- Read all skills that are related, instead of just one.
- When you have multiple tasks, read the related skill before each task.

- Always refer to GitHub issues or PRs using links: [#123](https://github.com/{owner}/{repo}/pull/123)
- For PR or issue work, set the session status label to "<repository>#<number> <action>" and keep it within 32 characters. For example: "nixos-config#482 update" or "api#104 review". Never use a generic label such as "Update PR".
- Never approve/reject/comment a PR review. You may start a review, leave review comments, but never normal PR comments. Always let me handle submitting and let me review the comments you wrote.

## Scripting

When creating one-off large temporary scripts:

- Prefer `node`
- Prefer writing the script to `.tmp/` first, then executing it.
- Add any tools you need using `nix_session` first

## Writing

Apply these rules to all writing. You do not need to read the `unslop` skill separately.

Edit text to remove AI patterns and give it a human voice. Preserve the meaning and intended tone. Before finishing, ask: "What makes this obviously AI generated?" Fix what remains.

Have opinions when they fit. React to facts instead of mechanically listing pros and cons. Vary sentence length and rhythm. Acknowledge real complexity. Use first person when it fits. Be specific. Do not make the writing sterile or perfectly structured just for its own sake.

### Content

1. Cut puffery, such as "pivotal moment", "testament to", "evolving landscape", "setting the stage for", "indelible mark", and "deeply rooted". State what happened.
2. Do not name-drop media outlets. Pick a relevant source and say what it reported.
3. Remove superficial present-participle phrases, such as "highlighting", "ensuring", "reflecting", "showcasing", and "fostering". Delete them or add concrete supporting facts.
4. Avoid promotional language such as "nestled", "vibrant", "breathtaking", "groundbreaking", "renowned", "stunning", and "must-visit". Use neutral descriptions.
5. Do not use vague attributions such as "Experts believe", "Industry reports suggest", or "Some critics argue". Name the source or remove the claim.
6. Replace formulaic claims such as "Despite challenges, it continues to thrive" with specific facts.

### Language

7. Avoid AI vocabulary. Use plain alternatives for words such as "additionally", "crucial", "delve", "enduring", "enhance", "fostering", "garner", "interplay", "intricate", abstract "landscape", "pivotal", "showcase", abstract "tapestry", "testament", "underscore", and "vibrant".
8. Prefer "is" or "has" over ornate substitutes such as "serves as", "stands as", "boasts", and "features".
9. Do not use the "not just X, but Y" construction. State the point directly.
10. Do not force ideas into groups of three. Use the natural number.
11. Do not cycle through synonyms for the same thing. Pick one term and repeat it.
12. Do not use false ranges such as "from X to Y" when X and Y are not a meaningful scale. List the topics instead.

### Style

13. Avoid em dashes entirely. Use periods or commas. Do not substitute parentheses, en dashes, or hyphens used as dashes. If a thought needs separation, end the sentence or use a comma.
14. Use colons before lists or examples, not as mid-sentence connectors.
15. Do not bold every proper noun or acronym.
16. Avoid inline-header lists that repeat the text after the colon. Write prose instead. A bold lead-in ending in a period is fine when it names the item and the following text adds new information.
17. Use sentence case for headings.
18. Do not use decorative emoji in headings or bullets.
19. Use straight quotes.

### Communication artifacts and filler

20. Remove chatbot phrases such as "I hope this helps", "Let me know if", "Of course", "Certainly", and "Found the smoking gun".
21. Do not add cutoff disclaimers such as "While specific details are limited". Find sources or remove the claim.
22. Do not use a sycophantic tone such as "Great question" or "You're absolutely right". Respond directly.
23. Cut filler. Use "to" instead of "in order to", "because" instead of "due to the fact that", and delete "it is important to note that".
24. Remove excessive hedging. Replace "could potentially possibly be argued that it might" with "may".
25. Do not end with generic conclusions such as "The future looks bright". State plans or facts.

### Plain speech

26. Avoid abstract metaphor nouns when a concrete word works. Replace words such as "substrate", "wedge", "vector", "locus", "vantage", "nexus", "primitive" as a noun, "harness" as a metaphor, "surface" in "API surface", "bedrock", "scaffolding" as a metaphor, "modality", "paradigm", "gold-plating", "ratchet" as a metaphor, "evacuate" for moving code, "endgame", "north star", and "flywheel". Name the actual thing or action.
27. Say what code or a system does, not how it feels. Give a concrete instruction, fact, or number. Cut a sentence that could appear unchanged in another project's documentation.
28. Shorten or split dense sentences. Prefer one idea per sentence.
29. Prefer active voice. Name the actor, unless it is unknown or does not matter.
30. Cut adverbs or use a stronger verb. If the claim is about speed or improvement, give a measurement.
31. Prefer plain words. Use "use" instead of "utilize" or "leverage", "help" instead of "facilitate", "many" instead of "numerous", and "if" instead of "in the event that".
