#!/usr/bin/env python3
"""
lark-doc-upload.py — Markdown + 本地图片 → 精美排版飞书文档

核心能力：
- 单图：原图上传 + PATCH 设置合理显示尺寸（点击可放大）
- 多图并排：使用飞书 Grid 分栏布局（block type 24+25），真正并排显示
- 表格内图片：替换为文字描述（飞书表格不支持嵌入图片）
- 文本：通过 lark-cli docs +update append

认证方式（按优先级）：
1. 环境变量 LARK_ACCESS_TOKEN（直接使用）
2. 环境变量 LARK_APP_ID + LARK_APP_SECRET（自动 OAuth 设备码登录）
3. 复用 lark-cli 已有配置（自动读取 app_id，提示输入 app_secret）

用法:
    python3 lark-doc-upload.py report.md
    python3 lark-doc-upload.py report.md --title "自定义标题"
    python3 lark-doc-upload.py report.md --update <doc_id>
    python3 lark-doc-upload.py report.md --dry-run

依赖:
    pip3 install requests Pillow
    lark-cli >= 1.0.1 (npm install -g @larksuite/cli) — 用于文本追加

关联 issue: #IIYHAA
"""

import argparse
import json
import os
import re
import subprocess
import sys
import time
from pathlib import Path

import requests

try:
    from PIL import Image as PILImage
    HAS_PIL = True
except ImportError:
    HAS_PIL = False


# ── 常量 ────────────────────────────────────────────────
MAX_MARKDOWN_CHUNK = 28000
DELAY_TEXT = 0.3
DELAY_IMAGE = 0.5
DELAY_API = 0.2
FEISHU_DOC_WIDTH = 700
DISPLAY_SCALE = 2.0
BASE_URL = "https://open.feishu.cn"
TOKEN_CACHE = Path.home() / ".lark-cli" / "cache" / "py_token.json"
IMG_PATTERN = re.compile(r'<img\s+src="([^"]+)"([^>]*)/?>|!\[([^\]]*)\]\(([^)]+)\)')


# ── 认证 ─────────────────────────────────────────────────

class FeishuAuth:
    """飞书认证管理：app_access_token（自动获取 + 缓存）"""

    def __init__(self):
        self.access_token = None
        self.expires_at = 0

    def get_token(self):
        if self.access_token and time.time() < self.expires_at - 60:
            return self.access_token

        # 1. 环境变量直传
        token = os.environ.get("LARK_ACCESS_TOKEN")
        if token:
            self.access_token = token
            self.expires_at = time.time() + 7200
            return token

        # 2. 缓存
        if TOKEN_CACHE.exists():
            try:
                cache = json.loads(TOKEN_CACHE.read_text())
                if cache.get("expires_at", 0) > time.time() + 60:
                    self.access_token = cache["access_token"]
                    self.expires_at = cache["expires_at"]
                    return self.access_token
            except (json.JSONDecodeError, KeyError):
                pass

        # 3. 获取 app_access_token
        app_id, app_secret = self._get_app_credentials()
        return self._get_app_token(app_id, app_secret)

    def _get_app_credentials(self):
        app_id = os.environ.get("LARK_APP_ID")
        app_secret = os.environ.get("LARK_APP_SECRET")
        if app_id and app_secret:
            return app_id, app_secret

        # 从 lark-cli 配置读取 app_id
        config_path = Path.home() / ".lark-cli" / "config.json"
        if config_path.exists():
            try:
                cfg = json.loads(config_path.read_text())
                app_id = cfg["apps"][0]["appId"]
            except (json.JSONDecodeError, KeyError, IndexError):
                pass

        if not app_id:
            app_id = input("请输入飞书 App ID: ").strip()
        if not app_secret:
            app_secret = input("请输入飞书 App Secret: ").strip()

        return app_id, app_secret

    def _get_app_token(self, app_id, app_secret):
        resp = requests.post(f"{BASE_URL}/open-apis/auth/v3/app_access_token/internal", json={
            "app_id": app_id,
            "app_secret": app_secret,
        })
        data = resp.json()
        if data.get("code") != 0:
            print(f"❌ 获取 token 失败: {data}")
            sys.exit(1)

        self.access_token = data["app_access_token"]
        self.expires_at = time.time() + data.get("expire", 3600)

        TOKEN_CACHE.parent.mkdir(parents=True, exist_ok=True)
        TOKEN_CACHE.write_text(json.dumps({
            "access_token": self.access_token,
            "expires_at": self.expires_at,
            "app_id": app_id,
            "app_secret": app_secret,
        }))
        return self.access_token


