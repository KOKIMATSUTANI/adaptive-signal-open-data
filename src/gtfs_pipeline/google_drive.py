"""
Google Drive Integration Module

Provides functionality for automatically uploading GTFS data to Google Drive
"""

import os
import logging
from pathlib import Path
from typing import Optional, List
from datetime import datetime, timezone, timedelta

from google.auth.transport.requests import Request
from google.oauth2.credentials import Credentials
from google_auth_oauthlib.flow import InstalledAppFlow
from googleapiclient.discovery import build
from googleapiclient.http import MediaFileUpload
from pydrive2.auth import GoogleAuth
from pydrive2.drive import GoogleDrive

from .config import GTFSConfig


class GoogleDriveManager:
    """
    Google Drive integration management class
    """
    
    # Google Drive API scopes
    SCOPES = ['https://www.googleapis.com/auth/drive.file']
    
    def __init__(self, config: GTFSConfig):
        """
        Initialize Google Drive Manager
        
        Args:
            config: GTFS configuration object
        """
        self.config = config
        self.logger = logging.getLogger(__name__)
        self.drive_service = None
        self.gauth = None
        self.drive = None
        
    def authenticate(self) -> bool:
        """
        Execute Google Drive authentication
        
        Returns:
            True if authentication successful, False otherwise
        """
        try:
            # Credentials file paths
            creds_file = os.path.join(self.config.data_directory, 'credentials.json')
            token_file = os.path.join(self.config.data_directory, 'token.json')
            
            if not os.path.exists(creds_file):
                self.logger.error(f"Credentials file not found: {creds_file}")
                self.logger.info("Please download credentials.json from Google Cloud Console")
                return False
            
            # Authentication flow
            creds = None
            if os.path.exists(token_file):
                creds = Credentials.from_authorized_user_file(token_file, self.SCOPES)
            
            if not creds or not creds.valid:
                if creds and creds.expired and creds.refresh_token:
                    creds.refresh(Request())
                else:
                    flow = InstalledAppFlow.from_client_secrets_file(creds_file, self.SCOPES)
                    creds = flow.run_local_server(port=0)
                
                # Save token
                with open(token_file, 'w') as token:
                    token.write(creds.to_json())
            
            # Build Drive API service
            self.drive_service = build('drive', 'v3', credentials=creds)
            
            # PyDrive2 authentication
            self.gauth = GoogleAuth()
            self.gauth.credentials = creds
            self.drive = GoogleDrive(self.gauth)
            
            self.logger.info("Google Drive authentication successful")
            return True
            
        except Exception as e:
            self.logger.error(f"Google Drive authentication failed: {e}")
            return False
    
    def create_folder(self, folder_name: str, parent_folder_id: Optional[str] = None) -> Optional[str]:
        """
        Create folder in Google Drive
        
        Args:
            folder_name: Folder name
            parent_folder_id: Parent folder ID (None for root)
            
        Returns:
            Created folder ID, None if failed
        """
        try:
            folder_metadata = {
                'name': folder_name,
                'mimeType': 'application/vnd.google-apps.folder'
            }
            
            if parent_folder_id:
                folder_metadata['parents'] = [parent_folder_id]
            
            folder = self.drive_service.files().create(
                body=folder_metadata,
                fields='id'
            ).execute()
            
            folder_id = folder.get('id')
            self.logger.info(f"Created folder '{folder_name}' with ID: {folder_id}")
            return folder_id
            
        except Exception as e:
            self.logger.error(f"Failed to create folder '{folder_name}': {e}")
            return None
    
    def find_folder(self, folder_name: str, parent_folder_id: Optional[str] = None) -> Optional[str]:
        """
        Search for folder in Google Drive
        
        Args:
            folder_name: Folder name
            parent_folder_id: Parent folder ID
            
        Returns:
            Folder ID, None if not found
        """
        try:
            query = f"name='{folder_name}' and mimeType='application/vnd.google-apps.folder' and trashed=false"
            
            if parent_folder_id:
                query += f" and '{parent_folder_id}' in parents"
            
            results = self.drive_service.files().list(
                q=query,
                fields="files(id, name)"
            ).execute()
            
            folders = results.get('files', [])
            if folders:
                folder_id = folders[0]['id']
                self.logger.info(f"Found folder '{folder_name}' with ID: {folder_id}")
                return folder_id
            
            return None
            
        except Exception as e:
            self.logger.error(f"Failed to find folder '{folder_name}': {e}")
            return None
    
    def upload_file(self, file_path: str, folder_id: Optional[str] = None, 
                   file_name: Optional[str] = None) -> bool:
        """
        Upload file to Google Drive
        
        Args:
            file_path: Path to file to upload
            folder_id: Destination folder ID
            file_name: File name for upload (None for original filename)
            
        Returns:
            True if successful, False otherwise
        """
        try:
            if not os.path.exists(file_path):
                self.logger.error(f"File not found: {file_path}")
                return False
            
            if file_name is None:
                file_name = os.path.basename(file_path)
            
            # File metadata
            file_metadata = {'name': file_name}
            if folder_id:
                file_metadata['parents'] = [folder_id]
            
            # Media file
            media = MediaFileUpload(file_path, resumable=True)
            
            # Execute upload
            file = self.drive_service.files().create(
                body=file_metadata,
                media_body=media,
                fields='id'
            ).execute()
            
            file_id = file.get('id')
            self.logger.info(f"Uploaded file '{file_name}' with ID: {file_id}")
            return True
            
        except Exception as e:
            self.logger.error(f"Failed to upload file '{file_path}': {e}")
            return False
    
    def upload_gtfs_data(self, data_directory: str) -> bool:
        """
        Upload GTFS data to Google Drive
        
        Args:
            data_directory: Directory where GTFS data is stored
            
        Returns:
            True if successful, False otherwise
        """
        try:
            # Check authentication
            if not self.drive_service:
                if not self.authenticate():
                    return False
            
            # Create date folder (JST - container timezone is set to Asia/Tokyo)
            today = datetime.now().strftime("%Y-%m-%d")
            date_folder_id = self.find_folder(today)
            if not date_folder_id:
                date_folder_id = self.create_folder(today)
                if not date_folder_id:
                    return False
            
            # Create GTFS data folder
            gtfs_folder_id = self.find_folder("GTFS_Data", date_folder_id)
            if not gtfs_folder_id:
                gtfs_folder_id = self.create_folder("GTFS_Data", date_folder_id)
                if not gtfs_folder_id:
                    return False
            
            # Upload files in data directory
            data_path = Path(data_directory)
            uploaded_count = 0
            
            for file_path in data_path.rglob("*"):
                if file_path.is_file():
                    # Maintain folder structure with relative paths
                    relative_path = file_path.relative_to(data_path)
                    folder_structure = relative_path.parent
                    
                    # Create subfolders
                    current_folder_id = gtfs_folder_id
                    if folder_structure != Path('.'):
                        for folder_name in folder_structure.parts:
                            sub_folder_id = self.find_folder(folder_name, current_folder_id)
                            if not sub_folder_id:
                                sub_folder_id = self.create_folder(folder_name, current_folder_id)
                            current_folder_id = sub_folder_id
                    
                    # Upload file
                    if self.upload_file(str(file_path), current_folder_id):
                        uploaded_count += 1
            
            self.logger.info(f"Successfully uploaded {uploaded_count} files to Google Drive")
            return uploaded_count > 0
            
        except Exception as e:
            self.logger.error(f"Failed to upload GTFS data: {e}")
            return False
