#!/bin/bash


# Created by: Micah Coyle - Jamf Technical Support Specialist 
# Created on: 03/06/2025
# Version 1.0
# This script will locate any packages within the JCDS and download them using the package URL

# Security Reccomendations: This script is provided as a starting point only and MUST be thoroughly tested before use. Never run untested scripts in production environments.

# DISCLAIMER: Jamf makes no representations or warranties, either express or implied, regarding the functionality, accuracy, or suitability of this script for any particular purpose. Jamf disclaims any responsibility for any issues, damages, or losses that may arise from its use.

	
	# Configuration
	JAMF_URL="https://your.jamf.server"  # Replace with your Jamf Pro URL
	CLIENT_ID="your_client_id"           # Replace with your API Client ID
	CLIENT_SECRET="your_client_secret"   # Replace with your API Client Secret
	DOWNLOAD_DIR="package_downloads"
	
	# Create download directory if it doesn't exist
	mkdir -p "$DOWNLOAD_DIR"
	
	# Color codes for output
	RED='\033[0;31m'
	GREEN='\033[0;32m'
	YELLOW='\033[1;33m'
	NC='\033[0m' # No Color
	
	# Counter for tracking downloads
	successful=0
	failed=0
	
	# Function to print messages with timestamp
	log_message() {
		echo -e "[$(date '+%Y-%m-%d %H:%M:%S')] $1"
	}
	
	# Function to get bearer token using OAuth
	get_bearer_token() {
		local token_response
		
		# Base64 encode the client credentials
		local auth_string=$(echo -n "${CLIENT_ID}:${CLIENT_SECRET}" | base64)
		
		token_response=$(curl -s \
		-H "Authorization: Basic ${auth_string}" \
		-X POST "${JAMF_URL}/api/oauth/token" \
		-d "grant_type=client_credentials" \
		-H "Accept: application/json")
		
		# Extract access token using grep and cut
		echo "$token_response" | grep -o '"access_token":"[^"]*' | cut -d'"' -f4
	}
	
	# Function to get list of packages
	get_packages() {
		local bearer_token="$1"
		curl -s \
		-H "Authorization: Bearer ${bearer_token}" \
		-H "accept: application/json" \
		"${JAMF_URL}/JSSResource/packages"
	}
	
	# Function to get JCDS download URL
	get_download_url() {
		local bearer_token="$1"
		local filename="$2"
		local url_response
		
		# URL encode the filename
		encoded_filename=$(echo "$filename" | perl -MURI::Escape -ne 'chomp;print uri_escape($_)')
		
		url_response=$(curl -s \
		-H "Authorization: Bearer ${bearer_token}" \
		-H "accept: application/json" \
		"${JAMF_URL}/api/v1/jcds/files/${encoded_filename}")
		
		# Extract URI using grep and cut
		echo "$url_response" | grep -o '"uri":"[^"]*' | cut -d'"' -f4
	}
	
	# Function to check token validity
	check_token_validity() {
		local bearer_token="$1"
		
		# Make a test API call to verify token
		local test_response=$(curl -s -o /dev/null -w "%{http_code}" \
		-H "Authorization: Bearer ${bearer_token}" \
		"${JAMF_URL}/api/v1/auth")
		
		[ "$test_response" = "200" ]
	}
	
	# Function to download package
	download_package() {
		local url="$1"
		local filename="$2"
		local output_path="${DOWNLOAD_DIR}/${filename}"
		
		# Skip if file already exists
		if [ -f "$output_path" ]; then
			log_message "${YELLOW}Skipping ${filename} - already exists${NC}"
			return 0
			}
			
			log_message "${GREEN}Downloading ${filename}${NC}"
			
			# Download with progress bar using curl
			if curl -# -L -o "$output_path" "$url"; then
				log_message "${GREEN}Successfully downloaded ${filename}${NC}"
				return 0
			else
				log_message "${RED}Failed to download ${filename}${NC}"
				# Clean up failed download
				rm -f "$output_path"
				return 1
			fi
			}
			
			# Function to refresh token if needed
			refresh_token_if_needed() {
				local current_token="$1"
				
				if ! check_token_validity "$current_token"; then
					log_message "${YELLOW}Token expired, refreshing...${NC}"
					new_token=$(get_bearer_token)
					if [ -n "$new_token" ]; then
						echo "$new_token"
						return 0
					else
						log_message "${RED}Failed to refresh token${NC}"
						return 1
					fi
				else
					echo "$current_token"
					return 0
				fi
			}
			
			# Main script execution
			main() {
				log_message "Starting package download process..."
				
				# Get initial bearer token
				log_message "Authenticating using OAuth..."
				bearer_token=$(get_bearer_token)
				
				if [ -z "$bearer_token" ]; then
					log_message "${RED}Failed to get authentication token${NC}"
					exit 1
				fi
				
				# Get list of packages
				log_message "Getting package list..."
				packages_json=$(get_packages "$bearer_token")
				
				# Extract filenames using grep and sed
				filenames=$(echo "$packages_json" | grep -o '"filename":"[^"]*' | sed 's/"filename":"//')
				
				if [ -z "$filenames" ]; then
					log_message "${RED}No packages found or error getting package list${NC}"
					exit 1
				fi
				
				# Process each package
				while IFS= read -r filename; do
					if [ -n "$filename" ]; then
						# Refresh token if needed
						bearer_token=$(refresh_token_if_needed "$bearer_token")
						if [ $? -ne 0 ]; then
							log_message "${RED}Authentication failed, exiting${NC}"
							exit 1
						fi
						
						# Get download URL
						download_url=$(get_download_url "$bearer_token" "$filename")
						
						if [ -n "$download_url" ]; then
							if download_package "$download_url" "$filename"; then
								((successful++))
							else
								((failed++))
							fi
						else
							log_message "${RED}Failed to get download URL for ${filename}${NC}"
							((failed++))
						fi
						
						# Small delay to prevent overwhelming the server
						sleep 1
					fi
				done <<< "$filenames"
				
				# Print summary
				log_message "\nDownload Summary:"
				log_message "${GREEN}Successfully downloaded: ${successful}${NC}"
				log_message "${RED}Failed downloads: ${failed}${NC}"
				log_message "Download location: $(cd "$DOWNLOAD_DIR" && pwd)"
			}
			
			# Run main function
			main