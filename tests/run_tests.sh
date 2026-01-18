#!/bin/bash
# Test Runner for Claude Account Switcher
# Run all unit tests in a clean environment

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

# Get script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo ""
echo "╔════════════════════════════════════════════════════════════╗"
echo "║  Claude Account Switcher - Test Runner                    ║"
echo "╚════════════════════════════════════════════════════════════╝"
echo ""

# Check if jq is available
if ! command -v jq &> /dev/null; then
    echo -e "${YELLOW}Warning: jq not found. Some tests may be skipped.${NC}"
    echo "Install jq for better test coverage:"
    echo "  brew install jq"
    echo ""
fi

# Run the tests
bash "$SCRIPT_DIR/test_claude_switch.bats" "$@"
EXIT_CODE=$?

echo ""
if [ $EXIT_CODE -eq 0 ]; then
    echo -e "${GREEN}✓ All tests passed!${NC}"
else
    echo -e "${RED}✗ Some tests failed.${NC}"
fi

exit $EXIT_CODE
