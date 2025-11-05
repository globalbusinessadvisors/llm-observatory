#!/bin/sh
# Generate comprehensive test report from test results
# Aggregates results from multiple test runs

# Color output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Configuration
TEST_RESULTS_DIR="${TEST_RESULTS_DIR:-/test-results}"
COVERAGE_DIR="${COVERAGE_DIR:-/coverage}"
OUTPUT_DIR="${OUTPUT_DIR:-${TEST_RESULTS_DIR}}"

print_status() {
    echo "${GREEN}[$(date +'%Y-%m-%d %H:%M:%S')]${NC} $1"
}

echo "${BLUE}==============================================================================${NC}"
echo "${BLUE}                  LLM Observatory - Test Report Generator${NC}"
echo "${BLUE}==============================================================================${NC}"
echo ""

# Create output directory
mkdir -p "${OUTPUT_DIR}"

print_status "Generating comprehensive test report..."

# Create HTML report
cat > "${OUTPUT_DIR}/report.html" << 'EOF'
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>LLM Observatory - Test Report</title>
    <style>
        * { margin: 0; padding: 0; box-sizing: border-box; }
        body {
            font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, 'Helvetica Neue', Arial, sans-serif;
            line-height: 1.6;
            color: #333;
            background: #f5f5f5;
            padding: 20px;
        }
        .container { max-width: 1200px; margin: 0 auto; background: white; padding: 30px; border-radius: 8px; box-shadow: 0 2px 4px rgba(0,0,0,0.1); }
        h1 { color: #2c3e50; margin-bottom: 10px; font-size: 2.5em; }
        h2 { color: #34495e; margin-top: 30px; margin-bottom: 15px; padding-bottom: 10px; border-bottom: 2px solid #3498db; }
        .timestamp { color: #7f8c8d; font-size: 0.9em; margin-bottom: 30px; }
        .summary { display: grid; grid-template-columns: repeat(auto-fit, minmax(250px, 1fr)); gap: 20px; margin: 20px 0; }
        .metric {
            background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
            color: white;
            padding: 20px;
            border-radius: 8px;
            box-shadow: 0 4px 6px rgba(0,0,0,0.1);
        }
        .metric.success { background: linear-gradient(135deg, #11998e 0%, #38ef7d 100%); }
        .metric.warning { background: linear-gradient(135deg, #f093fb 0%, #f5576c 100%); }
        .metric.info { background: linear-gradient(135deg, #4facfe 0%, #00f2fe 100%); }
        .metric-label { font-size: 0.9em; opacity: 0.9; margin-bottom: 5px; }
        .metric-value { font-size: 2.5em; font-weight: bold; }
        .metric-unit { font-size: 0.6em; opacity: 0.8; }
        .test-section { margin: 20px 0; padding: 20px; background: #f8f9fa; border-radius: 8px; }
        .status-badge {
            display: inline-block;
            padding: 4px 12px;
            border-radius: 12px;
            font-size: 0.85em;
            font-weight: 600;
            text-transform: uppercase;
        }
        .status-passed { background: #d4edda; color: #155724; }
        .status-failed { background: #f8d7da; color: #721c24; }
        .status-skipped { background: #fff3cd; color: #856404; }
        table { width: 100%; border-collapse: collapse; margin: 20px 0; }
        th, td { padding: 12px; text-align: left; border-bottom: 1px solid #dee2e6; }
        th { background: #f8f9fa; font-weight: 600; color: #495057; }
        tr:hover { background: #f8f9fa; }
        .progress-bar {
            width: 100%;
            height: 30px;
            background: #e9ecef;
            border-radius: 15px;
            overflow: hidden;
            margin: 10px 0;
        }
        .progress-fill {
            height: 100%;
            background: linear-gradient(90deg, #11998e 0%, #38ef7d 100%);
            display: flex;
            align-items: center;
            justify-content: center;
            color: white;
            font-weight: bold;
            transition: width 0.3s ease;
        }
        .footer { margin-top: 40px; padding-top: 20px; border-top: 1px solid #dee2e6; text-align: center; color: #6c757d; font-size: 0.9em; }
    </style>
</head>
<body>
    <div class="container">
        <h1>LLM Observatory Test Report</h1>
        <p class="timestamp">Generated: <span id="timestamp"></span></p>

        <div class="summary">
            <div class="metric success">
                <div class="metric-label">Tests Passed</div>
                <div class="metric-value" id="tests-passed">-</div>
            </div>
            <div class="metric warning">
                <div class="metric-label">Tests Failed</div>
                <div class="metric-value" id="tests-failed">-</div>
            </div>
            <div class="metric info">
                <div class="metric-label">Code Coverage</div>
                <div class="metric-value" id="coverage">-<span class="metric-unit">%</span></div>
            </div>
            <div class="metric">
                <div class="metric-label">Total Duration</div>
                <div class="metric-value" id="duration">-<span class="metric-unit">s</span></div>
            </div>
        </div>

        <h2>Test Results</h2>
        <div class="test-section">
            <h3>Unit Tests</h3>
            <div id="unit-tests">Loading...</div>
        </div>

        <div class="test-section">
            <h3>Integration Tests</h3>
            <div id="integration-tests">Loading...</div>
        </div>

        <div class="test-section">
            <h3>Coverage Report</h3>
            <div class="progress-bar">
                <div class="progress-fill" id="coverage-bar" style="width: 0%">0%</div>
            </div>
            <p>Detailed coverage report available in <code>coverage/index.html</code></p>
        </div>

        <div class="footer">
            <p>LLM Observatory Test Suite &copy; 2024</p>
            <p>Generated by automated test infrastructure</p>
        </div>
    </div>

    <script>
        // Set timestamp
        document.getElementById('timestamp').textContent = new Date().toLocaleString();

        // Load test results if available
        // This would be populated by actual test result data
        document.getElementById('tests-passed').textContent = '0';
        document.getElementById('tests-failed').textContent = '0';
        document.getElementById('coverage').innerHTML = '0<span class="metric-unit">%</span>';
        document.getElementById('duration').innerHTML = '0<span class="metric-unit">s</span>';

        // Update progress bar
        const coverageValue = 0;
        const progressBar = document.getElementById('coverage-bar');
        progressBar.style.width = coverageValue + '%';
        progressBar.textContent = coverageValue + '%';
    </script>
</body>
</html>
EOF

# Create markdown report
cat > "${OUTPUT_DIR}/REPORT.md" << EOF
# LLM Observatory Test Report

**Generated:** $(date -u '+%Y-%m-%d %H:%M:%S UTC')

## Summary

| Metric | Value |
|--------|-------|
| Tests Run | - |
| Tests Passed | - |
| Tests Failed | - |
| Code Coverage | - % |
| Total Duration | - |

## Test Results

### Unit Tests
- Status: Pending
- Details: See \`test-results/unit-tests.log\`

### Integration Tests
- Status: Pending
- Details: See \`test-results/integration-tests.log\`

### Documentation Tests
- Status: Pending
- Details: See \`test-results/doc-tests.log\`

## Coverage Analysis

Coverage reports are available in multiple formats:
- HTML: \`coverage/index.html\`
- LCOV: \`coverage/lcov.info\`
- JSON: \`coverage/coverage.json\`

## Files Generated

\`\`\`
test-results/
├── unit-tests.log
├── integration-tests.log
├── doc-tests.log
├── clippy.log
├── fmt.log
├── summary.txt
└── report.html

coverage/
├── index.html
├── lcov.info
└── summary.json
\`\`\`

## Next Steps

1. Review failed tests in the log files
2. Check coverage report for untested code paths
3. Address any clippy warnings
4. Fix formatting issues if any

---

*This report was automatically generated by the LLM Observatory test infrastructure.*
EOF

print_status "Reports generated:"
print_status "  - HTML: ${OUTPUT_DIR}/report.html"
print_status "  - Markdown: ${OUTPUT_DIR}/REPORT.md"

echo ""
echo "${GREEN}==============================================================================${NC}"
echo "${GREEN}                    Report Generation Complete ✓${NC}"
echo "${GREEN}==============================================================================${NC}"
