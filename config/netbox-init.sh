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

echo "NetBox initialization completed."