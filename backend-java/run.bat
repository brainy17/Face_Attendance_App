@echo off
REM Face Attendance Backend - Java Setup Script (Windows)
REM This script builds and runs the Java backend

echo.
echo 🚀 Face Attendance Backend - Java Spring Boot
echo ===============================================
echo.

REM Check Java installation
echo 1️⃣ Checking Java installation...
java -version >nul 2>&1
if errorlevel 1 (
    echo ❌ Java not found! Please install Java 11 or higher
    pause
    exit /b 1
)
for /f tokens^=2 %%i in ('java -version 2^>^&1 ^| find "version"') do set JAVA_VERSION=%%i
echo ✅ Java found: %JAVA_VERSION%

REM Check Maven installation
echo.
echo 2️⃣ Checking Maven installation...
mvn -version >nul 2>&1
if errorlevel 1 (
    echo ❌ Maven not found! Please install Maven 3.6 or higher
    echo.
    echo Download Maven from: https://maven.apache.org/download.cgi
    pause
    exit /b 1
)
echo ✅ Maven found

REM Navigate to backend-java
echo.
echo 3️⃣ Navigating to backend-java directory...
cd backend-java
if errorlevel 1 (
    echo ❌ Could not find backend-java directory
    pause
    exit /b 1
)
echo ✅ Current directory: %cd%

REM Build the project
echo.
echo 4️⃣ Building the project...
echo    This may take 2-3 minutes on first run...
call mvn clean package -DskipTests
if errorlevel 1 (
    echo ❌ Build failed!
    pause
    exit /b 1
)
echo ✅ Build completed successfully!

REM Run the application
echo.
echo 5️⃣ Starting the server...
echo    Backend will start on http://localhost:8001
echo.
java -jar target/face-attendance-backend-2.0.0.jar
pause
