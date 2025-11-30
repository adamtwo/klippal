# Security Policy

## Supported Versions

| Version | Supported          |
| ------- | ------------------ |
| 1.x.x   | :white_check_mark: |

## Reporting a Vulnerability

We take security vulnerabilities seriously. If you discover a security issue in KlipPal, please report it responsibly.

### How to Report

1. **Do not** open a public GitHub issue for security vulnerabilities
2. Instead, use [GitHub's private vulnerability reporting](https://github.com/adamtwo/klippal/security/advisories/new) to submit your report
3. Alternatively, you can report via GitHub Issues with the "security" label if the vulnerability is not critical

### What to Include

Please provide as much information as possible:

- Description of the vulnerability
- Steps to reproduce
- Potential impact
- Suggested fix (if any)

### Response Timeline

- **Initial Response**: Within 48 hours
- **Status Update**: Within 7 days
- **Resolution Target**: Within 30 days for critical issues

### What to Expect

1. You will receive an acknowledgment of your report
2. We will investigate and validate the issue
3. We will work on a fix and coordinate disclosure timing with you
4. You will be credited in the security advisory (unless you prefer to remain anonymous)

## Security Best Practices

KlipPal is designed with privacy and security in mind:

- **Local-only storage**: All clipboard data is stored locally on your device
- **No network access**: The app does not transmit any data over the network
- **No telemetry**: No usage data or analytics are collected
- **Sensitive data detection**: The app attempts to detect and warn about potentially sensitive content (passwords, API keys)

## Scope

This security policy applies to:

- The KlipPal macOS application
- Official releases distributed through this repository

Third-party forks or modifications are not covered by this policy.
