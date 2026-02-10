#!/bin/bash

# Script to test deployment and monitor version distribution
# Usage: ./test-deployment.sh <service-url> <num-requests>

SERVICE_URL=${1:-"http://localhost"}
NUM_REQUESTS=${2:-100}

echo "========================================="
echo "Testing Deployment"
echo "========================================="
echo "Service URL: $SERVICE_URL"
echo "Number of requests: $NUM_REQUESTS"
echo "========================================="

# Initialize counters
declare -A version_count
declare -A color_count
total=0
errors=0

echo ""
echo "Sending $NUM_REQUESTS requests..."
echo ""

for i in $(seq 1 $NUM_REQUESTS); do
    # Make request and capture response
    response=$(curl -s $SERVICE_URL 2>/dev/null)
    
    if [ $? -eq 0 ]; then
        # Extract version and color
        version=$(echo $response | grep -o '"version":"[^"]*"' | cut -d'"' -f4)
        color=$(echo $response | grep -o '"color":"[^"]*"' | cut -d'"' -f4)
        
        # Count versions
        if [ ! -z "$version" ]; then
            version_count[$version]=$((${version_count[$version]:-0} + 1))
            total=$((total + 1))
        fi
        
        # Count colors
        if [ ! -z "$color" ]; then
            color_count[$color]=$((${color_count[$color]:-0} + 1))
        fi
        
        # Progress indicator
        if [ $((i % 10)) -eq 0 ]; then
            echo -n "."
        fi
    else
        errors=$((errors + 1))
    fi
    
    # Small delay
    sleep 0.1
done

echo ""
echo ""
echo "========================================="
echo "Results"
echo "========================================="
echo "Total requests: $total"
echo "Errors: $errors"
echo ""

echo "Version Distribution:"
for version in "${!version_count[@]}"; do
    count=${version_count[$version]}
    percentage=$(awk "BEGIN {printf \"%.2f\", ($count/$total)*100}")
    echo "  $version: $count requests ($percentage%)"
done

echo ""
echo "Color Distribution:"
for color in "${!color_count[@]}"; do
    count=${color_count[$color]}
    percentage=$(awk "BEGIN {printf \"%.2f\", ($count/$total)*100}")
    echo "  $color: $count requests ($percentage%)"
done

echo ""
echo "========================================="

# Summary
if [ ${#version_count[@]} -gt 1 ]; then
    echo "✅ Multiple versions detected - Canary or Rolling Update in progress"
elif [ ${#version_count[@]} -eq 1 ]; then
    echo "✅ Single version detected - Stable deployment"
else
    echo "❌ No version information received"
fi
echo "========================================="