# ── 飞书 API ────────────────────────────────────────────

class FeishuDocAPI:
    """飞书文档 API 封装"""

    def __init__(self, auth: FeishuAuth):
        self.auth = auth
        self.session = requests.Session()

    def _headers(self):
        return {"Authorization": f"Bearer {self.auth.get_token()}"}

    def _api(self, method, path, **kwargs):
        url = f"{BASE_URL}{path}"
        resp = self.session.request(method, url, headers=self._headers(), **kwargs)
        return resp.json()

    # ── 文档操作 ──

    def create_document(self, title, folder_token=None):
        """用 app_access_token 创建文档（app 作为 owner，确保后续 block API 有权限）"""
        body = {"title": title}
        if folder_token:
            body["folder_token"] = folder_token
        data = self._api("POST", "/open-apis/docx/v1/documents", json=body)
        if data.get("code") != 0:
            print(f"❌ 创建文档失败: {data.get('msg')}")
            return None, None
        doc = data["data"]["document"]
        doc_id = doc["document_id"]
        doc_url = f"https://www.feishu.cn/docx/{doc_id}"

        # 把文档分享给当前用户（让 lark-cli 的 user token 也能操作）
        self._grant_user_permission(doc_id)
        return doc_id, doc_url

    def _grant_user_permission(self, doc_id):
        """给当前 lark-cli 登录用户授予文档编辑权限"""
        config_path = Path.home() / ".lark-cli" / "config.json"
        user_id = None
        if config_path.exists():
            try:
                cfg = json.loads(config_path.read_text())
                user_id = cfg["apps"][0]["users"][0]["userOpenId"]
            except (json.JSONDecodeError, KeyError, IndexError):
                pass
        if user_id:
            self._api("POST", f"/open-apis/drive/v1/permissions/{doc_id}/members",
                      json={"member_type": "openid", "member_id": user_id, "perm": "full_access"},
                      params={"type": "docx", "need_notification": "false"})

    def append_text(self, doc_id, markdown_text):
        """通过 lark-cli (user token) 追加文本（markdown 渲染）。用 stdin 传入避免 shell 转义问题。"""
        cmd = ['lark-cli', 'docs', '+update', '--doc', doc_id,
               '--mode', 'append', '--markdown', '-']
        try:
            r = subprocess.run(cmd, input=markdown_text,
                               capture_output=True, text=True, timeout=60)
            if r.returncode == 0:
                return True
            print(f"    ⚠️  lark-cli 追加失败: {r.stderr[:100] or r.stdout[:100]}")
            return False
        except subprocess.TimeoutExpired:
            print(f"    ⚠️  lark-cli 追加超时")
            return False

    # ── Block 操作 ──

    def get_block(self, doc_id, block_id):
        data = self._api("GET", f"/open-apis/docx/v1/documents/{doc_id}/blocks/{block_id}")
        return data.get("data", {}).get("block", {})

    def create_children(self, doc_id, parent_id, children):
        """在 parent block 下创建子 block"""
        data = self._api("POST",
                         f"/open-apis/docx/v1/documents/{doc_id}/blocks/{parent_id}/children",
                         json={"children": children})
        if data.get("code") != 0:
            print(f"    ⚠️  创建 block 失败: {data.get('msg')}")
            return None
        return data["data"]["children"]

    def patch_block(self, doc_id, block_id, body):
        data = self._api("PATCH",
                         f"/open-apis/docx/v1/documents/{doc_id}/blocks/{block_id}",
                         json=body, params={"document_revision_id": "-1"})
        return data.get("code") == 0

    def delete_children(self, doc_id, parent_id, start_idx, end_idx):
        self._api("DELETE",
                  f"/open-apis/docx/v1/documents/{doc_id}/blocks/{parent_id}/children/batch_delete",
                  json={"start_index": start_idx, "end_index": end_idx},
                  params={"document_revision_id": "-1"})

    # ── Grid 操作 ──

    def create_grid(self, doc_id, parent_id, column_count):
        """创建 grid 分栏，返回 grid_block 和 column_block_ids"""
        children = self.create_children(doc_id, parent_id, [{
            "block_type": 24,
            "grid": {"column_size": min(column_count, 5)}
        }])
        if not children:
            return None, []
        grid = children[0]
        return grid["block_id"], grid.get("children", [])

    def create_image_block(self, doc_id, parent_id):
        """在 parent 下创建空 image block，返回 block_id"""
        children = self.create_children(doc_id, parent_id, [{
            "block_type": 27,
            "image": {}
        }])
        if not children:
            return None
        return children[0]["block_id"]

    # ── 图片上传 ──

    def upload_image_to_block(self, doc_id, image_block_id, image_path):
        """上传图片到指定 image block（multipart/form-data），返回 file_token"""
        file_size = os.path.getsize(image_path)
        file_name = os.path.basename(image_path)

        with open(image_path, "rb") as f:
            resp = self.session.post(
                f"{BASE_URL}/open-apis/drive/v1/medias/upload_all",
                headers=self._headers(),
                data={
                    "file_name": file_name,
                    "parent_type": "docx_image",
                    "parent_node": image_block_id,
                    "size": str(file_size),
                },
                files={"file": (file_name, f)},
            )
        data = resp.json()
        if data.get("code") != 0:
            print(f"    ⚠️  上传图片失败 ({file_name}): {data.get('msg')}")
            return None
        return data["data"]["file_token"]

    def bind_image(self, doc_id, block_id, file_token, width, height):
        """绑定 file_token 到 image block 并设置显示尺寸"""
        return self.patch_block(doc_id, block_id, {
            "replace_image": {
                "token": file_token,
                "width": width,
                "height": height,
            }
        })

    # ── 高级操作 ──

    def insert_single_image(self, doc_id, image_path, display_width, max_width):
        """上传单张图片到文档末尾，设置显示尺寸"""
        # 创建 image block 在文档根节点
        block_id = self.create_image_block(doc_id, doc_id)
        if not block_id:
            print(f"    ⚠️  创建 image block 失败")
            return False
        time.sleep(DELAY_API)

        # 上传图片
        file_token = self.upload_image_to_block(doc_id, block_id, image_path)
        if not file_token:
            return False
        time.sleep(DELAY_API)

        # 获取原始尺寸
        orig_w, orig_h = get_image_size(image_path)
        dw = min(display_width, max_width, orig_w)
        dh = max(int(orig_h * dw / orig_w), 1) if orig_w else 100

        # 绑定并设置显示尺寸
        return self.bind_image(doc_id, block_id, file_token, dw, dh)

    def insert_grid_images(self, doc_id, images, max_width):
        """
        用 grid 分栏并排多张图片。
        images: [(abs_path, md_width), ...]
        """
        n = len(images)
        if n > 5:
            n = 5  # API 限制最多 5 列
            images = images[:5]

        # 1. 创建 grid
        grid_id, col_ids = self.create_grid(doc_id, doc_id, n)
        if not grid_id or len(col_ids) < n:
            print(f"    ⚠️  创建 grid 失败")
            return False
        time.sleep(DELAY_API)

        ok = True
        for i, (path, md_w) in enumerate(images):
            col_id = col_ids[i]

            # 2. 在 column 中创建 image block
            img_block = self.create_image_block(doc_id, col_id)
            if not img_block:
                ok = False
                continue
            time.sleep(DELAY_API)

            # 3. 上传图片到该 block
            file_token = self.upload_image_to_block(doc_id, img_block, path)
            if not file_token:
                ok = False
                continue
            time.sleep(DELAY_API)

            # 4. 设置显示尺寸（column 内宽度自适应，设较大值让其填满列）
            orig_w, orig_h = get_image_size(path)
            col_width = max_width // n  # 每列宽度
            dw = min(orig_w, col_width)
            dh = max(int(orig_h * dw / orig_w), 1) if orig_w else 100
            self.bind_image(doc_id, img_block, file_token, dw, dh)
            time.sleep(DELAY_API)

        return ok


