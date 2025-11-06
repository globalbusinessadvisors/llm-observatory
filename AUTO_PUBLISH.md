# Automatic Publishing Guide

LLM Observatory packages are **automatically published** when you bump the version and push to main.

## 🚀 How It Works

1. **You bump the version** (locally or via script)
2. **Push to main branch**
3. **GitHub Actions detects the version change**
4. **Runs tests automatically**
5. **Publishes to npm/crates.io if tests pass**
6. **Creates git tags and GitHub releases**

All automatic! 🎉

## Quick Start

### Option 1: Use the Version Bump Script (Recommended)

```bash
# Bump patch version for both npm and Rust (0.1.0 → 0.1.1)
./scripts/bump-version.sh patch all

# Review the changes
git diff

# Commit and push
git add -A
git commit -m "chore: bump version to 0.1.1"
git push origin main

# ✅ Auto-publishes!
```

### Option 2: Manual Version Bump

#### Bump Node.js SDK Only

```bash
cd sdk/nodejs
npm version patch  # or minor, or major
cd ../..
git add sdk/nodejs/package.json
git commit -m "chore: bump Node.js SDK to 0.1.1"
git push origin main
```

#### Bump Rust Crates Only

```bash
# Edit Cargo.toml - change this line:
# version = "0.1.0"  →  version = "0.1.1"

git add Cargo.toml
git commit -m "chore: bump Rust crates to 0.1.1"
git push origin main
```

#### Bump Both

```bash
# Bump npm
cd sdk/nodejs && npm version patch && cd ../..

# Bump Rust (edit Cargo.toml manually)
sed -i 's/^version = "0.1.0"/version = "0.1.1"/' Cargo.toml

# Commit and push
git add -A
git commit -m "chore: bump version to 0.1.1"
git push origin main
```

## Version Bump Types

| Type | Example | Use Case |
|------|---------|----------|
| **patch** | 0.1.0 → 0.1.1 | Bug fixes, documentation |
| **minor** | 0.1.0 → 0.2.0 | New features, backward-compatible |
| **major** | 0.1.0 → 1.0.0 | Breaking changes |

```bash
# Patch (bug fixes)
./scripts/bump-version.sh patch all

# Minor (new features)
./scripts/bump-version.sh minor all

# Major (breaking changes)
./scripts/bump-version.sh major all
```

## What Gets Published

### When npm version changes:
- ✅ Runs: lint, tests, build
- ✅ Publishes to: https://www.npmjs.com/package/@llm-observatory/sdk
- ✅ Creates tag: `sdk-nodejs-v{version}`
- ✅ Creates GitHub release

### When Rust version changes:
- ✅ Runs: tests, clippy
- ✅ Publishes to: https://crates.io (all 5 crates in dependency order)
- ✅ Creates tag: `v{version}`
- ✅ Creates GitHub release

## Monitoring Auto-Publish

Watch the workflow:
https://github.com/globalbusinessadvisors/llm-observatory/actions

You'll see:
- ✅ **Check versions** - Detects what changed
- ✅ **Publish npm** - If Node.js SDK version changed
- ✅ **Publish crates** - If Rust version changed

## Safety Features

✅ **Only publishes on version change** - Won't republish same version
✅ **Tests must pass** - Fails if tests don't pass
✅ **Lint must pass** - Code quality checked
✅ **Automatic git tags** - Creates version tags
✅ **GitHub releases** - Auto-generates release notes

## Workflow Triggers

The auto-publish workflow runs on push to main when these files change:
- `sdk/nodejs/package.json` - Node.js SDK
- `Cargo.toml` - Rust crates workspace version
- `crates/**/Cargo.toml` - Individual crate versions

## Example Workflow

Let's say you fixed a bug:

```bash
# 1. Fix the bug
vim src/some-file.rs

# 2. Run tests locally
cargo test

# 3. Bump version
./scripts/bump-version.sh patch rust

# 4. Commit with conventional commit message
git add -A
git commit -m "fix: resolve connection timeout issue"

# 5. Push to main
git push origin main

# 6. ✨ Magic happens:
#    - GitHub Actions detects Rust version changed
#    - Runs tests (they pass!)
#    - Publishes all 5 crates to crates.io
#    - Creates git tag v0.1.1
#    - Creates GitHub release
```

Check https://github.com/globalbusinessadvisors/llm-observatory/actions to watch it happen!

## Troubleshooting

### "Tests failed"
- Fix the tests before pushing
- Run `npm test` or `cargo test` locally first

### "Already published"
- Version already exists on npm/crates.io
- Bump to next version and try again

### "Authentication failed"
- Check GitHub secrets are set:
  - `NPM_TOKEN` for npm publishing
  - `CARGO_REGISTRY_TOKEN` for crates.io
- Go to: Settings → Secrets and variables → Actions

### "Workflow didn't trigger"
- Make sure you pushed to `main` branch
- Check that version actually changed in package.json or Cargo.toml
- View workflow runs: https://github.com/globalbusinessadvisors/llm-observatory/actions

## One-Time Setup Required

Before auto-publishing works, you need to set up secrets:

**NPM_TOKEN**:
```bash
npm login
npm token create --type=automation
# Copy token and add as GitHub secret
```

**CARGO_REGISTRY_TOKEN**:
- Go to https://crates.io/settings/tokens
- Create new token
- Copy and add as GitHub secret

Add secrets here:
https://github.com/globalbusinessadvisors/llm-observatory/settings/secrets/actions

## Disabling Auto-Publish

If you want to temporarily disable auto-publishing:

1. Go to: https://github.com/globalbusinessadvisors/llm-observatory/actions/workflows/auto-publish.yml
2. Click "..." menu
3. Select "Disable workflow"

Re-enable the same way when ready.

## Manual Override

You can still publish manually if needed:

```bash
# npm
cd sdk/nodejs && npm publish --access public

# Rust
cargo publish -p llm-observatory-core
```

But with auto-publish, you shouldn't need to! 🎉

## Best Practices

✅ **DO**: Bump version when making changes
✅ **DO**: Use conventional commits (fix:, feat:, chore:)
✅ **DO**: Test locally before pushing
✅ **DO**: Review auto-publish logs

❌ **DON'T**: Push to main without bumping version (won't publish)
❌ **DON'T**: Manually create tags (auto-publish does this)
❌ **DON'T**: Skip tests ("tests will pass in CI" - they won't!)

## Resources

- [Semantic Versioning](https://semver.org/)
- [Conventional Commits](https://www.conventionalcommits.org/)
- [npm Publishing](https://docs.npmjs.com/packages-and-modules/contributing-packages-to-the-registry)
- [crates.io Publishing](https://doc.rust-lang.org/cargo/reference/publishing.html)
