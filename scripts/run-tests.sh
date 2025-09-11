#!/bin/bash

# SyncHook Test Runner
# This script runs all tests with different configurations

set -e

echo "🧪 SyncHook Test Suite Runner"
echo "=============================="

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to print colored output
print_status() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Check if forge is installed
if ! command -v forge &> /dev/null; then
    print_error "Foundry is not installed. Please install it first."
    exit 1
fi

# Check if we're in the right directory
if [ ! -f "foundry.toml" ]; then
    print_error "Please run this script from the SyncHook project root directory."
    exit 1
fi

# Parse command line arguments
RUN_UNIT=true
RUN_INTEGRATION=true
RUN_FUZZ=true
RUN_INVARIANT=true
RUN_COVERAGE=false
VERBOSE=false
PROFILE="default"

while [[ $# -gt 0 ]]; do
    case $1 in
        --unit-only)
            RUN_INTEGRATION=false
            RUN_FUZZ=false
            RUN_INVARIANT=false
            shift
            ;;
        --integration-only)
            RUN_UNIT=false
            RUN_FUZZ=false
            RUN_INVARIANT=false
            shift
            ;;
        --fuzz-only)
            RUN_UNIT=false
            RUN_INTEGRATION=false
            RUN_INVARIANT=false
            shift
            ;;
        --invariant-only)
            RUN_UNIT=false
            RUN_INTEGRATION=false
            RUN_FUZZ=false
            shift
            ;;
        --coverage)
            RUN_COVERAGE=true
            PROFILE="coverage"
            shift
            ;;
        --verbose)
            VERBOSE=true
            shift
            ;;
        --profile)
            PROFILE="$2"
            shift 2
            ;;
        --help)
            echo "Usage: $0 [OPTIONS]"
            echo ""
            echo "Options:"
            echo "  --unit-only        Run only unit tests"
            echo "  --integration-only Run only integration tests"
            echo "  --fuzz-only        Run only fuzz tests"
            echo "  --invariant-only   Run only invariant tests"
            echo "  --coverage         Run with coverage analysis"
            echo "  --verbose          Enable verbose output"
            echo "  --profile PROFILE  Use specific profile (default, ci, lite, coverage)"
            echo "  --help             Show this help message"
            exit 0
            ;;
        *)
            print_error "Unknown option: $1"
            exit 1
            ;;
    esac
done

# Set up test environment
print_status "Setting up test environment..."

# Clean previous builds
print_status "Cleaning previous builds..."
forge clean

# Build contracts
print_status "Building contracts..."
if [ "$VERBOSE" = true ]; then
    forge build --force
else
    forge build --force > /dev/null 2>&1
fi

print_success "Contracts built successfully"

# Run tests based on configuration
TOTAL_TESTS=0
PASSED_TESTS=0
FAILED_TESTS=0

# Function to run tests and capture results
run_tests() {
    local test_type=$1
    local test_pattern=$2
    local test_name=$3
    
    print_status "Running $test_name..."
    
    local start_time=$(date +%s)
    
    if [ "$VERBOSE" = true ]; then
        if forge test --profile $PROFILE --match-path "$test_pattern" --no-match-contract ".*Fuzz.*|.*Invariant.*"; then
            local end_time=$(date +%s)
            local duration=$((end_time - start_time))
            print_success "$test_name completed in ${duration}s"
            ((PASSED_TESTS++))
        else
            local end_time=$(date +%s)
            local duration=$((end_time - start_time))
            print_error "$test_name failed after ${duration}s"
            ((FAILED_TESTS++))
        fi
    else
        if forge test --profile $PROFILE --match-path "$test_pattern" --no-match-contract ".*Fuzz.*|.*Invariant.*" > /dev/null 2>&1; then
            local end_time=$(date +%s)
            local duration=$((end_time - start_time))
            print_success "$test_name completed in ${duration}s"
            ((PASSED_TESTS++))
        else
            local end_time=$(date +%s)
            local duration=$((end_time - start_time))
            print_error "$test_name failed after ${duration}s"
            ((FAILED_TESTS++))
        fi
    fi
    
    ((TOTAL_TESTS++))
}

