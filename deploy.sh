#!/bin/bash

# ==============================================================================
#                      APPLICATION DEPLOYMENT SCRIPT
# ==============================================================================
# This script automates the deployment of multiple ReactJS applications and
# a Java WAR file from the /tmp directory to their specified destinations.
# It includes features for backup, backup rotation, and user interaction.
# ==============================================================================

# --- Configuration ---

# File Ownership Settings (user:group)
# For React projects, 'www-data' is common for Nginx/Apache on Ubuntu
REACT_OWNER="www-data:www-data"
# For Tomcat WAR files
WAR_OWNER="tomcat:tomcat"

# Base path for all code projects
CODE_BASE_PATH="/var/www/code"

# React Project 1
P1_NAME="Project One"
P1_DEST="${CODE_BASE_PATH}/project-one"

# React Project 2
P2_NAME="Project Two"
P2_DEST="${CODE_BASE_PATH}/project-two"

# React Project 3
P3_NAME="Project Three"
P3_DEST="${CODE_BASE_PATH}/project-three"

# WAR deployment path
WAR_DEST="/opt/tomcat/latest/webapps"

# Common paths
TMP_SRC="/tmp"
# The name of the directory inside the React zip files (e.g., the output of `npm run build`)
REACT_BUILD_DIR_NAME="build"

# Backup configuration
MAX_BACKUPS=3

# --- Colors for Logging ---
COLOR_RESET='\033[0m'
COLOR_RED='\033[0;31m'
COLOR_GREEN='\033[0;32m'
COLOR_BLUE='\033[0;34m'
COLOR_YELLOW='\033[1;33m'

# --- Helper Functions ---

# Prints an informational message
log_info() {
    echo -e "${COLOR_BLUE}[INFO] $1${COLOR_RESET}"
}

# Prints a success message
log_success() {
    echo -e "${COLOR_GREEN}[SUCCESS] $1${COLOR_RESET}"
}

# Prints an error message
log_error() {
    echo -e "${COLOR_RED}[ERROR] $1${COLOR_RESET}"
}

# Prints a warning message
log_warn() {
    echo -e "${COLOR_YELLOW}[WARNING] $1${COLOR_RESET}"
}

# Manages backup rotation, keeping only the most recent N backups
# Usage: manage_backups "/path/to/backups/basename_*.zip"
manage_backups() {
    local backup_pattern=$1
    local files_to_delete=$(ls -1t ${backup_pattern} 2>/dev/null | tail -n +$((MAX_BACKUPS + 1)))
    if [[ -n "$files_to_delete" ]]; then
        log_info "Cleaning up old backups..."
        echo "$files_to_delete" | xargs -r rm
        log_success "Old backups removed."
    fi
}

# Pauses execution and waits for user to press Enter
press_enter_to_continue() {
    read -p "Press [Enter] to return to the menu..."
}

# --- Core Deployment Functions ---

