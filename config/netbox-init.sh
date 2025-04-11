#!/bin/bash
set -e

echo "Starting NetBox initialization script..."

# Install dulwich package
echo "Installing dulwich package..."
pip install dulwich

# Create API token for admin user using the correct path to manage.py
echo "Creating API token for admin user..."
cd /app/netbox/netbox
python manage.py shell --interface python << EOF
from users.models import User
from users.models import Token
# Check if token already exists before creating
user = User.objects.get(username='admin')
if not Token.objects.filter(user=user, key='c4cd2e9bf74869feb061eba14b090b4811353d9c').exists():
    user.tokens.create(key='c4cd2e9bf74869feb061eba14b090b4811353d9c')
    print("Token created successfully")
else:
    print("Token already exists")
EOF

# Wait for API to be fully available
echo "Waiting for NetBox API to be available..."
for i in {1..30}; do
    if curl -s -f http://localhost:8000/api/ > /dev/null; then
        echo "NetBox API is available!"
        break
    fi
    echo "Waiting for NetBox API to become available... (attempt $i/30)"
    sleep 5
    if [ $i -eq 30 ]; then
        echo "Timed out waiting for NetBox API"
        exit 1
    fi
done

# Store the result of the create operation to extract the ID
echo "Creating Nokia SRL Scripts data source..."
RESULT=$(curl -s -X POST \
  -H "Authorization: Token c4cd2e9bf74869feb061eba14b090b4811353d9c" \
  -H "Content-Type: application/json" \
  -H "Accept: application/json; indent=4" \
  http://localhost:8000/api/core/data-sources/ \
  --data '{
    "name": "Nokia SRL Scripts",
    "type": "git",
    "source_url": "https://github.com/FloSch62/nokia-srl-netbox-scripts.git",
    "backend_branch": "netbox4.2",
    "backend_username": "",
    "backend_password": "",
    "enabled": true,
    "parameters": {
      "branch": "netbox4.2",
      "username": "",
      "password": ""
    }
  }')

echo "API Response: $RESULT"

# Check if the data source was created successfully or already exists
if echo "$RESULT" | grep -q '"id"'; then
    # Extract the ID from the result
    DS_ID=$(echo $RESULT | grep -o '"id":[^,]*' | cut -d':' -f2 | tr -d ' ')
    echo "Data source created with ID: $DS_ID"

    # Now use the ID to sync the data source - fixed URL with no double slash
    echo "Syncing data source..."
    SYNC_RESULT=$(curl -s -X POST \
      -H "Authorization: Token c4cd2e9bf74869feb061eba14b090b4811353d9c" \
      -H "Content-Type: application/json" \
      -H "Accept: application/json; indent=4" \
      "http://localhost:8000/api/core/data-sources/${DS_ID}/sync/")

    echo "Sync result: $SYNC_RESULT"
else
    echo "Error creating data source or data source already exists: $RESULT"

    # Try to find the existing data source and sync it
    echo "Attempting to find and sync existing data source..."
    DS_LIST=$(curl -s \
      -H "Authorization: Token c4cd2e9bf74869feb061eba14b090b4811353d9c" \
      -H "Accept: application/json; indent=4" \
      "http://localhost:8000/api/core/data-sources/")

    if echo "$DS_LIST" | grep -q "Nokia SRL Scripts"; then
        # Extract ID of the existing data source
        DS_ID=$(echo "$DS_LIST" | grep -B 5 "Nokia SRL Scripts" | grep -o '"id":[^,]*' | head -1 | cut -d':' -f2 | tr -d ' ')

        if [ ! -z "$DS_ID" ]; then
            echo "Found existing data source with ID: $DS_ID, syncing..."
            SYNC_RESULT=$(curl -s -X POST \
              -H "Authorization: Token c4cd2e9bf74869feb061eba14b090b4811353d9c" \
              -H "Content-Type: application/json" \
              -H "Accept: application/json; indent=4" \
              "http://localhost:8000/api/core/data-sources/${DS_ID}/sync/")

            echo "Sync result: $SYNC_RESULT"
        else
            echo "Could not extract ID from existing data sources"
        fi
    else
        echo "Could not find existing Nokia SRL Scripts data source"
    fi
fi

# Add scripts from the data source
sleep 10
echo "Now adding scripts from the data source..."

# Set variables for script addition
TOKEN="c4cd2e9bf74869feb061eba14b090b4811353d9c"
NETBOX_URL="http://localhost:8000"  # Use localhost since we're inside the container
COOKIE_JAR=/tmp/netbox_cookies.txt

