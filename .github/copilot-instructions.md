# GitHub Copilot Instructions

## Core Development Principles

### Conventional Commit Messages (REQUIRED)

**ALL commits MUST use [Conventional Commits](https://www.conventionalcommits.org/en/v1.0.0/) specification.**

- Format: `<type>[optional scope]: <description>`
- Types: `feat`, `fix`, `docs`, `style`, `refactor`, `test`, `chore`
- Examples:
  - `feat: add new **user facing** functionality`
  - `fix: resolves a **user facing** bug or issue`
  - `test: add comprehensive tests for config validation`
  - `docs: update README with new installation steps`
  - `refactor: improve code structure without changing behavior`
  - `chore: anything that does not belong in the other categories`

The commit message types directly relate to version changes which then result in the users having to update.
We want to minimize the impact on users, so we only want to change the version when there is a user facing change.

**Commits not following this specification will be rejected.**

### Code Quality and Architecture

#### Software Hygiene
- **Boy Scout Rule**: Leave code cleaner than you found it
- Clear separation of concerns
- Meaningful variable and function names
- Proper error handling
- No magic numbers or hardcoded values
- Follow existing patterns and conventions

### Linting and Formatting

- Ensure code is formatted in an idiomatic and consistent way for the project

### Documentation

- Document all new features and changes
- Update README.md when adding new functionality
- Maintain consistent language and style
- Update relevant ADR files when making architectural decisions

## When in Doubt

**DO NOT make assumptions or guess.** Instead:

1. Research the existing codebase for similar patterns
2. Check the ADR documentation in `doc/adr/`
3. Review the README.md and CONTRIBUTING.md
4. Ask for clarification from the team

**Never make things up or implement solutions without understanding the requirements.**

**Remember: These are not suggestions - they are requirements. Adherence to these standards is mandatory for all contributions.**
