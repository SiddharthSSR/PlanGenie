# Contributing to PlanGenie

Thank you for taking the time to contribute! The goal of this document is to make sure every change ships with the same level of quality across mockups, the Next.js prototype, and the Flutter client.

## Prerequisites
- Node.js 18+ for the web prototypes
- Flutter 3.16+ (stable channel) for the mobile client
- An environment configured with `flutter doctor`

## Getting Started
1. Fork the repository and create a feature branch off `main`.
2. Keep changes focused; separate unrelated fixes into their own pull requests.
3. Make sure any new UI work is represented in the relevant mockup or documented in the README when appropriate.

## Required Checks Before You Push
- **Static analysis**: run `flutter analyze` inside `flutter-app/`.
- **Formatting**: run `dart format --set-exit-if-changed .` from `flutter-app/` and ensure no diff remains.
- **Web projects**: if you touched `mockup/` or `mockup-next/`, run `npm run lint` and `npm test` (if applicable).

## Pull Request Checklist
- [ ] Format and lint checks (`dart format`, `flutter analyze`) noted in the PR description.
- [ ] Updated documentation and mockups as needed.
- [ ] Screenshots or screen recordings included for notable UI changes.
- [ ] Clear summary of the change, risks, and rollback plan.

## Commit Guidelines
- Use present tense for commit messages (e.g., "Add home screen layout").
- Reference issues or tickets using `Fixes #123` when applicable.
- Keep commits scoped and avoid bundling unrelated changes.

## Code Review Expectations
- Be respectful; assume positive intent.
- Call out potential regressions and add follow-up issues when necessary.
- Prefer suggestions over directives when giving feedback.

## Release Process
1. Ensure the main branch is green in CI.
2. Tag the release with `vX.Y.Z` and document noteworthy changes in the project README or release notes.
3. Communicate with the team before shipping major UX updates.

Thanks again for helping build PlanGenie! Feel free to open an issue if anything in this document is unclear.