##
# Deploys a ReactJS project
# Now asks for the zip file name instead of taking it as an argument.
#
# Globals: TMP_SRC, REACT_BUILD_DIR_NAME, MAX_BACKUPS
# Arguments:
#   $1: Project Display Name (e.g., "Project One")
#   $2: Destination path (e.g., "/home/ubuntu/code/project-one")
##
deploy_react_project() {
    local project_name=$1
    local dest_path=$2
    local temp_extract_path="${TMP_SRC}/${REACT_BUILD_DIR_NAME}"

    log_info "Starting deployment for ${project_name}..."

    # 1. Ask for the zip file name
    read -p "Enter the name of the zip file for '${project_name}': " zip_name
    
    if [[ -z "$zip_name" ]]; then
        log_error "Zip file name cannot be empty. Aborting."
        return 1
    fi

    local source_zip="${TMP_SRC}/${zip_name}"

    # 2. Validation
    if [[ ! -f "$source_zip" ]]; then
        log_error "Source file not found: ${source_zip}"
        return 1
    fi
    if [[ ! -d "$dest_path" ]] && [[ ! -w "$(dirname "$dest_path")" ]]; then
        log_error "Permission denied to create directory: ${dest_path}"
        return 1
    fi
    if [[ -d "$dest_path" ]] && [[ ! -w "$dest_path" ]]; then
        log_error "Permission denied to write to destination: ${dest_path}"
        return 1
    fi

    mkdir -p "$dest_path"

    # 3. Backup existing content
    local backup_base_path="${dest_path}"
    local backup_pattern="${backup_base_path}_*.zip"
    manage_backups "$backup_pattern"

    if [[ -n "$(ls -A "$dest_path")" ]]; then
        local timestamp=$(date +%Y%m%d_%H%M%S)
        local backup_file="${backup_base_path}_${timestamp}.zip"
        log_info "Backing up existing content of ${dest_path} to ${backup_file}"
        (cd "$dest_path" && zip -qr "$backup_file" ./*)
        if [[ $? -ne 0 ]]; then
            log_error "Backup failed. Aborting deployment."
            return 1
        fi
        log_success "Backup created successfully."
    else
        log_info "Destination directory is empty. No backup needed."
    fi

    # 4. Deploy new content
    log_info "Cleaning destination directory: ${dest_path}"
    rm -rf "${dest_path:?}"/*

    log_info "Extracting ${source_zip}..."
    rm -rf "$temp_extract_path"
    unzip -q "$source_zip" -d "$TMP_SRC"
    exit_code=$?
    if [[ $exit_code -gt 1 || ! -d "$temp_extract_path" ]]; then
        log_error "Failed to extract or extracted directory '${REACT_BUILD_DIR_NAME}' not found in zip."
        return 1
    fi

    log_info "Moving new files to destination..."
    mv "$temp_extract_path"/* "$dest_path/"
    if [[ $? -ne 0 ]]; then
        log_error "Failed to move files to destination. Check permissions."
        return 1
    fi

    log_info "Setting ownership for ${project_name} to ${REACT_OWNER}..."
    chown -R "$REACT_OWNER" "$dest_path"
    if [[ $? -ne 0 ]]; then
        log_warn "Failed to set ownership. Does user '${REACT_OWNER%%:*}' exist?"
        # This is a warning, not a fatal error, so we don't return 1
    fi

    # 5. Cleanup
    log_info "Cleaning up temporary files..."
    rm -rf "$temp_extract_path"

    log_success "${project_name} deployed successfully! ✨"
    return 0
}

##
# Deploys a .war file to Tomcat
# Globals: TMP_SRC, WAR_DEST, MAX_BACKUPS
##
deploy_war_file() {
    log_info "Starting WAR file deployment..."
    read -p "Enter the name of the .war file (e.g., myapp.war): " war_filename

    if [[ -z "$war_filename" ]]; then
        log_error "WAR file name cannot be empty."
        return 1
    fi

    local source_war="${TMP_SRC}/${war_filename}"
    local dest_war="${WAR_DEST}/${war_filename}"

    if [[ ! -f "$source_war" ]]; then
        log_error "Source file not found: ${source_war}"
        return 1
    fi
    if [[ ! -w "$WAR_DEST" ]]; then
        log_error "Write permission denied for Tomcat webapps directory: ${WAR_DEST}"
        log_warn "You may need to run this script with 'sudo' or adjust directory permissions."
        return 1
    fi

    if [[ -f "$dest_war" ]]; then
        local backup_pattern="${dest_war}.*.zip"
        manage_backups "$backup_pattern"

        local timestamp=$(date +%Y%m%d_%H%M%S)
        local backup_file="${dest_war}.${timestamp}.zip"

        log_info "Backing up existing ${war_filename} to ${backup_file}"
        zip -qj "$backup_file" "$dest_war"
        if [[ $? -ne 0 ]]; then
            log_error "Backup failed. Aborting deployment."
            return 1
        fi
        log_success "Backup created successfully."
    fi

    log_info "Copying ${war_filename} to ${WAR_DEST}..."
    cp "$source_war" "$WAR_DEST/"
    if [[ $? -ne 0 ]]; then
        log_error "Failed to copy WAR file. Check permissions."
        return 1
    fi

    log_info "Setting ownership of ${war_filename} to ${WAR_OWNER}..."
    chown "$WAR_OWNER" "$dest_war"
    if [[ $? -ne 0 ]]; then
        log_warn "Failed to set ownership. Does user '${WAR_OWNER%%:*}' exist?"
    fi

    log_success "${war_filename} deployed successfully! 🚀 Tomcat will unpack it shortly."
    return 0
}

# --- Main Menu and Execution ---

# Displays the main menu and handles user input
main_menu() {
    clear
    echo "========================================="
    echo "      APPLICATION DEPLOYMENT MENU        "
    echo "========================================="
    echo "Which application do you want to deploy?"
    echo "  1. ${P1_NAME}"
    echo "  2. ${P2_NAME}"
    echo "  3. ${P3_NAME}"
    echo "  4. A .war file"
    echo "  5. Exit"
    echo "-----------------------------------------"
    read -p "Enter your choice [1-5]: " choice
    echo ""

    case $choice in
        1)
            deploy_react_project "$P1_NAME" "$P1_DEST"
            press_enter_to_continue
            ;;
        2)
            deploy_react_project "$P2_NAME" "$P2_DEST"
            press_enter_to_continue
            ;;
        3)
            deploy_react_project "$P3_NAME" "$P3_DEST"
            press_enter_to_continue
            ;;
        4)
            deploy_war_file
            press_enter_to_continue
            ;;
        5)
            log_info "Exiting script. Goodbye!"
            exit 0
            ;;
        *)
            log_error "Invalid choice. Please select an option from 1 to 5."
            press_enter_to_continue
            ;;
    esac
}

# --- Script Entry Point ---

# Check for required commands
for cmd in zip unzip; do
    if ! command -v $cmd &> /dev/null; then
        log_error "Required command '${cmd}' is not installed. Please install it and try again."
        exit 1
    fi
done

# Main loop
while true; do
    main_menu
done
