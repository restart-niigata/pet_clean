param(
  [switch]$Apply = $false,     # 既定は DryRun。-Apply を付けると実際に _disabled へリネーム
  [switch]$VerbosePlan = $true # 退避対象の詳細を出力
)

$ErrorActionPreference = "Stop"

# 1) ルートと存在確認
$repoRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$projectRoot = Split-Path -Parent $repoRoot
$libPath = Join-Path $projectRoot "lib"
if (!(Test-Path $libPath)) {
  Write-Error "lib フォルダが見つかりません: $libPath"
}

# 2) “正とするパス”の優先規則（明示マップ）
#    Key: ファイル名, Value: 正とするフルパスの部分一致（配列可）
$keepRules = @{
  # コメント導線は utils 側を正
  "comments_loader.dart" = @("\lib\utils\comments_loader.dart")
  "comment_service.dart" = @("\lib\utils\comment_service.dart")
  # データ定義は data 側を正
  "species_assets.dart"  = @("\lib\data\species_assets.dart")
  # 広告は ads 側を正
  "ad_manager.dart"      = @("\lib\ads\ad_manager.dart")
  # comments_repository は repositories 側を正
  "comments_repository.dart" = @("\lib\repositories\comments_repository.dart")
}

# 3) 重複候補の検出（同名ファイル）
$allFiles = Get-ChildItem $libPath -Recurse -File -Include *.dart
$dups = $allFiles | Group-Object Name | Where-Object { $_.Count -gt 1 }

# 4) 保持・退避の計画を構築
$plan = @()

foreach ($grp in $dups) {
  $name = $grp.Name
  $candidates = $grp.Group

  # 既定: keep は keepRules に合致するもの、なければ lib/pages|lib/utils|lib/data|lib/ads の優先順位で1つ
  $keep = $null
  if ($keepRules.ContainsKey($name)) {
    $patterns = $keepRules[$name]
    foreach ($cand in $candidates) {
      foreach ($pat in $patterns) {
        if ($cand.FullName.ToLower().EndsWith($pat.ToLower())) { $keep = $cand; break }
      }
      if ($keep) { break }
    }
  }

  if (-not $keep) {
    # フォルダ優先順位
    $priority = @("\lib\pages\", "\lib\utils\", "\lib\data\", "\lib\ads\", "\lib\models\", "\lib\services\", "\lib\repositories\")
    foreach ($p in $priority) {
      $hit = $candidates | Where-Object { $_.FullName.ToLower().Contains($p.ToLower()) }
      if ($hit) { $keep = $hit | Select-Object -First 1; break }
    }
  }

  if (-not $keep) {
    # それでも決まらなければ、更新日時が新しいもの
    $keep = $candidates | Sort-Object LastWriteTime -Descending | Select-Object -First 1
  }

  $disable = $candidates | Where-Object { $_.FullName -ne $keep.FullName }

  foreach ($d in $disable) {
    $target = "$($d.FullName)._disabled.dart"
    $plan += [pscustomobject]@{
      Type="DUP_NAME"
      File=$d.FullName
      Keep=$keep.FullName
      DisableTo=$target
    }
  }
}

# 5) pages 配下の未参照（import も route 参照もされていない）候補を抽出
function Test-Referenced {
  param([string]$FileFullPath)
  $fileName = Split-Path $FileFullPath -Leaf
  $stem = [System.IO.Path]::GetFileNameWithoutExtension($fileName)
  # import行・Navigator遷移・MaterialPageRoute・GoRouter風・単純クラス名参照 などをざっくり探索
  $patterns = @(
    "import\s+['""](.*/)?$([regex]::Escape($fileName))['""]",
    "MaterialPageRoute\(.*$([regex]::Escape($stem))",
    "CupertinoPageRoute\(.*$([regex]::Escape($stem))",
    "GoRoute\(.*$([regex]::Escape($stem))",
    "\b$([regex]::Escape($stem))\s*\("  # コンストラクタ呼び出しの簡易検出
  )
  $libTexts = Get-ChildItem $libPath -Recurse -File -Include *.dart | ForEach-Object { Get-Content $_.FullName -Raw }
  foreach ($t in $libTexts) {
    foreach ($pat in $patterns) {
      if ($t -match $pat) { return $true }
    }
  }
  return $false
}

$pages = Get-ChildItem (Join-Path $libPath "pages") -Recurse -File -Include *.dart -ErrorAction SilentlyContinue
foreach ($p in $pages) {
  if (-not (Test-Referenced -FileFullPath $p.FullName)) {
    $target = "$($p.FullName)._disabled.dart"
    $plan += [pscustomobject]@{
      Type="PAGES_UNUSED?"
      File=$p.FullName
      Keep=""
      DisableTo=$target
    }
  }
}

# 6) プラン出力
if ($VerbosePlan) {
  Write-Host "=== Dedupe/Disable PLAN (DryRun=$(-not $Apply)) ===" -ForegroundColor Cyan
  $plan | Format-Table -AutoSize
}

# 7) 適用
if ($Apply) {
  foreach ($item in $plan) {
    $src = $item.File
    $dst = $item.DisableTo
    if (Test-Path $dst) { continue }
    Rename-Item -Path $src -NewName ([System.IO.Path]::GetFileName($dst))
  }
  Write-Host "適用完了: $($plan.Count) 件を _disabled へ退避しました。" -ForegroundColor Green
} else {
  Write-Host "DryRun 完了: 退避対象 $($plan.Count) 件。-Apply を付けると実行します。" -ForegroundColor Yellow
}
