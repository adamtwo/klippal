# Contributing to KlipPal

Thank you for your interest in contributing to KlipPal! This document provides guidelines and instructions for contributing.

## Code of Conduct

This project adheres to the [Contributor Covenant Code of Conduct](CODE_OF_CONDUCT.md). By participating, you are expected to uphold this code.

## How Can I Contribute?

### Reporting Bugs

Before creating a bug report, please check existing issues to avoid duplicates.

When creating a bug report, include:

- **Clear title** describing the issue
- **Steps to reproduce** the behavior
- **Expected behavior** vs what actually happened
- **macOS version** and KlipPal version
- **Screenshots** if applicable
- **Console logs** if relevant (from Console.app filtering for "KlipPal")

### Suggesting Features

Feature requests are welcome! Please:

- Check existing issues first
- Describe the feature and its use case
- Explain why this would be useful to most users
- Consider how it fits with KlipPal's privacy-first philosophy

### Pull Requests

1. **Fork the repository** and create your branch from `main`
2. **Follow the code style** of the existing codebase
3. **Add tests** for new functionality
4. **Ensure tests pass** (`swift test`)
5. **Update documentation** if needed
6. **Write a clear PR description** explaining the changes

## Development Setup

### Prerequisites

- macOS 13.0 or later
- Xcode 15.0 or later
- Swift 5.9 or later

### Building

```bash
# Clone the repository
git clone https://github.com/adamtwo/klippal.git
cd klippal

# Build the project
swift build

# Run the app
.build/debug/KlipPal
```

### Running Tests

```bash
# Run all tests
swift test

# Run specific test
swift test --filter TestClassName
```

### Granting Permissions

KlipPal requires Accessibility permissions to function. After building:

1. Open System Settings > Privacy & Security > Accessibility
2. Add the built binary (`.build/debug/KlipPal`)
3. Enable the toggle

Note: You may need to re-grant permissions after rebuilding.

## Code Guidelines

### Swift Style

- Use Swift's standard naming conventions
- Prefer `let` over `var` when possible
- Use meaningful variable and function names
- Add documentation comments for public APIs

### Architecture

- Follow the existing modular architecture (see `CLAUDE.md` for details)
- Keep components loosely coupled
- Use async/await for asynchronous operations
- Maintain thread safety with actors where appropriate

### Commits

- Write clear, concise commit messages
- Use present tense ("Add feature" not "Added feature")
- Reference issues when applicable (`Fixes #123`)

## Questions?

Feel free to open an issue for any questions about contributing.
