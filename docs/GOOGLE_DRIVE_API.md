# Google Drive API Configuration

## Overview

This directory contains configuration files for Google Drive API integration. This is an **alternative method** to rclone for Google Drive backup.

## When to Use Google Drive API vs rclone

| Method | Use Case | Setup Difficulty | Maintenance |
|--------|----------|------------------|-------------|
| **rclone** | Production use, large data transfers | ⭐⭐ Easy | ⭐⭐ Low |
| **Google Drive API** | Development, testing, custom functionality | ⭐⭐⭐ Complex | ⭐⭐⭐ High |

**Recommendation**: Use rclone for production. Use Google Drive API only for development/testing or when you need custom functionality.

## Setup Instructions

### 1. Create Project in Google Cloud Console
1. Access [Google Cloud Console](https://console.cloud.google.com/)
2. Create a new project
3. Enable Google Drive API

### 2. Create Credentials
1. "Credentials" → "Create Credentials" → "OAuth Client ID"
2. Application Type: "Desktop Application"
3. Download credentials and save as `credentials.json`

### 3. File Placement
```
configs/google_drive/
├── credentials.json  # Downloaded from Google Cloud Console
├── token.json        # Auto-generated (after initial authentication)
└── README.md         # This file
```

### 4. Initial Authentication
When running the Docker container, a browser will open for initial authentication:
1. Login with Google account
2. Grant application access permission
3. `token.json` will be auto-generated

## Important Notes
- Do not commit `credentials.json` to Git as it contains sensitive information
- Do not commit `token.json` to Git as it is auto-generated
- Authentication credentials need regular updates