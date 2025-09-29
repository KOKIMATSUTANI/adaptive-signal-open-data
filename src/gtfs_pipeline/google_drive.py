"""
Google Drive連携モジュール

GTFSデータをGoogle Driveに自動アップロードする機能を提供
"""

import os
import logging
from pathlib import Path
from typing import Optional, List
from datetime import datetime

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
    Google Drive連携管理クラス
    """
    
    # Google Drive API スコープ
    SCOPES = ['https://www.googleapis.com/auth/drive.file']
    
    def __init__(self, config: GTFSConfig):
        """
        Google Drive Manager初期化
        
        Args:
            config: GTFS設定オブジェクト
        """
        self.config = config
        self.logger = logging.getLogger(__name__)
        self.drive_service = None
        self.gauth = None
        self.drive = None
        
    def authenticate(self) -> bool:
        """
        Google Drive認証を実行
        
        Returns:
            True if authentication successful, False otherwise
        """
        try:
            # 認証情報ファイルのパス
            creds_file = os.path.join(self.config.data_directory, 'credentials.json')
            token_file = os.path.join(self.config.data_directory, 'token.json')
            
            if not os.path.exists(creds_file):
                self.logger.error(f"Credentials file not found: {creds_file}")
                self.logger.info("Please download credentials.json from Google Cloud Console")
                return False
            
            # 認証フロー
            creds = None
            if os.path.exists(token_file):
                creds = Credentials.from_authorized_user_file(token_file, self.SCOPES)
            
            if not creds or not creds.valid:
                if creds and creds.expired and creds.refresh_token:
                    creds.refresh(Request())
                else:
                    flow = InstalledAppFlow.from_client_secrets_file(creds_file, self.SCOPES)
                    creds = flow.run_local_server(port=0)
                
                # トークンを保存
                with open(token_file, 'w') as token:
                    token.write(creds.to_json())
            
            # Drive API サービスを構築
            self.drive_service = build('drive', 'v3', credentials=creds)
            
            # PyDrive2認証
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
        Google Driveにフォルダを作成
        
        Args:
            folder_name: フォルダ名
            parent_folder_id: 親フォルダID（Noneの場合はルート）
            
        Returns:
            作成されたフォルダのID、失敗時はNone
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
        Google Driveでフォルダを検索
        
        Args:
            folder_name: フォルダ名
            parent_folder_id: 親フォルダID
            
        Returns:
            フォルダのID、見つからない場合はNone
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
        ファイルをGoogle Driveにアップロード
        
        Args:
            file_path: アップロードするファイルのパス
            folder_id: アップロード先フォルダID
            file_name: アップロード時のファイル名（Noneの場合は元のファイル名）
            
        Returns:
            True if successful, False otherwise
        """
        try:
            if not os.path.exists(file_path):
                self.logger.error(f"File not found: {file_path}")
                return False
            
            if file_name is None:
                file_name = os.path.basename(file_path)
            
            # ファイルメタデータ
            file_metadata = {'name': file_name}
            if folder_id:
                file_metadata['parents'] = [folder_id]
            
            # メディアファイル
            media = MediaFileUpload(file_path, resumable=True)
            
            # アップロード実行
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
        GTFSデータをGoogle Driveにアップロード
        
        Args:
            data_directory: GTFSデータが保存されているディレクトリ
            
        Returns:
            True if successful, False otherwise
        """
        try:
            # 認証チェック
            if not self.drive_service:
                if not self.authenticate():
                    return False
            
            # 日付フォルダを作成
            today = datetime.now().strftime("%Y-%m-%d")
            date_folder_id = self.find_folder(today)
            if not date_folder_id:
                date_folder_id = self.create_folder(today)
                if not date_folder_id:
                    return False
            
            # GTFSデータフォルダを作成
            gtfs_folder_id = self.find_folder("GTFS_Data", date_folder_id)
            if not gtfs_folder_id:
                gtfs_folder_id = self.create_folder("GTFS_Data", date_folder_id)
                if not gtfs_folder_id:
                    return False
            
            # データディレクトリ内のファイルをアップロード
            data_path = Path(data_directory)
            uploaded_count = 0
            
            for file_path in data_path.rglob("*"):
                if file_path.is_file():
                    # 相対パスでフォルダ構造を維持
                    relative_path = file_path.relative_to(data_path)
                    folder_structure = relative_path.parent
                    
                    # サブフォルダを作成
                    current_folder_id = gtfs_folder_id
                    if folder_structure != Path('.'):
                        for folder_name in folder_structure.parts:
                            sub_folder_id = self.find_folder(folder_name, current_folder_id)
                            if not sub_folder_id:
                                sub_folder_id = self.create_folder(folder_name, current_folder_id)
                            current_folder_id = sub_folder_id
                    
                    # ファイルをアップロード
                    if self.upload_file(str(file_path), current_folder_id):
                        uploaded_count += 1
            
            self.logger.info(f"Successfully uploaded {uploaded_count} files to Google Drive")
            return uploaded_count > 0
            
        except Exception as e:
            self.logger.error(f"Failed to upload GTFS data: {e}")
            return False
