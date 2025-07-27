# Development & Contribution Guide

This document spells out how to tackle tasks in the **Rails SaaS Starter Template** project. It isn’t a legal contract – it’s a practical set of tips that help you deliver high‑quality work and keep the project moving.

## 1. Planning your work

1. **Break it down.** Decompose the issue into smaller steps: API design, database migrations, models, views, controllers, background jobs, tests, etc. Sketch the flow on paper or in a gist.  
2. **Check existing patterns.** This template emphasises consistency. Look at existing modules (e.g. `ai/` or `billing/`) for conventions on naming, structure, and patterns. Reuse helpers and libraries rather than inventing new ones.  
3. **Consider maintainability.** Avoid hacks and shortcuts. Favour clear, modular code with a single responsibility. Document assumptions and trade‑offs in the code comments or the issue thread.

## 2. Completing the task

1. **Work on a branch.** Create a new branch off `main` with a descriptive name (`feature/mcp-fetcher`, `fix/ai-test-timeouts`, etc.).  
2. **Implement iteratively.** Commit early and often. Keep commits focused on a single concern.  
3. **Write tests first.** Include unit, integration, and system tests as needed.  
4. **Follow best practices.** Use latest Rails idioms. Avoid N+1 queries. Handle errors and edge cases gracefully.  
5. **Document your changes.** Update READMEs, module guides, `.env.example`, etc.  
6. **Integrate cross-cutting requirements.** Always verify your feature addresses:

   - **Security & Permissions**
   - **Audit Logging**
   - **Documentation**
   - **Accessibility (A11y)**
   - **SEO**
   - **Internationalization (i18n)**
   - **Testing**
   - **Health Checks & Debugging**
   - **UX & CX**
   - **Mobile Responsiveness**

## 3. Testing & verification

1. **Run the full test suite.** Ensure everything passes locally before pushing.  
2. **Check code quality.** Use RuboCop and JS linters.  
3. **Verify against the original task.** Be thorough and critical.  
4. **Peer review.** Open a PR, request feedback, and collaborate.

## 4. Planning new project tasks

1. **Identify gaps.** Log new ideas as separate issues.  
2. **Use the issue template.** Include title, scope, criteria.  
3. **Prioritise impact.** Focus on high-value work.

## 5. Final thoughts

Write robust, maintainable, well-documented, and tested code. You’re building something lasting and useful. Make it easy for others to follow your work.
