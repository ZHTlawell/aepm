#!/usr/bin/env python3
"""
image_decopyrighter.py — 图片去版权化工具

将有版权风险的图片通过 AI 重绘生成可商用替代图片。
流程：读取图片 → Gemini Flash 提取语义描述 → Imagen 4.0 重绘 → 输出新图片

全程只需一个 GEMINI_API_KEY。

Backends (生成后端):
    gemini    — Imagen 4.0，需要 GEMINI_API_KEY（默认）
    together  — Flux Schnell，$0.003/张，需要 TOGETHER_API_KEY
    dalle     — DALL-E 3，$0.04/张，需要 OPENAI_API_KEY

Usage:
    python3 image_decopyrighter.py auto <image_path>                          # 默认 gemini
    python3 image_decopyrighter.py auto <image_path> --backend dalle          # 高质量
    python3 image_decopyrighter.py batch <img1> <img2> --style illustration   # 批量
    python3 image_decopyrighter.py describe <image_path>                      # 仅提取 prompt
    python3 image_decopyrighter.py generate "<prompt>" out.png                # 仅生成

Environment:
    GEMINI_API_KEY     — describe + gemini 生成后端（默认，全程只需这一个）
    TOGETHER_API_KEY   — together 后端需要
    OPENAI_API_KEY     — dalle 后端需要
"""

import argparse
import base64
import json
import os
import subprocess
import sys
from pathlib import Path


# ── HTTP via curl (avoids macOS SSL cert issues) ─────────────────

def _curl_json(url: str, headers: dict, data: dict | None = None, timeout: int = 120) -> dict:
    """POST/GET JSON via curl subprocess. Uses temp file for large payloads."""
    import tempfile as _tf
    cmd = ["curl", "-sL", "--max-time", str(timeout)]
    for k, v in headers.items():
        cmd += ["-H", f"{k}: {v}"]

    tmpfile = None
    if data is not None:
        payload = json.dumps(data)
        if len(payload) > 100_000:
            # Large payload (e.g. base64 images) — write to temp file
            tmp = _tf.NamedTemporaryFile(mode="w", suffix=".json", delete=False)
            tmp.write(payload)
            tmp.close()
            tmpfile = tmp.name
            cmd += ["-X", "POST", "-d", f"@{tmpfile}"]
        else:
            cmd += ["-X", "POST", "-d", payload]
    cmd.append(url)

    try:
        result = subprocess.run(cmd, capture_output=True, text=True)
    finally:
        if tmpfile:
            os.unlink(tmpfile)

    if result.returncode != 0:
        print(f"ERROR: curl failed: {result.stderr}", file=sys.stderr)
        sys.exit(1)

    try:
        return json.loads(result.stdout)
    except json.JSONDecodeError:
        print(f"ERROR: Invalid JSON response: {result.stdout[:200]}", file=sys.stderr)
        sys.exit(1)


# ── Helpers ──────────────────────────────────────────────────────

def _get_mime_type(path: str) -> str:
    ext = Path(path).suffix.lower()
    return {
        ".png": "image/png", ".jpg": "image/jpeg", ".jpeg": "image/jpeg",
        ".gif": "image/gif", ".webp": "image/webp",
    }.get(ext, "image/png")


def _encode_image(path: str) -> str:
    with open(path, "rb") as f:
        return base64.standard_b64encode(f.read()).decode("utf-8")


def _size_to_aspect_ratio(size: str) -> str:
    """Convert WxH size string to aspect ratio string for Imagen API."""
    ratios = {"1024x1024": "1:1", "1792x1024": "16:9", "1024x1792": "9:16"}
    return ratios.get(size, "1:1")


# ── Step 1: Describe (Gemini Flash Vision) ──────────────────────

