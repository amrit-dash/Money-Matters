# Security Policy

## Supported versions

Security fixes are applied to the active development branch (`main`) and the latest tagged release when one exists. Older branches and one-off forks are not supported unless agreed with the maintainer.

| Version | Supported          |
| ------- | ------------------ |
| latest on `main` | :white_check_mark: |
| older tags / forks | :x: |

## Reporting a vulnerability

If you discover a security issue in Money Matters (the Flutter app, Firebase rules, Cloud Functions, ingest endpoints, signing, or related tooling), please report it responsibly.

**Do not** open a public GitHub issue for security vulnerabilities. Public disclosure before a fix can put users at risk.

### How to report

1. Email **amrit.dash60@gmail.com** with a clear description of the issue.
2. Include steps to reproduce, affected components (app, Firebase, Shortcuts ingest, etc.), and impact if known.
3. If you have a suggested fix or patch, you may include it; it is not required.

### What to expect

- **Acknowledgment** within a few business days.
- **Assessment** of severity and affected scope.
- **Updates** on remediation status when practical.
- **Credit** in release notes or advisories if you want it and the report is valid (optional).

We ask that you:

- Give us reasonable time to investigate and ship a fix before public disclosure.
- Avoid accessing, modifying, or deleting data that is not yours.
- Avoid denial-of-service attacks, spam, or social engineering against maintainers or users.

## Scope

In scope examples:

- Authentication or authorization bypass (Firebase Auth, device ingest tokens, Firestore rules)
- Ingest endpoint abuse, token leakage, or unsafe handling of SMS/payload data
- Remote code execution, injection, or unsafe deserialization in app or functions
- Sensitive data exposure in logs, backups, or client storage

Out of scope examples (still welcome as regular bugs, not security reports):

- Issues in third-party services outside this repository’s control
- Physical device access or jailbreak-only scenarios without a realistic app threat model
- Missing security headers or best-practice hardening with no demonstrated exploit

## Safe harbor

Good-faith security research that follows this policy will not be pursued as malicious activity. Reports that clearly violate law or user privacy may be referred appropriately.

Thank you for helping keep Money Matters and its users safe.