# ── 辅助 ─────────────────────────────────────────────────

def get_image_size(path):
    if HAS_PIL:
        try:
            img = PILImage.open(path)
            return img.size
        except Exception:
            pass
    return 600, 1300  # fallback


def extract_title(content):
    for line in content.split('\n'):
        if line.strip().startswith('# '):
            return line.strip()[2:].strip()
    return "Untitled"


def resolve_image_path(src, base_dir):
    if src.startswith(('http://', 'https://')):
        return None
    p = Path(base_dir) / src
    if p.is_file():
        return str(p.resolve())
    name = Path(src).name
    candidates = list(Path(base_dir).rglob(name))
    return str(candidates[0].resolve()) if candidates else None


def parse_img_width(tag_str):
    m = re.search(r'width="(\d+)"', tag_str)
    return int(m.group(1)) if m else None


def compute_display_width(orig_w, md_width, max_width):
    # 单图宽度 ≈ 5列 Grid 中每列的宽度（max_width / 5 ≈ 140px）
    target = max_width // 5
    return min(target, orig_w)


# ── Markdown 解析 ────────────────────────────────────────

def split_segments(content, base_dir):
    """
    拆分为有序段列表：
      ('text', markdown_string)
      ('image', [(abs_path, md_width), ...])  — 单图或多图（同行并排）
    """
    segments = []
    text_buf = []
    in_table = False

    def flush_text():
        t = '\n'.join(text_buf).strip()
        if t:
            segments.append(('text', t))
        text_buf.clear()

    for line in content.split('\n'):
        stripped = line.strip()
        is_table_row = stripped.startswith('|') and stripped.endswith('|')

        if is_table_row and not in_table:
            in_table = True
        elif in_table and not is_table_row and not re.match(r'^\|[-:\s|]+\|$', stripped):
            in_table = False

        images_in_line = list(IMG_PATTERN.finditer(line))
        if not images_in_line:
            text_buf.append(line)
            continue

        remaining = line
        line_images = []
        for m in reversed(images_in_line):
            src = m.group(1) or m.group(4)
            width = parse_img_width(m.group(0))
            abs_path = resolve_image_path(src, base_dir)
            if abs_path:
                if in_table:
                    fname = Path(src).stem.replace('-', ' ')
                    remaining = remaining[:m.start()] + f'[{fname}]' + remaining[m.end():]
                else:
                    line_images.insert(0, (abs_path, width))
                    remaining = remaining[:m.start()] + remaining[m.end():]

        if not in_table:
            remaining = re.sub(r'\s*→\s*→?\s*', ' ', remaining).strip()

        if remaining.strip() and remaining.strip() not in ('|', '→'):
            text_buf.append(remaining)

        if not in_table and line_images:
            flush_text()
            segments.append(('image', line_images))

    flush_text()
    return segments


