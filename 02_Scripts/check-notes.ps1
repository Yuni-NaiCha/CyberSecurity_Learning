# 仓库体检脚本（笔记一致性检查）
# 用法：powershell -NoProfile -ExecutionPolicy Bypass -File 02_Scripts\check-notes.ps1
# 检查项：文件名规范、README 链接、图片引用、纸质笔记标注、代码块闭合、💬 覆盖

$root = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)
$notes = Join-Path $root '01_Notes'
$readme = Join-Path $root 'README.md'
$problems = 0

function Say($level, $msg) {
    $color = switch ($level) { 'OK' { 'Green' } 'WARN' { 'Yellow' } 'ERR' { 'Red' } default { 'Gray' } }
    Write-Host ("[{0}] {1}" -f $level, $msg) -ForegroundColor $color
}

if (-not (Test-Path $notes)) { Say 'ERR' "找不到 01_Notes：$notes"; exit 1 }
if (-not (Test-Path $readme)) { Say 'ERR' "找不到 README：$readme"; exit 1 }

$files = Get-ChildItem $notes -Filter '*.md' | Sort-Object Name
Say 'OK' ("笔记 {0} 篇" -f $files.Count)

# 1. 文件名规范
foreach ($f in $files) {
    if ($f.Name -notmatch '^\d{2}-.+\.md$') { Say 'WARN' "命名不规范（应为 NN-标题.md）：$($f.Name)"; $problems++ }
    if ($f.Name -match '\s') { Say 'WARN' "文件名含空格：$($f.Name)"; $problems++ }
}

# 2. README 链接
$md = Get-Content $readme -Raw -Encoding UTF8
$links = [regex]::Matches($md, '\]\(01_Notes/([^)]+)\)') | ForEach-Object { $_.Groups[1].Value }
$missing = $links | Where-Object { -not (Test-Path (Join-Path $notes $_)) }
if ($missing) { $missing | ForEach-Object { Say 'ERR' "README 链接指向不存在的文件：$_"; $problems++ } } else { Say 'OK' ("README {0} 条链接全部有效" -f $links.Count) }
$unlisted = $files | Where-Object { $links -notcontains $_.Name }
if ($unlisted) { $unlisted | ForEach-Object { Say 'WARN' "文件未在 README 列出：$($_.Name)" } }

# 3. 图片引用
foreach ($f in $files) {
    $t = Get-Content $f.FullName -Raw -Encoding UTF8
    $imgs = [regex]::Matches($t, '!\[[^\]]*\]\((images/[^)]+)\)') | ForEach-Object { $_.Groups[1].Value }
    foreach ($i in $imgs) {
        if (-not (Test-Path (Join-Path $notes $i))) { Say 'ERR' "图片缺失：$($f.Name) -> $i"; $problems++ }
    }
}

# 4. 纸质笔记标注（有 .JPG 照片的笔记，README 应带“附纸质笔记”）
$paperNotes = @()
foreach ($f in $files) {
    $t = Get-Content $f.FullName -Raw -Encoding UTF8
    if ($t -match 'images/[^)]*\.JPG') { $paperNotes += $f.Name }
}
foreach ($p in $paperNotes) {
    if ($md -notmatch [regex]::Escape($p) -or $true) {
        $line = ($md -split "`n") | Where-Object { $_ -match [regex]::Escape($p) } | Select-Object -First 1
        if ($line -and $line -notmatch '纸质笔记') { Say 'WARN' "有手写照片但 README 缺“附纸质笔记”：$p"; $problems++ }
    }
}
Say 'OK' ("带手写照片的笔记 {0} 篇：{1}" -f $paperNotes.Count, ($paperNotes -join '、'))

# 5. 代码块闭合
foreach ($f in $files) {
    $t = Get-Content $f.FullName -Raw -Encoding UTF8
    $fences = ([regex]::Matches($t, '(?m)^```')).Count
    if ($fences % 2 -ne 0) { Say 'WARN' "代码块可能未闭合：$($f.Name)（行首 ``` 出现 $fences 次）"; $problems++ }
}

# 6. 💬 大白话覆盖（只提示，不算错）
$noDbl = $files | Where-Object {
    $t = Get-Content $_.FullName -Raw -Encoding UTF8
    -not ($t -match '💬')
} | ForEach-Object { $_.Name }
if ($noDbl) { Say 'WARN' ("没有 💬 大白话的笔记：" + ($noDbl -join '、')) }

Say 'OK' ("检查结束，问题数：{0}" -f $problems)