def describe_image(image_path: str, style_hint: str = "") -> str:
    """Use Gemini 2.5 Flash Vision to extract a semantic description suitable for regeneration."""
    api_key = os.environ.get("GEMINI_API_KEY", "")
    if not api_key:
        print("ERROR: GEMINI_API_KEY not set", file=sys.stderr)
        sys.exit(1)

    mime = _get_mime_type(image_path)
    b64 = _encode_image(image_path)

    style_instruction = ""
    if style_hint:
        style_instruction = f"\n- Apply this style direction: {style_hint}"

    prompt_text = f"""You are an image description expert helping to recreate this image in a copyright-safe way.

Analyze this image and produce an image generation prompt that will recreate its SEMANTIC MEANING while ensuring the output looks visually DIFFERENT enough to avoid any copyright claim.

Rules:
- Describe the subject, composition, colors, mood, and context accurately
- Do NOT include any brand names, logos, specific athlete names, or copyrighted characters
- Explicitly state "no brand logos or text" in the prompt
- For product images: describe the type of product generically (e.g., "a running shoe" not "Nike Air Max")
- For people: describe their appearance/pose generically, never identify specific individuals
- For trading cards / collectibles: describe the card layout, sport, and visual style generically
- Add subtle style variations (e.g., slightly different color palette, illustration style, or angle)
- The prompt should be a single paragraph, 50-150 words, in English
- Output ONLY the prompt text, nothing else{style_instruction}"""

    data = {
        "contents": [{"parts": [
            {"inlineData": {"mimeType": mime, "data": b64}},
            {"text": prompt_text},
        ]}],
    }

    resp = _curl_json(
        f"https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash:generateContent?key={api_key}",
        headers={"Content-Type": "application/json"},
        data=data,
        timeout=60,
    )

    if "error" in resp:
        print(f"ERROR: Gemini API: {resp['error'].get('message', resp['error'])}", file=sys.stderr)
        sys.exit(1)

    return resp["candidates"][0]["content"]["parts"][0]["text"].strip()


# ── Step 2: Generate — Backend: Gemini / Imagen 4.0 (FREE tier) ─

def generate_gemini(prompt: str, output_path: str, size: str = "1024x1024") -> str:
    """Use Google Imagen 4.0 via Gemini API. Free tier: 50 images/day."""
    api_key = os.environ.get("GEMINI_API_KEY", "")
    if not api_key:
        print("ERROR: GEMINI_API_KEY not set", file=sys.stderr)
        sys.exit(1)

    aspect_ratio = _size_to_aspect_ratio(size)

    resp = _curl_json(
        f"https://generativelanguage.googleapis.com/v1beta/models/imagen-4.0-generate-001:predict?key={api_key}",
        headers={"Content-Type": "application/json"},
        data={
            "instances": [{"prompt": prompt}],
            "parameters": {"sampleCount": 1, "aspectRatio": aspect_ratio},
        },
        timeout=90,
    )

    if "error" in resp:
        print(f"ERROR: Gemini API: {resp['error'].get('message', resp['error'])}", file=sys.stderr)
        sys.exit(1)

    b64_data = resp["predictions"][0]["bytesBase64Encoded"]
    img_bytes = base64.standard_b64decode(b64_data)
    Path(output_path).parent.mkdir(parents=True, exist_ok=True)
    with open(output_path, "wb") as f:
        f.write(img_bytes)

    return prompt


# ── Step 2: Generate — Backend: Together AI ($0.003/image) ──────

def generate_together(prompt: str, output_path: str, width: int = 1024, height: int = 1024) -> str:
    """Use Together AI (Flux Schnell) to generate an image. ~$0.003/image."""
    api_key = os.environ.get("TOGETHER_API_KEY", "")
    if not api_key:
        print("ERROR: TOGETHER_API_KEY not set", file=sys.stderr)
        sys.exit(1)

    resp = _curl_json(
        "https://api.together.xyz/v1/images/generations",
        headers={
            "Content-Type": "application/json",
            "Authorization": f"Bearer {api_key}",
        },
        data={
            "model": "black-forest-labs/FLUX.1-schnell-Free",
            "prompt": prompt,
            "width": width,
            "height": height,
            "n": 1,
            "response_format": "b64_json",
        },
        timeout=120,
    )

    if "error" in resp:
        print(f"ERROR: Together API: {resp['error']}", file=sys.stderr)
        sys.exit(1)

    b64_data = resp["data"][0]["b64_json"]
    img_bytes = base64.standard_b64decode(b64_data)
    Path(output_path).parent.mkdir(parents=True, exist_ok=True)
    with open(output_path, "wb") as f:
        f.write(img_bytes)

    return prompt