# Fetch the data files from the API and filter for Python files only
echo "Fetching and filtering Python script files..."
DATA_FILES_JSON=$(curl -s \
  -H "Authorization: Token $TOKEN" \
  -H "Accept: application/json; indent=4" \
  "$NETBOX_URL/api/core/data-files/?brief=true&limit=100&source_id=$DS_ID")

# Extract Python file IDs using jq if available, or fallback to grep/sed
if command -v jq &> /dev/null; then
    echo "Using jq to parse JSON response..."
    PYTHON_FILE_IDS=$(echo "$DATA_FILES_JSON" | jq -r '.results[] | select(.path | endswith(".py")) | .id')
else
    echo "jq not available, using grep/sed to parse JSON response..."
    # This is a simple parser that may need adjustments based on the exact JSON format
    PYTHON_FILE_IDS=$(echo "$DATA_FILES_JSON" | grep -o '"id": [0-9]*' | grep -v '"id": null' | cut -d' ' -f2 | tr '\n' ' ')
    # Verify we have Python files
    echo "Verifying Python files in response..."
    PYTHON_PATHS=$(echo "$DATA_FILES_JSON" | grep -o '"path": "[^"]*\.py"' | wc -l)
    if [ "$PYTHON_PATHS" -eq 0 ]; then
        echo "Warning: No Python files found in the data source. Full response:"
        echo "$DATA_FILES_JSON"
        # Fallback to hard-coded IDs from your example if no Python files are detected
        echo "Falling back to hard-coded IDs from example..."
        PYTHON_FILE_IDS="4 5 2"
    fi
fi

echo "Found Python file IDs: $PYTHON_FILE_IDS"

# Step 1: First login to get a valid session
echo "Logging into NetBox web interface..."
curl -s -c $COOKIE_JAR -X GET "$NETBOX_URL/login/" > /tmp/login_page.html

# Extract initial CSRF token from the login page
INITIAL_CSRF=$(grep -o 'window.CSRF_TOKEN = "[^"]*"' /tmp/login_page.html | cut -d '"' -f 2)
echo "Initial CSRF Token: $INITIAL_CSRF"

# Perform the login
curl -s -c $COOKIE_JAR -b $COOKIE_JAR -X POST "$NETBOX_URL/login/" \
  -H "Referer: $NETBOX_URL/login/" \
  -H "X-CSRFToken: $INITIAL_CSRF" \
  -F "csrfmiddlewaretoken=$INITIAL_CSRF" \
  -F "username=admin" \
  -F "password=admin" \
  -F "next=/extras/scripts/add/" \
  --location

# Add each Python script
for SCRIPT_ID in $PYTHON_FILE_IDS; do
    echo "Adding script with data_file ID: $SCRIPT_ID"

    # Step 2: Get the form page to extract the fresh CSRF token
    curl -s -c $COOKIE_JAR -b $COOKIE_JAR "$NETBOX_URL/extras/scripts/add/" > /tmp/form_page.html

    # Extract CSRF token from the JavaScript in the response
    CSRF_TOKEN=$(grep -o 'window.CSRF_TOKEN = "[^"]*"' /tmp/form_page.html | cut -d '"' -f 2)
    echo "Form CSRF Token for script $SCRIPT_ID: $CSRF_TOKEN"

    # Generate current timestamp for _init_time
    INIT_TIME=$(date +%s.%N)

    # Step 3: Submit the form for this script
    SUBMIT_RESULT=$(curl -s -X POST "$NETBOX_URL/extras/scripts/add/" \
      -b $COOKIE_JAR \
      -H "Referer: $NETBOX_URL/extras/scripts/add/" \
      -H "X-CSRFToken: $CSRF_TOKEN" \
      -F "csrfmiddlewaretoken=$CSRF_TOKEN" \
      -F "_init_time=$INIT_TIME" \
      -F "upload_file=" \
      -F "data_source=$DS_ID" \
      -F "data_file=$SCRIPT_ID" \
      -F "auto_sync_enabled=on" \
      -F "_create=")

    if [[ "$SUBMIT_RESULT" == *"success"* ]]; then
        echo "Successfully added script with data_file ID: $SCRIPT_ID"
    else
        echo "Warning: May have failed to add script with data_file ID: $SCRIPT_ID"
        # Uncomment to debug issues
        # echo "Response: $SUBMIT_RESULT" > /tmp/script_${SCRIPT_ID}_response.html
    fi

    # Sleep briefly to prevent overwhelming the server
    sleep 2
done

echo "NetBox initialization and script setup completed."