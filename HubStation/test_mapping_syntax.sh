#!/bin/bash
# HubStation File Mapping and Syntax Check Script

echo -e "\033[36mScanning HubStation directory: $(pwd)\033[0m"

# List all files and folders
echo -e "\n\033[33mAll files and folders:\033[0m"
find . -type f -o -type d | sort

# Check for key files
echo -e "\n\033[33mChecking for required files/components:\033[0m"
keyFiles=(
    "index.html"
    "GeminiService.ps1"
    "OllamaRunner"
    "Reflections.psm1"
    "HubStation.ps1"
    "hub_config.json"
    "shared_bus"
    "START.bat"
    "Start-HubStation.ps1"
)

for file in "${keyFiles[@]}"; do
    if find . -iname "$file" | grep -q .; then
        echo -e "\033[32m✓ Found: $file\033[0m"
    else
        echo -e "\033[31m✗ Missing: $file\033[0m"
    fi
done

# Check JSON files for validity
echo -e "\n\033[33mValidating JSON files:\033[0m"
for jsonfile in $(find . -name "*.json"); do
    echo -n "Checking: $jsonfile ... "
    if python3 -m json.tool "$jsonfile" > /dev/null 2>&1; then
        echo -e "\033[32m✓ Valid JSON\033[0m"
    else
        echo -e "\033[31m✗ Invalid JSON\033[0m"
    fi
done

# Check PowerShell files exist
echo -e "\n\033[33mPowerShell script inventory:\033[0m"
for ps1file in $(find . -name "*.ps1" -o -name "*.psm1"); do
    echo -e "\033[37m  $ps1file\033[0m"
    linecount=$(wc -l < "$ps1file")
    echo -e "    Lines: $linecount"
done

echo -e "\n\033[36mMapping and syntax check complete.\033[0m"