# ── Step 2: Generate — Backend: DALL-E 3 ($0.04/image) ──────────

def generate_dalle(prompt: str, output_path: str, size: str = "1024x1024", style: str = "natural") -> str:
    """Use DALL-E 3 to generate an image. ~$0.04/image."""
    api_key = os.environ.get("OPENAI_API_KEY", "")
    if not api_key:
        print("ERROR: OPENAI_API_KEY not set (required for dalle backend)", file=sys.stderr)
        sys.exit(1)

    resp = _curl_json(
        "https://api.openai.com/v1/images/generations",
        headers={
            "Content-Type": "application/json",
            "Authorization": f"Bearer {api_key}",
        },
        data={
            "model": "dall-e-3",
            "prompt": prompt,
            "n": 1,
            "size": size,
            "style": style,
            "response_format": "b64_json",
        },
        timeout=120,
    )

    if "error" in resp:
        print(f"ERROR: OpenAI API: {resp['error']}", file=sys.stderr)
        sys.exit(1)

    b64_data = resp["data"][0]["b64_json"]
    revised_prompt = resp["data"][0].get("revised_prompt", "")
    img_bytes = base64.standard_b64decode(b64_data)
    Path(output_path).parent.mkdir(parents=True, exist_ok=True)
    with open(output_path, "wb") as f:
        f.write(img_bytes)

    return revised_prompt


# ── Dispatch ─────────────────────────────────────────────────────

BACKENDS = {
    "gemini":   {"cost": "免费(50张/天)", "key_env": "GEMINI_API_KEY"},
    "together": {"cost": "$0.003/张",     "key_env": "TOGETHER_API_KEY"},
    "dalle":    {"cost": "$0.04/张",      "key_env": "OPENAI_API_KEY"},
}

DEFAULT_BACKEND = "gemini"


def generate_image(prompt: str, output_path: str, backend: str = DEFAULT_BACKEND,
                   size: str = "1024x1024", style: str = "natural") -> str:
    """Route to the selected backend for image generation."""
    if backend == "gemini":
        return generate_gemini(prompt, output_path, size=size)
    elif backend == "together":
        w, h = (int(x) for x in size.split("x"))
        return generate_together(prompt, output_path, width=w, height=h)
    elif backend == "dalle":
        return generate_dalle(prompt, output_path, size=size, style=style)
    else:
        print(f"ERROR: Unknown backend '{backend}'. Available: {', '.join(BACKENDS.keys())}", file=sys.stderr)
        sys.exit(1)


# ── Auto pipeline ────────────────────────────────────────────────

def auto_process(image_path: str, output_dir: str = "", style: str = "",
                 size: str = "1024x1024", backend: str = DEFAULT_BACKEND) -> dict:
    """Full pipeline: describe → generate → return result metadata."""
    image_path = os.path.abspath(image_path)
    if not os.path.exists(image_path):
        print(f"ERROR: Image not found: {image_path}", file=sys.stderr)
        sys.exit(1)

    stem = Path(image_path).stem
    if not output_dir:
        output_dir = str(Path(image_path).parent)

    output_path = os.path.join(output_dir, f"{stem}_decopyrighted.png")

    info = BACKENDS.get(backend, {})
    label = f"{backend} ({info.get('cost', '?')})"
    print(f"[1/2] Describing image: {image_path}", file=sys.stderr)
    prompt = describe_image(image_path, style_hint=style)
    print(f"  Prompt: {prompt[:100]}...", file=sys.stderr)

    print(f"[2/2] Generating via {label}...", file=sys.stderr)
    revised = generate_image(prompt, output_path, backend=backend, size=size)
    print(f"  Output: {output_path}", file=sys.stderr)

    result = {
        "source": image_path,
        "output": output_path,
        "prompt": prompt,
        "revised_prompt": revised,
        "backend": backend,
        "size": size,
        "style": style or "default",
    }

    meta_path = os.path.join(output_dir, f"{stem}_decopyrighted.meta.json")
    with open(meta_path, "w") as f:
        json.dump(result, f, indent=2, ensure_ascii=False)

    return result


