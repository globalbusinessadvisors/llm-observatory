# Contributing to LLM Observatory

Thank you for your interest in contributing to LLM Observatory! We welcome contributions from the community.

## Code of Conduct

This project adheres to a code of conduct that all contributors are expected to follow. Please be respectful and professional in all interactions.

## Developer Certificate of Origin (DCO)

This project uses the Developer Certificate of Origin (DCO) to ensure that contributors have the legal right to submit their contributions.

### What is DCO?

The DCO is a lightweight way for contributors to certify that they wrote or otherwise have the right to submit the code they are contributing. You can read the full text at [developercertificate.org](https://developercertificate.org/).

### How to Sign Your Commits

To sign your commits, add the `-s` flag when committing:

```bash
git commit -s -m "Add new feature"
```

This adds a "Signed-off-by" line to your commit message:

```
Add new feature

Signed-off-by: Your Name <your.email@example.com>
```

### Automatic Sign-off

You can configure Git to automatically sign your commits:

```bash
git config --global format.signOff true
```

### DCO Enforcement

All commits must be signed off. Pull requests with unsigned commits will be blocked until all commits are properly signed.

## Getting Started

1. **Fork the repository** on GitHub
2. **Clone your fork** locally:
   ```bash
   git clone https://github.com/YOUR_USERNAME/llm-observatory.git
   cd llm-observatory
   ```
3. **Set up the development environment**:
   ```bash
   # Install Rust (1.75.0 or later)
   curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh

   # Install development dependencies
   cargo install cargo-watch cargo-nextest
   ```
4. **Create a branch** for your changes:
   ```bash
   git checkout -b feature/your-feature-name
   ```

## Development Workflow

### Building

```bash
# Build all crates
cargo build

# Build with optimizations
cargo build --release

# Build specific crate
cargo build -p llm-observatory-collector
```

### Testing

```bash
# Run all tests
cargo test

# Run tests with nextest (faster)
cargo nextest run

# Run tests for specific crate
cargo test -p llm-observatory-core

# Run integration tests
cargo test --test '*'
```

### Code Quality

```bash
# Format code
cargo fmt

# Check formatting without modifying
cargo fmt -- --check

# Run clippy lints
cargo clippy --all-targets --all-features -- -D warnings

# Run all checks (formatting, clippy, tests)
cargo make verify  # if using cargo-make
```

### Running Locally

```bash
# Start development environment with Docker Compose
docker-compose up -d

# Run the collector
cargo run -p llm-observatory-collector -- --config config/dev.yaml

# Run the API server
cargo run -p llm-observatory-api -- --port 8080
```

## Project Structure

```
llm-observatory/
├── crates/
│   ├── collector/       # OTLP collector with PII redaction
│   ├── core/            # Shared core types and utilities
│   ├── storage/         # Database interfaces and implementations
│   ├── api/             # REST API server
│   ├── sdk/             # SDK for instrumenting applications
│   ├── providers/       # LLM provider integrations
│   └── cli/             # Command-line interface
├── docs/                # Documentation
├── examples/            # Example integrations
├── helm/                # Kubernetes Helm charts
└── docker/              # Docker configurations
```

## Contribution Guidelines

### Code Style

- Follow Rust standard style guidelines (enforced by `rustfmt`)
- Write idiomatic Rust code
- Add documentation comments (`///`) for public APIs
- Keep functions focused and concise
- Use meaningful variable and function names

### Documentation

- Update documentation for any user-facing changes
- Add examples for new features
- Update the CHANGELOG.md with your changes
- Ensure all public APIs have documentation

### Testing

- Write unit tests for new functionality
- Add integration tests for complex features
- Ensure all tests pass before submitting PR
- Aim for high test coverage (>80%)

### Commit Messages

Write clear, concise commit messages following this format:

```
<type>(<scope>): <subject>

<body>

<footer>
```

Types:
- `feat`: New feature
- `fix`: Bug fix
- `docs`: Documentation changes
- `style`: Code style changes (formatting)
- `refactor`: Code refactoring
- `test`: Adding or updating tests
- `chore`: Maintenance tasks

Example:
```
feat(collector): add PII redaction processor

Implement automatic PII detection and redaction for trace data
using regex patterns and ML-based entity recognition.

Closes #123

Signed-off-by: Your Name <your.email@example.com>
```

### Pull Request Process

1. **Ensure all tests pass** and code is formatted
2. **Update documentation** as needed
3. **Add entries to CHANGELOG.md** under "Unreleased"
4. **Sign all commits** with DCO
5. **Submit the pull request** with a clear description
6. **Respond to review feedback** promptly
7. **Squash commits** if requested before merge

### PR Description Template

```markdown
## Description
Brief description of changes

## Type of Change
- [ ] Bug fix
- [ ] New feature
- [ ] Breaking change
- [ ] Documentation update

## Testing
Describe testing performed

## Checklist
- [ ] Code follows project style guidelines
- [ ] Self-review completed
- [ ] Comments added for complex code
- [ ] Documentation updated
- [ ] No new warnings generated
- [ ] Tests added/updated
- [ ] All tests passing
- [ ] CHANGELOG.md updated
- [ ] All commits signed with DCO
```

## Reporting Issues

### Bug Reports

When reporting bugs, please include:

- LLM Observatory version
- Operating system and version
- Rust version
- Steps to reproduce
- Expected behavior
- Actual behavior
- Relevant logs or error messages

### Feature Requests

When requesting features:

- Describe the problem you're trying to solve
- Explain why existing features don't work
- Provide examples of how the feature would be used
- Consider proposing an implementation approach

## Areas for Contribution

We welcome contributions in these areas:

- **Provider Integrations**: Add support for new LLM providers
- **Evaluators**: Implement new quality metrics and evaluators
- **Documentation**: Improve guides, examples, and API docs
- **Performance**: Optimize critical paths
- **Testing**: Increase test coverage
- **Examples**: Add integration examples for popular frameworks
- **Visualizations**: Enhance dashboards and reports
- **Security**: Improve PII detection, secret handling, authentication

## Questions?

- **GitHub Discussions**: For questions and discussions
- **GitHub Issues**: For bug reports and feature requests
- **Documentation**: Check the [docs](./docs) directory

## License

By contributing to LLM Observatory, you agree that your contributions will be licensed under the Apache License 2.0.

Thank you for contributing to LLM Observatory!
