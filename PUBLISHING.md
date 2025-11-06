# Publishing Guide

This guide explains how to publish LLM Observatory packages to npm and crates.io.

## Table of Contents

- [Prerequisites](#prerequisites)
- [Publishing Node.js SDK to npm](#publishing-nodejs-sdk-to-npm)
- [Publishing Rust Crates to crates.io](#publishing-rust-crates-to-cratesio)
- [Versioning Strategy](#versioning-strategy)
- [Troubleshooting](#troubleshooting)

## Prerequisites

### For npm Publishing

1. **npm Account**: Create an account at [npmjs.com](https://www.npmjs.com/)
2. **Organization**: Create `@llm-observatory` organization (or use your own)
3. **npm Token**: Generate an automation token:
   ```bash
   npm login
   npm token create --type=automation
   ```
4. **GitHub Secret**: Add token as `NPM_TOKEN` in repository secrets:
   - Go to Settings → Secrets and variables → Actions
   - New repository secret: `NPM_TOKEN`

### For crates.io Publishing

1. **crates.io Account**: Create account at [crates.io](https://crates.io/)
2. **API Token**: Generate token in Account Settings
3. **GitHub Secret**: Add token as `CARGO_REGISTRY_TOKEN`:
   - Go to Settings → Secrets and variables → Actions
   - New repository secret: `CARGO_REGISTRY_TOKEN`

### GitHub Environments

Set up environments for additional protection:

1. Go to Settings → Environments
2. Create `npm-publishing` environment
3. Create `crates-io-publishing` environment
4. Add required reviewers for manual approval (recommended)

## Publishing Node.js SDK to npm

### Automatic Publishing (Recommended)

1. **Navigate to Actions**:
   - Go to Actions → Publish Node.js SDK to npm

2. **Run Workflow**:
   - Click "Run workflow"
   - Set version (e.g., `0.1.0`)
   - Choose tag (`latest`, `beta`, or `next`)
   - Enable dry run for testing
   - Click "Run workflow"

3. **Verify Dry Run**:
   - Check workflow output
   - Review package contents
   - Ensure tests pass

4. **Publish for Real**:
   - Run workflow again with dry run disabled
   - Package will be published to npm
   - Git tag will be created
   - GitHub release will be created

### Manual Publishing

```bash
# Navigate to SDK directory
cd sdk/nodejs

# Install dependencies
npm ci

# Run tests
npm test

# Run linting
npm run lint

# Build package
npm run build

# Update version
npm version 0.1.0 --no-git-tag-version

# Test package contents
npm pack --dry-run

# Publish (dry run)
npm publish --tag latest --dry-run

# Publish for real
npm publish --tag latest --access public

# Create git tag
git tag -a sdk-nodejs-v0.1.0 -m "Release Node.js SDK v0.1.0"
git push origin sdk-nodejs-v0.1.0
```

## Publishing Rust Crates to crates.io

### Automatic Publishing (Recommended)

1. **Navigate to Actions**:
   - Go to Actions → Publish Rust Crates to crates.io

2. **Run Workflow**:
   - Click "Run workflow"
   - Set version (e.g., `0.1.0`)
   - Choose crates to publish:
     - `all` - publishes all crates
     - `core,providers,storage` - specific crates (comma-separated)
   - Enable dry run for testing
   - Click "Run workflow"

3. **Verify Dry Run**:
   - Check workflow output
   - Review package contents
   - Ensure tests pass

4. **Publish for Real**:
   - Run workflow again with dry run disabled
   - Crates will be published in dependency order
   - Git tag will be created
   - GitHub release will be created

### Manual Publishing

```bash
# Login to crates.io
cargo login <your-token>

# Update version in workspace Cargo.toml
sed -i 's/^version = .*/version = "0.1.0"/' Cargo.toml

# Run tests
cargo test --workspace

# Run formatting
cargo fmt --all

# Run clippy
cargo clippy --all-targets --all-features

# Publish in dependency order
cd crates/core
cargo publish --dry-run  # Test first
cargo publish            # Publish for real
cd ../..

# Wait for propagation (30-60 seconds)
sleep 60

# Publish providers (depends on core)
cd crates/providers
cargo publish
cd ../..

sleep 60

# Publish storage (depends on core)
cd crates/storage
cargo publish
cd ../..

sleep 60

# Publish collector (depends on core, providers)
cd crates/collector
cargo publish
cd ../..

sleep 60

# Publish SDK (depends on core, providers)
cd crates/sdk
cargo publish
cd ../..

# Create git tag
git tag -a v0.1.0 -m "Release v0.1.0"
git push origin v0.1.0
```

## Versioning Strategy

We follow [Semantic Versioning 2.0.0](https://semver.org/):

- **MAJOR** version (X.0.0): Incompatible API changes
- **MINOR** version (0.X.0): Backwards-compatible functionality
- **PATCH** version (0.0.X): Backwards-compatible bug fixes

### Pre-release Versions

- **Alpha**: `0.1.0-alpha.1` - Early development
- **Beta**: `0.1.0-beta.1` - Feature complete, testing
- **RC**: `0.1.0-rc.1` - Release candidate

### Version Alignment

Keep all packages aligned when possible:

- Node.js SDK: `@llm-observatory/sdk@0.1.0`
- Rust crates: All at `0.1.0`

## Publishing Checklist

### Before Publishing

- [ ] All tests passing
- [ ] Documentation updated
- [ ] CHANGELOG.md updated
- [ ] Version bumped in all relevant files
- [ ] No uncommitted changes
- [ ] Dry run successful

### Node.js SDK Specific

- [ ] TypeScript builds without errors
- [ ] All exports are correct
- [ ] README.md is up to date
- [ ] Examples work
- [ ] LICENSE file included

### Rust Crates Specific

- [ ] `cargo fmt` passes
- [ ] `cargo clippy` passes with no warnings
- [ ] `cargo test` passes
- [ ] All README.md files exist
- [ ] Dependencies are published first
- [ ] Inter-crate version numbers match

### After Publishing

- [ ] Verify package on npm/crates.io
- [ ] Test installation in clean environment
- [ ] GitHub release created
- [ ] Documentation site updated
- [ ] Announce on social media/blog

## Troubleshooting

### npm Publishing Issues

**Error: "You must be logged in to publish packages"**
```bash
# Re-authenticate
npm login
```

**Error: "Package already exists"**
```bash
# Version already published, bump version
npm version patch  # or minor, major
```

**Error: "403 Forbidden"**
- Check npm token has publish permissions
- Verify organization membership
- Check package name availability

### crates.io Publishing Issues

**Error: "failed to get a 200 OK response"**
- Wait 60 seconds for previous crate to propagate
- Retry publish command

**Error: "another version is currently being published"**
- Wait a few minutes and retry
- Check crates.io status page

**Error: "failed to verify"**
- Ensure dependencies are published first
- Check dependency versions match

**Error: "repository URL not found"**
- Verify `repository` field in Cargo.toml
- Ensure repository is public

### General Issues

**Build Failures**
```bash
# Clean and rebuild
cargo clean
npm run clean

# Fresh install
rm -rf node_modules package-lock.json
npm install
```

**Test Failures**
- Fix all tests before publishing
- Run tests in CI environment
- Check for environment-specific issues

## Resources

- [npm Publishing Guide](https://docs.npmjs.com/packages-and-modules/contributing-packages-to-the-registry)
- [crates.io Publishing Guide](https://doc.rust-lang.org/cargo/reference/publishing.html)
- [Semantic Versioning](https://semver.org/)
- [GitHub Actions Docs](https://docs.github.com/en/actions)

## Support

For issues or questions:
- GitHub Issues: https://github.com/globalbusinessadvisors/llm-observatory/issues
- Discussions: https://github.com/globalbusinessadvisors/llm-observatory/discussions