def merge_text_segments(segments):
    merged = []
    text_buf = []

    def flush():
        if text_buf:
            combined = '\n\n'.join(text_buf)
            if len(combined) <= MAX_MARKDOWN_CHUNK:
                merged.append(('text', combined))
            else:
                chunks, current = [], ""
                for part in text_buf:
                    if len(current) + len(part) + 2 > MAX_MARKDOWN_CHUNK:
                        if current:
                            chunks.append(current)
                        current = part
                    else:
                        current = current + '\n\n' + part if current else part
                if current:
                    chunks.append(current)
                for c in chunks:
                    merged.append(('text', c))
            text_buf.clear()

    for seg in segments:
        if seg[0] == 'text':
            text_buf.append(seg[1])
        else:
            flush()
            merged.append(seg)
    flush()
    return merged


# ── CLI ──────────────────────────────────────────────────

def parse_args():
    p = argparse.ArgumentParser(description="Markdown + 本地图片 → 精美排版飞书文档")
    p.add_argument("markdown", help="Markdown 文件路径")
    p.add_argument("--title", help="文档标题")
    p.add_argument("--folder-token", help="飞书文件夹 token")
    p.add_argument("--update", metavar="DOC_ID", help="追加到已有文档")
    p.add_argument("--dry-run", action="store_true", help="只解析不执行")
    p.add_argument("--max-width", type=int, default=FEISHU_DOC_WIDTH)
    return p.parse_args()