# Function to run fuzz tests
run_fuzz_tests() {
    local test_type=$1
    local test_pattern=$2
    local test_name=$3
    
    print_status "Running $test_name..."
    
    local start_time=$(date +%s)
    
    if [ "$VERBOSE" = true ]; then
        if forge test --profile $PROFILE --match-path "$test_pattern" --match-contract ".*Fuzz.*"; then
            local end_time=$(date +%s)
            local duration=$((end_time - start_time))
            print_success "$test_name completed in ${duration}s"
            ((PASSED_TESTS++))
        else
            local end_time=$(date +%s)
            local duration=$((end_time - start_time))
            print_error "$test_name failed after ${duration}s"
            ((FAILED_TESTS++))
        fi
    else
        if forge test --profile $PROFILE --match-path "$test_pattern" --match-contract ".*Fuzz.*" > /dev/null 2>&1; then
            local end_time=$(date +%s)
            local duration=$((end_time - start_time))
            print_success "$test_name completed in ${duration}s"
            ((PASSED_TESTS++))
        else
            local end_time=$(date +%s)
            local duration=$((end_time - start_time))
            print_error "$test_name failed after ${duration}s"
            ((FAILED_TESTS++))
        fi
    fi
    
    ((TOTAL_TESTS++))
}

# Function to run invariant tests
run_invariant_tests() {
    local test_type=$1
    local test_pattern=$2
    local test_name=$3
    
    print_status "Running $test_name..."
    
    local start_time=$(date +%s)
    
    if [ "$VERBOSE" = true ]; then
        if forge test --profile $PROFILE --match-path "$test_pattern" --match-contract ".*Invariant.*"; then
            local end_time=$(date +%s)
            local duration=$((end_time - start_time))
            print_success "$test_name completed in ${duration}s"
            ((PASSED_TESTS++))
        else
            local end_time=$(date +%s)
            local duration=$((end_time - start_time))
            print_error "$test_name failed after ${duration}s"
            ((FAILED_TESTS++))
        fi
    else
        if forge test --profile $PROFILE --match-path "$test_pattern" --match-contract ".*Invariant.*" > /dev/null 2>&1; then
            local end_time=$(date +%s)
            local duration=$((end_time - start_time))
            print_success "$test_name completed in ${duration}s"
            ((PASSED_TESTS++))
        else
            local end_time=$(date +%s)
            local duration=$((end_time - start_time))
            print_error "$test_name failed after ${duration}s"
            ((FAILED_TESTS++))
        fi
    fi
    
    ((TOTAL_TESTS++))
}

# Run unit tests
if [ "$RUN_UNIT" = true ]; then
    run_tests "unit" "test/unit/*.t.sol" "Unit Tests"
fi

# Run integration tests
if [ "$RUN_INTEGRATION" = true ]; then
    run_tests "integration" "test/integration/*.t.sol" "Integration Tests"
fi

# Run fuzz tests
if [ "$RUN_FUZZ" = true ]; then
    run_fuzz_tests "fuzz" "test/fuzz/*.t.sol" "Fuzz Tests"
fi

# Run invariant tests
if [ "$RUN_INVARIANT" = true ]; then
    run_invariant_tests "invariant" "test/invariant/*.t.sol" "Invariant Tests"
fi

# Run coverage analysis if requested
if [ "$RUN_COVERAGE" = true ]; then
    print_status "Running coverage analysis..."
    
    if command -v lcov &> /dev/null; then
        forge coverage --profile $PROFILE --report lcov
        if [ -f "lcov.info" ]; then
            genhtml lcov.info --output-directory coverage
            print_success "Coverage report generated in coverage/index.html"
        fi
    else
        print_warning "lcov not found, skipping coverage report generation"
    fi
fi

# Print summary
echo ""
echo "=============================="
echo "📊 Test Summary"
echo "=============================="
echo "Total test suites: $TOTAL_TESTS"
echo -e "Passed: ${GREEN}$PASSED_TESTS${NC}"
echo -e "Failed: ${RED}$FAILED_TESTS${NC}"

if [ $FAILED_TESTS -eq 0 ]; then
    print_success "All tests passed! 🎉"
    exit 0
else
    print_error "Some tests failed! ❌"
    exit 1
fi
