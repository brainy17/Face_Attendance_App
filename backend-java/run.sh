#!/bin/bash
# Face Attendance Backend - Java Setup Script
# This script builds and runs the Java backend

set -e

echo "🚀 Face Attendance Backend - Java Spring Boot"
echo "=============================================="
echo ""

# Check Java installation
echo "1️⃣ Checking Java installation..."
if ! command -v java &> /dev/null; then
    echo "❌ Java not found! Please install Java 11 or higher"
    exit 1
fi
echo "✅ Java found: $(java -version 2>&1 | head -1)"

# Check Maven installation
echo ""
echo "2️⃣ Checking Maven installation..."
if ! command -v mvn &> /dev/null; then
    echo "❌ Maven not found! Please install Maven 3.6 or higher"
    exit 1
fi
echo "✅ Maven found: $(mvn -version | head -1)"

# Navigate to backend-java
echo ""
echo "3️⃣ Navigating to backend-java directory..."
cd "$(dirname "$0")/backend-java" || exit 1
echo "✅ Current directory: $(pwd)"

# Build the project
echo ""
echo "4️⃣ Building the project..."
echo "   This may take 2-3 minutes on first run..."
mvn clean package -DskipTests
echo "✅ Build completed successfully!"

# Run the application
echo ""
echo "5️⃣ Starting the server..."
echo "   Backend will start on http://localhost:8001"
echo ""
java -jar target/face-attendance-backend-2.0.0.jar
