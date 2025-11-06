#!/bin/bash
# Version bumping script for LLM Observatory
# Usage: ./scripts/bump-version.sh [patch|minor|major] [npm|rust|all]

set -e

VERSION_TYPE=${1:-patch}  # patch, minor, or major
PACKAGE=${2:-all}         # npm, rust, or all

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${GREEN}🔄 Bumping version: $VERSION_TYPE${NC}"

# Function to bump npm version
bump_npm() {
    echo -e "${YELLOW}📦 Bumping Node.js SDK version...${NC}"
    cd sdk/nodejs

    # Bump version using npm
    NEW_VERSION=$(npm version $VERSION_TYPE --no-git-tag-version | sed 's/v//')

    echo -e "${GREEN}✅ Node.js SDK version bumped to: $NEW_VERSION${NC}"
    cd ../..

    return 0
}

# Function to bump Rust version
bump_rust() {
    echo -e "${YELLOW}🦀 Bumping Rust crates version...${NC}"

    # Get current version
    CURRENT_VERSION=$(grep -m1 '^version = ' Cargo.toml | sed 's/version = "\(.*\)"/\1/')

    # Split version into parts
    IFS='.' read -ra VERSION_PARTS <<< "$CURRENT_VERSION"
    MAJOR=${VERSION_PARTS[0]}
    MINOR=${VERSION_PARTS[1]}
    PATCH=${VERSION_PARTS[2]}

    # Bump version based on type
    case $VERSION_TYPE in
        major)
            MAJOR=$((MAJOR + 1))
            MINOR=0
            PATCH=0
            ;;
        minor)
            MINOR=$((MINOR + 1))
            PATCH=0
            ;;
        patch)
            PATCH=$((PATCH + 1))
            ;;
        *)
            echo -e "${RED}❌ Invalid version type: $VERSION_TYPE${NC}"
            echo "Use: patch, minor, or major"
            exit 1
            ;;
    esac

    NEW_VERSION="$MAJOR.$MINOR.$PATCH"

    # Update workspace Cargo.toml
    sed -i "s/^version = \".*\"/version = \"$NEW_VERSION\"/" Cargo.toml

    echo -e "${GREEN}✅ Rust crates version bumped to: $NEW_VERSION${NC}"

    return 0
}

# Main logic
case $PACKAGE in
    npm)
        bump_npm
        ;;
    rust)
        bump_rust
        ;;
    all)
        bump_npm
        bump_rust
        ;;
    *)
        echo -e "${RED}❌ Invalid package type: $PACKAGE${NC}"
        echo "Use: npm, rust, or all"
        exit 1
        ;;
esac

echo ""
echo -e "${GREEN}✅ Version bump complete!${NC}"
echo ""
echo "Next steps:"
echo "  1. Review changes: git diff"
echo "  2. Commit changes: git add -A && git commit -m 'chore: bump version to $VERSION_TYPE'"
echo "  3. Push to main: git push origin main"
echo "  4. Auto-publish will trigger automatically!"
echo ""