# ── Main ─────────────────────────────────────────────────

def main():
    args = parse_args()
    md_path = Path(args.markdown).resolve()
    if not md_path.is_file():
        print(f"错误: 文件不存在 {md_path}")
        sys.exit(1)

    base_dir = md_path.parent
    content = md_path.read_text(encoding='utf-8')
    title = args.title or extract_title(content)

    # 跳过标题行
    lines = content.split('\n')
    for i, line in enumerate(lines):
        if line.strip().startswith('# '):
            content = '\n'.join(lines[i+1:])
            break

    raw_segments = split_segments(content, base_dir)
    segments = merge_text_segments(raw_segments)

    text_count = sum(1 for s in segments if s[0] == 'text')
    img_segs = [s for s in segments if s[0] == 'image']
    single_imgs = sum(1 for s in img_segs if len(s[1]) == 1)
    multi_imgs = sum(1 for s in img_segs if len(s[1]) > 1)
    total_imgs = sum(len(s[1]) for s in img_segs)
    total = len(segments)

    print(f"📄 {title}")
    print(f"   {total} 段: {text_count} 文本, {single_imgs} 单图, {multi_imgs} 并排组 ({total_imgs} 张原图)")

    if args.dry_run:
        print("\n--- Dry Run ---")
        for i, seg in enumerate(segments):
            if seg[0] == 'text':
                preview = seg[1][:80].replace('\n', '\\n')
                print(f"  [{i+1}/{total}] TEXT ({len(seg[1])} chars): {preview}...")
            else:
                imgs = seg[1]
                names = [os.path.basename(p) for p, _ in imgs]
                if len(imgs) > 1:
                    print(f"  [{i+1}/{total}] GRID [{len(imgs)}列]: {' | '.join(names)}")
                else:
                    w = imgs[0][1]
                    print(f"  [{i+1}/{total}] IMAGE: {names[0]}" + (f" (w={w})" if w else ""))
        return

    # 认证
    auth = FeishuAuth()
    api = FeishuDocAPI(auth)

    # 验证 token
    print("\n[1] 认证...")
    token = auth.get_token()
    print(f"   ✅ token 有效")

    # 创建文档
    if args.update:
        doc_id = args.update
        doc_url = f"https://www.feishu.cn/docx/{doc_id}"
        print(f"\n[2] 追加到: {doc_url}")
    else:
        print(f"\n[2] 创建文档...")
        doc_id, doc_url = api.create_document(title, args.folder_token)
        if not doc_id:
            sys.exit(1)
        print(f"   ✅ {doc_url}")

    # 上传
    print(f"\n[3] 上传内容...")
    success, fail = 0, 0
    t0 = time.time()

    for i, seg in enumerate(segments):
        progress = f"[{i+1}/{total}]"

        if seg[0] == 'text':
            print(f"  {progress} 追加文本 ({len(seg[1])} chars)...")
            ok = api.append_text(doc_id, seg[1])
            time.sleep(DELAY_TEXT)

        else:
            imgs = seg[1]
            if len(imgs) == 1:
                # 单图
                path, md_w = imgs[0]
                orig_w, _ = get_image_size(path)
                dw = compute_display_width(orig_w, md_w, args.max_width)
                print(f"  {progress} 插入图片: {os.path.basename(path)} (显示宽{dw}px)")
                ok = api.insert_single_image(doc_id, path, dw, args.max_width)
            else:
                # 多图 → Grid 并排
                names = [os.path.basename(p) for p, _ in imgs]
                print(f"  {progress} 并排 {len(imgs)} 张: {', '.join(names)}")
                ok = api.insert_grid_images(doc_id, imgs, args.max_width)
            time.sleep(DELAY_IMAGE)

        if ok:
            success += 1
        else:
            fail += 1

    elapsed = time.time() - t0
    print(f"\n[4] 完成!")
    print(f"   成功: {success}/{total}  失败: {fail}")
    print(f"   耗时: {elapsed:.1f}s")
    print(f"   文档: {doc_url}")

    if fail > 0:
        sys.exit(1)


if __name__ == '__main__':
    main()