# ── CLI ──────────────────────────────────────────────────────────

def main():
    backends_help = ", ".join(f"{k} ({v['cost']})" for k, v in BACKENDS.items())
    parser = argparse.ArgumentParser(
        description="图片去版权化工具",
        epilog=f"Backends: {backends_help}",
    )
    sub = parser.add_subparsers(dest="command")

    # describe
    p_desc = sub.add_parser("describe", help="提取图片语义描述（输出生成 prompt）")
    p_desc.add_argument("image", help="图片路径")
    p_desc.add_argument("--style", default="", help="风格提示（如：illustration, watercolor）")

    # generate
    p_gen = sub.add_parser("generate", help="从 prompt 生成新图片")
    p_gen.add_argument("prompt", help="图片描述 prompt")
    p_gen.add_argument("output", help="输出图片路径")
    p_gen.add_argument("--backend", default=DEFAULT_BACKEND, choices=list(BACKENDS.keys()))
    p_gen.add_argument("--size", default="1024x1024", choices=["1024x1024", "1792x1024", "1024x1792"])
    p_gen.add_argument("--style", default="natural", choices=["natural", "vivid"])

    # auto
    p_auto = sub.add_parser("auto", help="一键：描述 + 生成")
    p_auto.add_argument("image", help="图片路径")
    p_auto.add_argument("--output", default="", help="输出目录（默认同源文件目录）")
    p_auto.add_argument("--backend", default=DEFAULT_BACKEND, choices=list(BACKENDS.keys()))
    p_auto.add_argument("--style", default="", help="风格提示")
    p_auto.add_argument("--size", default="1024x1024", choices=["1024x1024", "1792x1024", "1024x1792"])

    # batch
    p_batch = sub.add_parser("batch", help="批量处理多张图片")
    p_batch.add_argument("images", nargs="+", help="图片路径列表")
    p_batch.add_argument("--output", default="", help="输出目录")
    p_batch.add_argument("--backend", default=DEFAULT_BACKEND, choices=list(BACKENDS.keys()))
    p_batch.add_argument("--style", default="", help="风格提示")
    p_batch.add_argument("--size", default="1024x1024", choices=["1024x1024", "1792x1024", "1024x1792"])

    args = parser.parse_args()

    if args.command == "describe":
        prompt = describe_image(args.image, style_hint=args.style)
        print(prompt)

    elif args.command == "generate":
        revised = generate_image(args.prompt, args.output, backend=args.backend,
                                 size=args.size, style=args.style)
        print(json.dumps({"output": args.output, "revised_prompt": revised}, indent=2))

    elif args.command == "auto":
        result = auto_process(args.image, output_dir=args.output, style=args.style,
                              size=args.size, backend=args.backend)
        print(json.dumps(result, indent=2, ensure_ascii=False))

    elif args.command == "batch":
        results = []
        for img in args.images:
            try:
                r = auto_process(img, output_dir=args.output, style=args.style,
                                 size=args.size, backend=args.backend)
                results.append(r)
            except SystemExit:
                results.append({"source": img, "error": "failed"})
                continue
        print(json.dumps(results, indent=2, ensure_ascii=False))

    else:
        parser.print_help()
        sys.exit(1)


if __name__ == "__main__":
    main()
