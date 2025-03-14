#!/bin/bash

# Created by: Micah Coyle - Jamf Technical Support Specialist 
# Created on: 02/011/2025
# Version 1.0

# This script will check the endpoint locally to determine if the MDM profile communication is broken. Can be ran locally or as an Extension Attribute

# Reccomendations: This script is provided as a starting point only and MUST be thoroughly tested before use. Never run untested scripts in production environments.

# DISCLAIMER: Jamf makes no representations or warranties, either express or implied, regarding the functionality, accuracy, or suitability of this script for any particular purpose. Jamf disclaims any responsibility for any issues, damages, or losses that may arise from its use.


result=$(log show --style compact --predicate '(process CONTAINS "mdmclient")' --last 1d | grep "Unable to create MDM identity")
if [[ $result == '' ]]
then
	echo "MDM is communicating"
else
	echo "MDM is broken"
	
fi