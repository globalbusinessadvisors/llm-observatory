#!/bin/bash

# Knowledge Base API - Setup Validation Script
# This script validates that all required components are properly configured

set -e

echo "🔍 Knowledge Base API - Setup Validation"
echo "========================================"
echo ""

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Check functions
check_pass() {
    echo -e "${GREEN}✓${NC} $1"
}

check_fail() {
    echo -e "${RED}✗${NC} $1"
}

check_warn() {
    echo -e "${YELLOW}⚠${NC} $1"
}

# 1. Check Node.js version
echo "1. Checking Node.js version..."
if command -v node &> /dev/null; then
    NODE_VERSION=$(node -v | cut -d 'v' -f 2)
    REQUIRED_VERSION="20.0.0"
    if [ "$(printf '%s\n' "$REQUIRED_VERSION" "$NODE_VERSION" | sort -V | head -n1)" = "$REQUIRED_VERSION" ]; then
        check_pass "Node.js version: $NODE_VERSION (>= 20.0.0)"
    else
        check_fail "Node.js version: $NODE_VERSION (requires >= 20.0.0)"
        exit 1
    fi
else
    check_fail "Node.js not found"
    exit 1
fi
echo ""

# 2. Check npm version
echo "2. Checking npm version..."
if command -v npm &> /dev/null; then
    NPM_VERSION=$(npm -v)
    check_pass "npm version: $NPM_VERSION"
else
    check_fail "npm not found"
    exit 1
fi
echo ""

# 3. Check if dependencies are installed
echo "3. Checking dependencies..."
if [ -d "node_modules" ]; then
    check_pass "node_modules directory exists"
else
    check_warn "node_modules not found - run 'npm install'"
fi
echo ""

# 4. Check environment configuration
echo "4. Checking environment configuration..."
if [ -f ".env" ]; then
    check_pass ".env file exists"

    # Check for required variables
    if grep -q "OPENAI_API_KEY=" .env; then
        if grep -q "OPENAI_API_KEY=your-openai-api-key" .env || grep -q "OPENAI_API_KEY=$" .env; then
            check_warn "OPENAI_API_KEY is not set in .env"
        else
            check_pass "OPENAI_API_KEY is configured"
        fi
    else
        check_warn "OPENAI_API_KEY not found in .env"
    fi
else
    check_warn ".env file not found - copy from .env.example"
fi
echo ""

# 5. Check Qdrant connectivity
echo "5. Checking Qdrant connectivity..."
QDRANT_URL="${QDRANT_URL:-http://localhost:6333}"
if command -v curl &> /dev/null; then
    if curl -s -f "${QDRANT_URL}/health" > /dev/null 2>&1; then
        check_pass "Qdrant is accessible at ${QDRANT_URL}"
    else
        check_warn "Qdrant not accessible at ${QDRANT_URL}"
        echo "   Start Qdrant: docker run -p 6333:6333 qdrant/qdrant"
    fi
else
    check_warn "curl not found - cannot check Qdrant connectivity"
fi
echo ""

# 6. Check TypeScript compilation
echo "6. Checking TypeScript setup..."
if [ -f "tsconfig.json" ]; then
    check_pass "tsconfig.json exists"
    if [ -d "node_modules/typescript" ]; then
        check_pass "TypeScript is installed"
    else
        check_warn "TypeScript not found in node_modules"
    fi
else
    check_fail "tsconfig.json not found"
fi
echo ""

# 7. Check source files
echo "7. Checking source files..."
REQUIRED_FILES=(
    "src/index.ts"
    "src/app.ts"
    "src/config.ts"
    "src/services/QdrantService.ts"
    "src/services/EmbeddingService.ts"
    "src/services/DocumentService.ts"
    "src/services/SearchService.ts"
)

for file in "${REQUIRED_FILES[@]}"; do
    if [ -f "$file" ]; then
        check_pass "$file"
    else
        check_fail "$file not found"
    fi
done
echo ""

# 8. Check test setup
echo "8. Checking test setup..."
if [ -f "jest.config.js" ]; then
    check_pass "jest.config.js exists"
else
    check_fail "jest.config.js not found"
fi

if [ -d "tests" ]; then
    TEST_COUNT=$(find tests -name "*.test.ts" | wc -l)
    check_pass "Found $TEST_COUNT test files"
else
    check_warn "tests directory not found"
fi
echo ""

# 9. Check documentation
echo "9. Checking documentation..."
DOC_FILES=("README.md" "API.md" "IMPLEMENTATION_SUMMARY.md")
for doc in "${DOC_FILES[@]}"; do
    if [ -f "$doc" ]; then
        check_pass "$doc exists"
    else
        check_warn "$doc not found"
    fi
done
echo ""

# 10. Check Docker setup
echo "10. Checking Docker setup..."
if [ -f "Dockerfile" ]; then
    check_pass "Dockerfile exists"
else
    check_warn "Dockerfile not found"
fi
echo ""

# Summary
echo "========================================"
echo "Validation complete!"
echo ""
echo "Next steps:"
echo "1. Install dependencies: npm install"
echo "2. Configure environment: cp .env.example .env && edit .env"
echo "3. Start Qdrant: docker run -p 6333:6333 qdrant/qdrant"
echo "4. Run tests: npm test"
echo "5. Start development: npm run dev"
echo ""
echo "Documentation:"
echo "- README.md - General information and quick start"
echo "- API.md - Complete API documentation"
echo "- IMPLEMENTATION_SUMMARY.md - Implementation details"
