#!/bin/bash

# Frontend Setup Verification Script
# This script verifies that all necessary files are in place

echo "=========================================="
echo "Frontend Setup Verification"
echo "=========================================="
echo ""

# Color codes
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Counters
PASSED=0
FAILED=0

# Function to check if file exists
check_file() {
    if [ -f "$1" ]; then
        echo -e "${GREEN}✓${NC} $1"
        ((PASSED++))
    else
        echo -e "${RED}✗${NC} $1 (MISSING)"
        ((FAILED++))
    fi
}

# Function to check if directory exists
check_dir() {
    if [ -d "$1" ]; then
        echo -e "${GREEN}✓${NC} $1/"
        ((PASSED++))
    else
        echo -e "${RED}✗${NC} $1/ (MISSING)"
        ((FAILED++))
    fi
}

echo "Checking Configuration Files..."
check_file "package.json"
check_file "tsconfig.json"
check_file "tsconfig.node.json"
check_file "vite.config.ts"
check_file "tailwind.config.js"
check_file "postcss.config.js"
check_file ".eslintrc.cjs"
check_file ".env.example"
check_file ".gitignore"
check_file "index.html"
echo ""

echo "Checking Source Directories..."
check_dir "src"
check_dir "src/api"
check_dir "src/components"
check_dir "src/components/Analytics"
check_dir "src/components/Chat"
check_dir "src/components/KnowledgeBase"
check_dir "src/components/Layout"
check_dir "src/pages"
check_dir "src/stores"
check_dir "src/types"
check_dir "src/utils"
echo ""

echo "Checking Core Files..."
check_file "src/App.tsx"
check_file "src/main.tsx"
check_file "src/index.css"
echo ""

echo "Checking API Layer..."
check_file "src/api/client.ts"
check_file "src/api/websocket.ts"
echo ""

echo "Checking Type Definitions..."
check_file "src/types/index.ts"
echo ""

echo "Checking State Stores..."
check_file "src/stores/chatStore.ts"
check_file "src/stores/analyticsStore.ts"
check_file "src/stores/knowledgeBaseStore.ts"
echo ""

echo "Checking Analytics Components..."
check_file "src/components/Analytics/Dashboard.tsx"
check_file "src/components/Analytics/CostChart.tsx"
check_file "src/components/Analytics/PerformanceChart.tsx"
check_file "src/components/Analytics/ModelUsageChart.tsx"
check_file "src/components/Analytics/DateRangePicker.tsx"
echo ""

echo "Checking Chat Components..."
check_file "src/components/Chat/ChatInterface.tsx"
check_file "src/components/Chat/MessageList.tsx"
check_file "src/components/Chat/MessageInput.tsx"
check_file "src/components/Chat/ConversationSidebar.tsx"
echo ""

echo "Checking Knowledge Base Components..."
check_file "src/components/KnowledgeBase/DocumentList.tsx"
check_file "src/components/KnowledgeBase/DocumentUpload.tsx"
echo ""

echo "Checking Layout Components..."
check_file "src/components/Layout/Layout.tsx"
check_file "src/components/Layout/Sidebar.tsx"
echo ""

echo "Checking Pages..."
check_file "src/pages/ChatPage.tsx"
check_file "src/pages/AnalyticsPage.tsx"
check_file "src/pages/KnowledgeBasePage.tsx"
check_file "src/pages/SettingsPage.tsx"
echo ""

echo "Checking Utilities..."
check_file "src/utils/cn.ts"
check_file "src/utils/formatters.ts"
echo ""

echo "Checking Documentation..."
check_file "README.md"
check_file "IMPLEMENTATION_SUMMARY.md"
echo ""

# Summary
echo "=========================================="
echo "Verification Summary"
echo "=========================================="
echo -e "${GREEN}Passed: $PASSED${NC}"
if [ $FAILED -gt 0 ]; then
    echo -e "${RED}Failed: $FAILED${NC}"
else
    echo -e "${GREEN}Failed: $FAILED${NC}"
fi
echo ""

if [ $FAILED -eq 0 ]; then
    echo -e "${GREEN}✓ All files are in place!${NC}"
    echo ""
    echo "Next steps:"
    echo "1. npm install"
    echo "2. cp .env.example .env.local"
    echo "3. npm run dev"
    exit 0
else
    echo -e "${RED}✗ Some files are missing. Please check the errors above.${NC}"
    exit 1
fi
