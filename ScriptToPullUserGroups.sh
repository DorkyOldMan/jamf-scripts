#!/bin/bash


##############################################################################
# Jamf Pro Extension Attribute: Entra ID Group Membership
# 
# This script retrieves the current user's Entra ID group memberships
# via Microsoft Graph API and returns them for inventory collection.
#
# REQUIREMENTS:
# - App registration in Entra ID with proper permissions
# - Client credentials stored securely on the device
#
#
# Modified by Micah Coyle on 10/7/2025

# Security Reccomendations: This script is provided as a starting point only and MUST be thoroughly tested before use. Never run untested scripts in production environments.

# DISCLAIMER: Jamf makes no representations or warranties, either express or implied, regarding the functionality, accuracy, or suitability of this script for any particular purpose. Jamf disclaims any responsibility for any issues, damages, or losses that may arise from its use.


##############################################################################

# Configuration - REPLACE THESE VALUES
TENANT_ID="your-tenant-id-here"
CLIENT_ID="your-client-id-here"
CLIENT_SECRET="your-client-secret-here"

# Get the current console user
currentUser=$(stat -f%Su /dev/console)

# Skip if no user is logged in or if it's a system account
if [[ "$currentUser" == "root" ]] || [[ "$currentUser" == "_mbsetupuser" ]] || [[ -z "$currentUser" ]]; then
	echo "<result>No user logged in</result>"
	exit 0
fi

# Function to get access token
get_access_token() {
	local token_response
	token_response=$(curl -s -X POST "https://login.microsoftonline.com/$TENANT_ID/oauth2/v2.0/token" \
		-H "Content-Type: application/x-www-form-urlencoded" \
		-d "client_id=$CLIENT_ID" \
		-d "client_secret=$CLIENT_SECRET" \
		-d "scope=https://graph.microsoft.com/.default" \
		-d "grant_type=client_credentials")
	
	# Extract access token using basic text processing
	echo "$token_response" | grep -o '"access_token":"[^"]*' | cut -d'"' -f4
}

# Function to get user's UPN (User Principal Name)
get_user_upn() {
	local username="$1"
	# Try to get UPN from system - this might need adjustment based on your environment
	# Option 1: Try dscl to get the user's email/UPN
	local upn
	upn=$(dscl . -read "/Users/$username" | grep -i "EMailAddress:" | cut -d' ' -f2)
	
	# Option 2: If that doesn't work, try alternative methods
	if [[ -z "$upn" ]]; then
		# Construct UPN assuming username@domain format
		upn="${username}@yourdomain.com"  # REPLACE with your actual domain
	fi
	
	echo "$upn"
}

# Function to get user's group memberships
get_user_groups() {
	local access_token="$1"
	local user_upn="$2"
	
	# Query Microsoft Graph API for user's group memberships
	local groups_response
	groups_response=$(curl -s -X GET "https://graph.microsoft.com/v1.0/users/$user_upn/memberOf" \
		-H "Authorization: Bearer $access_token" \
		-H "Content-Type: application/json")
	
	# Extract group display names
	echo "$groups_response" | grep -o '"displayName":"[^"]*' | cut -d'"' -f4 | sort
}

# Main execution
main() {
	# Get access token
	access_token=$(get_access_token)
	
	if [[ -z "$access_token" ]] || [[ "$access_token" == "null" ]]; then
		echo "<result>Authentication failed</result>"
		exit 1
	fi
	
	# Get user's UPN
	user_upn=$(get_user_upn "$currentUser")
	
	if [[ -z "$user_upn" ]]; then
		echo "<result>Could not determine user UPN</result>"
		exit 1
	fi
	
	# Get user's groups
	groups=$(get_user_groups "$access_token" "$user_upn")
	
	if [[ -z "$groups" ]]; then
		echo "<result>No groups found or API error</result>"
	else
		# Format groups as a delimited list (using | as delimiter for Jamf Pro)
		formatted_groups=$(echo "$groups" | tr '\n' '|' | sed 's/|$//')
		echo "<result>$formatted_groups</result>"
	fi
}

# Run the main function
main