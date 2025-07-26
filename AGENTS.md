# Development & Contribution Guide

This document spells out how to tackle tasks in the **Rails SaaS Starter Template** project.  It isn’t a legal contract – it’s a practical set of tips that help you deliver high‑quality work and keep the project moving.

## 1. Picking a task

1. **Review the project board.**  The [Rails SaaS Starter Template project board](https://github.com/users/mitchellfyi/projects/2) lists all open issues.  Each issue represents a discrete piece of work with a defined outcome.
2. **Choose something you can finish.**  Take an issue that matches your skillset and availability.  Don’t bite off more than you can chew – the goal is to complete tasks, not to hoard them.
3. **Clarify before you start.**  If the issue description is ambiguous, raise a question in the issue thread.  Better to surface assumptions early than to rework later.

## 2. Planning your work

1. **Break it down.**  Decompose the issue into smaller steps: API design, database migrations, models, views, controllers, background jobs, tests, etc.  Sketch the flow on paper or in a gist.
2. **Check existing patterns.**  This template emphasises consistency.  Look at existing modules (e.g. `ai/` or `billing/`) for conventions on naming, structure, and patterns.  Reuse helpers and libraries rather than inventing new ones.
3. **Consider maintainability.**  Avoid hacks and shortcuts.  Favour clear, modular code with a single responsibility.  Document assumptions and trade‑offs in the code comments or the issue thread.

## 3. Completing the task

1. **Work on a branch.**  Create a new branch off `main` with a descriptive name (`feature/mcp-fetcher`, `fix/ai-test-timeouts`, etc.).
2. **Implement iteratively.**  Commit early and often.  Keep commits focused on a single concern (e.g. one commit for models, one for controllers, one for tests).  Use meaningful commit messages – no “fix stuff”.
3. **Write tests first.**  Whether you use RSpec or Minitest, start with failing tests that capture the desired behaviour.  Include unit tests (models, services), integration tests (controllers, background jobs), and system tests where appropriate.
4. **Follow best practices.**  Use the latest Rails idioms.  Avoid N+1 queries, handle errors gracefully, and guard against security issues (SQL injection, mass assignment, cross‑site scripting).  Keep modules decoupled and respect boundaries.
5. **Document your changes.**  Update relevant README sections, API documentation, and module guides.  If you introduce a new environment variable or configuration flag, document it in `.env.example` and the deployment guides.

## 4. Testing & verification

1. **Run the full test suite.**  Use `bin/rails test` or `bundle exec rspec` depending on your chosen framework.  Run integration/system tests to verify user flows.  The continuous integration (CI) pipeline runs the template installation and full test suite; make sure it passes locally before pushing.
2. **Check code quality.**  Lint your code with RuboCop and run JavaScript linters (if you touched client code).  Fix style violations and warnings.
3. **Verify against the original task.**  Re‑read the issue description and ensure that your implementation covers all acceptance criteria.  Be critical: would you sign off on this change if someone else submitted it?
4. **Peer review.**  Open a pull request (PR) and request review from a colleague.  Incorporate feedback promptly.  Be open to changes – this project values collaborative improvement over ego.

## 5. Planning new project tasks

1. **Identify gaps.**  As you work, you may spot missing features or refactoring opportunities.  Don’t cram them into your current PR.  Instead, create a new issue in the project board with a clear title and description.
2. **Use the template.**  For each new task, follow the established structure: concise title, well‑scoped description, acceptance criteria, and links to relevant code or discussions.
3. **Prioritise impact.**  Not all tasks are equal.  Focus on items that deliver value to users or improve the codebase’s stability and maintainability.  Avoid “busy work”.

## 6. Final thoughts

This template is for serious engineers building AI‑native SaaS products.  Treat it like a real product: write robust code, test thoroughly, and be mindful of future maintainers.  Your contributions should make life easier for the next person who touches the code.
