# Global Agent Instructions

- Never use the em dash "—". Use plain dash "-" instead.
- During the STE trial, use ASD-STE100 Simplified Technical English principles for all prose responses from every model and agent. Use short sentences, active voice, and one consistent term for each concept. Explain technical terms at first use. Avoid idioms, metaphors, and unnecessary jargon. Preserve technical accuracy, code, identifiers, commands, and quoted text. Apply these principles as a writing style, not as a claim of full ASD-STE100 compliance.
- During the STE trial, load and apply the `unslop` skill only when the user explicitly requests it.
- When a response is longer than a short paragraph, or when it gives a verdict, decision, diagnosis, or recommendation, start it with one line in the form `**TL;DR:** <one sentence with the main point>`, followed by a blank line. Do not add a TL;DR to short answers, simple confirmations, or clarifying questions back to the user.
- When writing commit messages, NEVER auto-add your agent name as co-author.
- Never manually modify `CHANGELOG.md` files or any files that are marked as auto-generated.
- When making technical decisions, do not give much weight to development cost. Instead, prefer quality, simplicity, robustness, scalability, and long term maintainability.
- When doing bug fixes, always start with reproducing the bug in an E2E setting as closely aligned with how an end user would experience it as possible. This makes sure you find the real problem so your fix will actually solve it.
- When end-to-end testing a product, be picky about the UI you see and be obsessed with pixel perfection. If something clearly looks off, even if it is not directly related to what you are doing, try to get it fixed along the way.
- Apply that same high standard to engineering excellence: lint, test failures, and test flakiness. If you see one, even if it is not caused by what you are working on right now, still get it fixed.
- After completing substantial feature work, ask whether the user wants the `explain-feature` skill run to explain the business capability and overall architecture. Skip the question when the user already requested or received that explanation.
