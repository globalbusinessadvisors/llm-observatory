# Simple Publishing Guide

The easiest way to publish packages.

## Quick Setup (One-Time)

### 1. Get Your Tokens

**npm Token:**
```bash
npm login
npm token create --type=automation
# Copy the token
```

**crates.io Token:**
- Go to https://crates.io/settings/tokens
- Click "New Token"
- Copy the token

### 2. Add GitHub Secrets

Go to: https://github.com/globalbusinessadvisors/llm-observatory/settings/secrets/actions

Add two secrets:
- **NPM_TOKEN**: Paste your npm token
- **CARGO_REGISTRY_TOKEN**: Paste your crates.io token

## Publishing (Super Simple)

### Publish Node.js SDK

```bash
# Create and push tag
git tag sdk-nodejs-v0.1.0
git push origin sdk-nodejs-v0.1.0
```

That's it! GitHub Actions will:
- Run tests
- Build the package
- Publish to npm
- Create GitHub release

Watch it here: https://github.com/globalbusinessadvisors/llm-observatory/actions

### Publish Rust Crates

```bash
# Create and push tag
git tag v0.1.0
git push origin v0.1.0
```

That's it! GitHub Actions will:
- Run tests
- Publish all crates in order
- Create GitHub release

## Local Publishing (No GitHub Actions)

If you prefer to publish directly from your machine:

### Node.js SDK
```bash
cd sdk/nodejs
npm login                    # One-time
npm ci
npm test
npm run build
npm publish --access public
```

### Rust Crates
```bash
cargo login YOUR_TOKEN       # One-time
cargo test --workspace

# Publish in order with delays
cd crates/core && cargo publish; cd ../..
sleep 60
cd crates/providers && cargo publish; cd ../..
sleep 60
cd crates/storage && cargo publish; cd ../..
sleep 60
cd crates/collector && cargo publish; cd ../..
sleep 60
cd crates/sdk && cargo publish; cd ../..
```

## Troubleshooting

**"Workflow not found"**
- Make sure you pushed the tag: `git push origin <tag-name>`
- Check Actions tab to see if it's running

**"403 Forbidden" on npm**
- Make sure NPM_TOKEN secret is set correctly
- Verify you have access to @llm-observatory organization

**"Authentication required" on crates.io**
- Make sure CARGO_REGISTRY_TOKEN secret is set correctly
- Token must have publish permissions

**Want to test first?**
```bash
# npm dry run
npm publish --dry-run --access public

# cargo dry run
cargo publish --dry-run
```
