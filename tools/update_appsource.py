#!/usr/bin/env python3
"""
Generate UTF-8 AppSource JSON (compatible with 全能签 / ESign & AltStore)
and a clean static GitHub Pages landing page in docs/.
"""

import argparse
import json
import os
from datetime import datetime, timezone


def main():
    parser = argparse.ArgumentParser(description="Update JiaGuIME AppSource JSON & Pages HTML.")
    parser.add_argument("--owner", required=True)
    parser.add_argument("--repo", required=True)
    parser.add_argument("--version", required=True)
    parser.add_argument("--build", required=True)
    parser.add_argument("--tag", required=True)
    parser.add_argument("--ipa-name", required=True)
    parser.add_argument("--ipa-size", type=int, required=True)
    parser.add_argument("--changelog", default="自动构建更新：优化全拼与小鹤双拼解码、触控跟手度与深浅色主题同步。")
    parser.add_argument("--docs-dir", default="docs")
    args = parser.parse_args()

    os.makedirs(args.docs_dir, exist_ok=True)

    pages_base = f"https://{args.owner}.github.io/{args.repo}"
    icon_url = f"{pages_base}/icon.png"
    download_url = f"https://github.com/{args.owner}/{args.repo}/releases/download/{args.tag}/{args.ipa_name}"
    now_iso = datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")
    full_ver = f"{args.version}"

    appsource = {
        "name": "甲骨输入法 (JiaGuIME) 官方软件源",
        "identifier": "com.custom.ime.source",
        "subtitle": "纯血 C++17 自研全拼 & 小鹤双拼 iOS 输入法",
        "description": "100% 纯血自研 C++17 音节切分与维特比解码引擎，零拷贝 mmap 雾凇词库，全画布裸触控有限状态机，支持全拼与小鹤双拼。",
        "iconURL": icon_url,
        "website": pages_base,
        "sourceURL": f"{pages_base}/appsource.json",
        "apps": [
            {
                "name": "甲骨输入法",
                "bundleIdentifier": "com.custom.ime",
                "developerName": "0xSny",
                "subtitle": "全拼 · 小鹤双拼 · 零延迟裸触控",
                "version": full_ver,
                "versionDate": now_iso,
                "versionDescription": f"Build {args.build}: {args.changelog}",
                "downloadURL": download_url,
                "localizedDescription": (
                    "纯血 C++17 自研 iOS 中文输入法，原生支持全拼与正统小鹤双拼。\n"
                    "• 零拷贝 mmap 雾凇词库，Dirty RAM 远低于 45MB 红线\n"
                    "• 全画布裸触控有限状态机 + Voronoi 零死角剖分 + 双指并击防吞字\n"
                    "• 增量自学习词库、分段自动造词、退格反悔回滚\n"
                    "• 100% 本地离线，零联网零隐私上传"
                ),
                "iconURL": icon_url,
                "tintColor": "#1468E0",
                "size": args.ipa_size,
                "versions": [
                    {
                        "version": full_ver,
                        "buildVersion": str(args.build),
                        "date": now_iso,
                        "localizedDescription": f"Build {args.build}: {args.changelog}",
                        "downloadURL": download_url,
                        "size": args.ipa_size,
                    }
                ],
                "appPermissions": {
                    "entitlements": [],
                    "privacy": {
                        "NSRequestsOpenAccess": "用于剪贴板快捷粘贴胶囊与键盘内触感声效增强，输入法本体零联网。"
                    }
                }
            }
        ],
        "news": []
    }

    appsource_path = os.path.join(args.docs_dir, "appsource.json")
    with open(appsource_path, "w", encoding="utf-8") as f:
        json.dump(appsource, f, ensure_ascii=False, indent=2)

    size_mb = args.ipa_size / (1024.0 * 1024.0)
    html = f"""<!DOCTYPE html>
<html lang="zh-CN">
<head>
  <meta charset="utf-8" />
  <meta name="viewport" content="width=device-width, initial-scale=1" />
  <title>甲骨输入法 JiaGuIME — 全能签软件源</title>
  <style>
    :root {{ color-scheme: light dark; }}
    body {{
      font-family: -apple-system, BlinkMacSystemFont, "SF Pro Text", "PingFang SC", sans-serif;
      max-width: 680px; margin: 40px auto; padding: 0 20px; line-height: 1.65;
    }}
    .card {{
      border: 1px solid rgba(128,128,128,0.22); border-radius: 16px;
      padding: 24px; background: rgba(128,128,128,0.06);
    }}
    .header {{ display: flex; align-items: center; gap: 16px; margin-bottom: 16px; }}
    .header img {{ width: 72px; height: 72px; border-radius: 16px; }}
    .btn {{
      display: inline-block; padding: 10px 18px; border-radius: 10px;
      background: #1468E0; color: #fff; text-decoration: none; font-weight: 600;
      margin-right: 10px; margin-top: 8px;
    }}
    code {{
      display: block; padding: 12px; border-radius: 10px;
      background: rgba(128,128,128,0.14); word-break: break-all; margin: 10px 0;
    }}
  </style>
</head>
<body>
  <div class="card">
    <div class="header">
      <img src="{icon_url}" alt="JiaGuIME Icon" />
      <div>
        <h1 style="margin:0;">甲骨输入法 JiaGuIME</h1>
        <div style="opacity:0.75;">v{full_ver} (Build {args.build}) · {size_mb:.2f} MB · 100% 离线纯血 C++17</div>
      </div>
    </div>
    <p>全能签 / AltStore 软件源订阅地址（复制下方链接添加到全能签 → 软件源）：</p>
    <code>{pages_base}/appsource.json</code>
    <a class="btn" href="{download_url}">直接下载最新 IPA</a>
    <a class="btn" style="background:#334155;" href="{pages_base}/appsource.json">查看软件源 JSON</a>
  </div>
</body>
</html>
"""
    with open(os.path.join(args.docs_dir, "index.html"), "w", encoding="utf-8") as f:
        f.write(html)

    print(f"[appsource] Updated {appsource_path} (v{full_ver} build {args.build}, {args.ipa_size} bytes)")


if __name__ == "__main__":
    main()
