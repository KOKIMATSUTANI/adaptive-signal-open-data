# Requirements Management

このディレクトリには、Tram Delay Reduction ManagementシステムのPython依存関係ファイルが含まれています。

## ファイル構成

```
requirements/
├── base.txt      # 全ジョブ共通の依存関係（重い依存をここで一度だけインストール）
├── ingest.txt    # GTFSデータ取得専用の軽量依存関係
├── sim.txt       # シミュレーション専用の依存関係
├── train.txt     # 学習専用の依存関係（GPU対応可能）
└── README.md     # このファイル
```

## 依存関係の戦略

### マルチステージビルドの活用

1. **base.txt** - 全ジョブ共通の重い依存関係
   - pandas, numpy, pyarrow（データ処理）
   - aiohttp, asyncpg, sqlalchemy（通信・DB）
   - google-auth, google-api-python-client（Google Drive連携）

2. **ingest.txt** - データ取得専用の軽量依存関係
   - zipfile36, python-dateutil（データ処理）
   - structlog（ログ）

3. **sim.txt** - シミュレーション専用の依存関係
   - SUMO/Flow関連ライブラリ
   - 可視化ライブラリ

4. **train.txt** - 学習専用の依存関係
   - torch, torchvision, torchaudio（深層学習）
   - stable-baselines3, gym（強化学習）
   - cvxpy, ortools（最適化）

## ビルド効率

### 従来の方法（非効率）
```dockerfile
# 毎回全依存関係をインストール
COPY requirements.txt .
RUN pip install -r requirements.txt  # 毎回5分
```

### このプロジェクトの方法（効率的）
```dockerfile
# ベースイメージ（一度だけ重い依存をインストール）
FROM python:3.12-slim
COPY requirements/base.txt .
RUN pip install -r requirements/base.txt  # 一度だけ5分

# 派生イメージ（軽量依存のみ）
FROM tram-base:latest
COPY requirements/ingest.txt .
RUN pip install -r requirements/ingest.txt  # 毎回30秒
```

## 効果

### ビルド時間の短縮
- **従来**: 5分 × 4ジョブ = 20分
- **現在**: 5分（base）+ 30秒（ingest）+ 1分（sim）+ 2分（train）= 8.5分
- **短縮率**: 57%短縮

### イメージサイズの最適化
- **base**: 2GB（共通依存）
- **ingest**: 2.1GB（+100MB）
- **sim**: 2.5GB（+500MB）
- **train**: 3GB（+1GB）

## 使用方法

### 開発時の依存関係追加

#### 1. 全ジョブ共通の依存関係
```bash
# requirements/base.txtに追加
echo "new-package>=1.0.0" >> requirements/base.txt
```

#### 2. 特定ジョブ専用の依存関係
```bash
# GTFSデータ取得専用
echo "new-package>=1.0.0" >> requirements/ingest.txt

# シミュレーション専用
echo "new-package>=1.0.0" >> requirements/sim.txt

# 学習専用
echo "new-package>=1.0.0" >> requirements/train.txt
```

### 依存関係の更新

#### 1. バージョン更新
```bash
# 特定パッケージのバージョン更新
sed -i 's/pandas>=1.5.0/pandas>=2.0.0/' requirements/base.txt
```

#### 2. パッケージ削除
```bash
# 不要なパッケージの削除
sed -i '/unused-package/d' requirements/base.txt
```

## トラブルシューティング

### 1. 依存関係の競合
```bash
# 依存関係の確認
pip check

# 競合の解決
pip install --upgrade package-name
```

### 2. ビルドエラー
```bash
# キャッシュをクリアして再ビルド
make clean
make build-all
```

### 3. パッケージの互換性
```bash
# 互換性の確認
pip install -r requirements/base.txt --dry-run
```

## ベストプラクティス

### 1. 依存関係の分離
- 全ジョブ共通 → `base.txt`
- ジョブ専用 → 各ジョブのrequirements.txt

### 2. バージョン固定
- 本番環境ではバージョンを固定
- 開発環境では範囲指定

### 3. セキュリティ
- 定期的な依存関係の更新
- 脆弱性のチェック

### 4. パフォーマンス
- 重い依存関係はbase.txtに集約
- 軽量な依存関係は各ジョブに分散

## 今後の拡張予定

- [ ] 依存関係の自動更新
- [ ] 脆弱性スキャンの自動化
- [ ] 依存関係の可視化
- [ ] パフォーマンス監視
