#!/bin/bash
set +m

# ═══════════════════════════════════════════════════
#  SXB Broadcast — Stable & Error-Proof (Final)
# ═══════════════════════════════════════════════════

STREAMER="SXB"
LOGO_URL="https://cdn.phototourl.com/anon/2026-11-20-b5a92a6a-471c-47a5-9a81-af43c13d5d7d.png"
ACCOUNT_NAME="Slayer_RT"
BG_IMAGE_URL="https://cdn.phototourl.com/anon/2026-11-20-62f2e940-ef2b-47e8-bc8e-c7b7dfe3f7b8.jpg"

# ── إعدادات الصوت الأول ──
CLIP1_URL="https://www.image2url.com/r2/default/audio/1794504710389-f7679c92-16cb-475d-9cd8-c6e9796dbd69.mp3"
CLIP1_INTERVAL=360
CLIP1_FIRST_DELAY=45
CLIP1_VOLUME=0.75

# ── إعدادات الصوت الثاني ──
CLIP2_URL="https://www.image2url.com/r2/default/audio/1795168796709-5e8c68dd-7a1c-4304-944f-512a0d926cc2.opus"
CLIP2_INTERVAL=1800
CLIP2_FIRST_DELAY=120
CLIP2_VOLUME=0.75

UA="Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36"
RESTREAM_KEY="${RESTREAM_KEY:-re_12215822_event7443f45547114c8aaf6a9153b0da6831}"
[ -z "$RESTREAM_KEY" ] && { echo "❌ مفتاح Restream فارغ"; exit 1; }
RESTREAM_URL="rtmp://live.restream.io/live/$RESTREAM_KEY"
WORKDIR="/tmp/standby_sxb"
mkdir -p "$WORKDIR"

# ── 1) تصميم التراكب الثابت ──
if [ ! -f "$WORKDIR/overlay.png" ]; then
    echo "🎨 تصميم التراكب الثابت..."
    cat > /tmp/make_overlay.py <<'PYEOF'
from PIL import Image, ImageDraw, ImageFont
import urllib.request, io, os
W, H = 1080, 1080
WORKDIR = os.environ["WORKDIR"]
LOGO_URL = os.environ["LOGO_URL"]
ACCOUNT = os.environ.get("ACCOUNT_NAME", "Slayer_RT")
FONT_AR = os.path.expanduser("~/.fonts/Cairo-var.ttf")
FONT_EN = os.path.expanduser("~/.fonts/Orbitron-var.ttf")
def load_font(path, size, weight=700):
    try:
        font = ImageFont.truetype(path, size)
        axes = font.get_variation_axes()
        if len(axes) == 1: font.set_variation_by_axes([weight])
        elif len(axes) == 2: font.set_variation_by_axes([0, weight])
        return font
    except: return ImageFont.load_default()
img = Image.new("RGBA", (W, H), (0,0,0,0))
d = ImageDraw.Draw(img)
x_brand = int(W * 0.03); y_brand = int(H * 0.03)
try:
    req = urllib.request.Request(LOGO_URL, headers={"User-Agent": "Mozilla/5.0"})
    logo = Image.open(io.BytesIO(urllib.request.urlopen(req, timeout=15).read())).convert("RGBA")
    lw = 80; lh = int(logo.height * (lw/logo.width))
    logo = logo.resize((lw, lh), Image.LANCZOS)
    img.alpha_composite(logo, (x_brand, y_brand))
    x_text = x_brand + lw + 15; y_text = y_brand + (lh // 2) - 20
except: 
    x_text = x_brand; y_text = y_brand
d.text((x_text, y_text), ACCOUNT, font=load_font(FONT_EN, 45, 900), fill=(255,255,255,255), anchor="lm")
badge_w, badge_h = 280, 60
x_badge = int(W * 0.50) - (badge_w // 2)
y_badge = int(H * 0.90) - (badge_h // 2)
d.rounded_rectangle([(x_badge, y_badge), (x_badge + badge_w, y_badge + badge_h)], radius=30, fill=(0, 0, 0, 200), outline=(255,255,255,100), width=2)
d.text((x_badge + badge_w//2 + 15, y_badge + badge_h//2), "صلي على النبي ", font=load_font(FONT_AR, 32, 900), fill=(255,255,255,255), anchor="mm", direction="rtl")
d.ellipse([(x_badge + 20, y_badge + 20), (x_badge + 40, y_badge + 40)], fill=(255,255,255,255))
img.save(f"{WORKDIR}/overlay.png")
PYEOF
    LOGO_URL="$LOGO_URL" ACCOUNT_NAME="$ACCOUNT_NAME" WORKDIR="$WORKDIR" python3 /tmp/make_overlay.py
fi

# ── 2) تحميل صورة الخلفية ──
if [ -n "$BG_IMAGE_URL" ] && [ ! -f "$WORKDIR/bg_custom.jpg" ]; then
    echo "🖼️ تحميل صورة الخلفية..."
    curl -sL --max-time 30 -A "Mozilla/5.0" "$BG_IMAGE_URL" -o "$WORKDIR/bg_custom.jpg"
    ffprobe -v error -select_streams v:0 -show_entries stream=width -of csv=p=0 "$WORKDIR/bg_custom.jpg" >/dev/null 2>&1 || rm -f "$WORKDIR/bg_custom.jpg"
fi

# ── 3) شاشة الانتظار ──
if [ ! -f "$WORKDIR/standby.ts" ]; then
    echo "🎨 تصميم شاشة الانتظار..."
    cat > /tmp/make_ui.py <<'PYEOF'
from PIL import Image, ImageDraw, ImageFont
import os
W, H = 1080, 1080
WORKDIR = os.environ["WORKDIR"]
FONT_AR = os.path.expanduser("~/.fonts/Cairo-var.ttf")
bg = Image.new("RGB", (W, H), (0, 2, 31))
d = ImageDraw.Draw(bg)
try:
    font = ImageFont.truetype(FONT_AR, 60)
    d.text((W//2, H//2), "جاري تجهيز البث...", font=font, fill=(255,255,255), anchor="mm")
except: pass
bg.save(f"{WORKDIR}/bg.png")
PYEOF
    WORKDIR="$WORKDIR" python3 /tmp/make_ui.py
    ffmpeg -y -hide_banner -loglevel warning -loop 1 -framerate 30 -i "$WORKDIR/bg.png" -f lavfi -i "anullsrc=r=44100:cl=stereo" -t 2 -c:v libx264 -preset ultrafast -pix_fmt yuv420p -g 60 -r 30 -c:a aac -b:a 128k -ar 44100 -ac 2 -shortest -f mpegts "$WORKDIR/standby.ts"
fi

# ── 4) بناء مسار الصوت الأول (مع فحص) ──
if [ ! -f "$WORKDIR/interval_audio_1.wav" ]; then
    echo "🎵 تحميل وبناء المسار الصوتي الأول..."
    curl -sL --max-time 60 -A "Mozilla/5.0" "$CLIP1_URL" -o "$WORKDIR/clip1_src"
    ffmpeg -y -hide_banner -loglevel error -i "$WORKDIR/clip1_src" -ar 44100 -ac 2 "$WORKDIR/clip1.wav" 2>/dev/null || true
    if [ -f "$WORKDIR/clip1.wav" ]; then
        CLIP1_DUR=$(ffprobe -v error -show_entries format=duration -of csv=p=0 "$WORKDIR/clip1.wav" 2>/dev/null | cut -d. -f1)
        CLIP1_DUR=${CLIP1_DUR:-10}
        LEAD_SIL=$CLIP1_FIRST_DELAY
        TAIL_SIL=$(( CLIP1_INTERVAL - LEAD_SIL - CLIP1_DUR ))
        [ "$TAIL_SIL" -lt 10 ] && TAIL_SIL=10
        ffmpeg -y -hide_banner -loglevel error -f lavfi -i "anullsrc=r=44100:cl=stereo" -t "$LEAD_SIL" -c:a pcm_s16le -ar 44100 -ac 2 "$WORKDIR/sil_lead1.wav"
        ffmpeg -y -hide_banner -loglevel error -f lavfi -i "anullsrc=r=44100:cl=stereo" -t "$TAIL_SIL" -c:a pcm_s16le -ar 44100 -ac 2 "$WORKDIR/sil_tail1.wav"
        ffmpeg -y -hide_banner -loglevel error -i "$WORKDIR/sil_lead1.wav" -i "$WORKDIR/clip1.wav" -i "$WORKDIR/sil_tail1.wav" -filter_complex "[0:a]aformat=sample_fmts=fltp:channel_layouts=stereo[a0];[1:a]aresample=44100,aformat=sample_fmts=fltp:channel_layouts=stereo[a1];[2:a]aformat=sample_fmts=fltp:channel_layouts=stereo[a2];[a0][a1][a2]concat=n=3:v=0:a=1[out]" -map "[out]" -c:a pcm_s16le -ar 44100 -ac 2 "$WORKDIR/interval_audio_1.wav"
    fi
fi

# ── 5) بناء مسار الصوت الثاني (مع فحص) ──
if [ ! -f "$WORKDIR/interval_audio_2.wav" ]; then
    echo "🎵 تحميل وبناء المسار الصوتي الثاني (OPUS)..."
    curl -sL --max-time 60 -A "Mozilla/5.0" "$CLIP2_URL" -o "$WORKDIR/clip2_src.opus"
    ffmpeg -y -hide_banner -loglevel error -i "$WORKDIR/clip2_src.opus" -vn -c:a pcm_s16le -ar 44100 -ac 2 "$WORKDIR/clip2.wav" 2>/dev/null || true
    if [ -f "$WORKDIR/clip2.wav" ]; then
        CLIP2_DUR=$(ffprobe -v error -show_entries format=duration -of csv=p=0 "$WORKDIR/clip2.wav" 2>/dev/null | cut -d. -f1)
        CLIP2_DUR=${CLIP2_DUR:-10}
        LEAD_SIL2=$CLIP2_FIRST_DELAY
        TAIL_SIL2=$(( CLIP2_INTERVAL - LEAD_SIL2 - CLIP2_DUR ))
        [ "$TAIL_SIL2" -lt 10 ] && TAIL_SIL2=10
        ffmpeg -y -hide_banner -loglevel error -f lavfi -i "anullsrc=r=44100:cl=stereo" -t "$LEAD_SIL2" -c:a pcm_s16le -ar 44100 -ac 2 "$WORKDIR/sil_lead2.wav"
        ffmpeg -y -hide_banner -loglevel error -f lavfi -i "anullsrc=r=44100:cl=stereo" -t "$TAIL_SIL2" -c:a pcm_s16le -ar 44100 -ac 2 "$WORKDIR/sil_tail2.wav"
        ffmpeg -y -hide_banner -loglevel error -i "$WORKDIR/sil_lead2.wav" -i "$WORKDIR/clip2.wav" -i "$WORKDIR/sil_tail2.wav" -filter_complex "[0:a]aformat=sample_fmts=fltp:channel_layouts=stereo[a0];[1:a]aresample=44100,aformat=sample_fmts=fltp:channel_layouts=stereo[a1];[2:a]aformat=sample_fmts=fltp:channel_layouts=stereo[a2];[a0][a1][a2]concat=n=3:v=0:a=1[out]" -map "[out]" -c:a pcm_s16le -ar 44100 -ac 2 "$WORKDIR/interval_audio_2.wav"
    else
        echo "⚠️ فشل تحويل الصوت الثاني (OPUS)، سيتم البث بدونه."
    fi
fi

# ── 6) تسليم/تسلّم ──
OLD_RUNS=$(gh run list --workflow="main.yml" --status=in_progress --json databaseId --jq '.[].databaseId' 2>/dev/null | awk -v m="$GITHUB_RUN_ID" '$1 != m')
if [ -n "$OLD_RUNS" ]; then
    for R in $OLD_RUNS; do timeout 10 gh run cancel "$R" 2>/dev/null || true; done
    sleep 8
fi

# ── 7) دالة البث المباشر ──
stream_live() {
    LIVE_URL=$(timeout 15 streamlink --hls-segment-queue-threshold=0 --http-header "User-Agent=$UA" "https://kick.com/$STREAMER" best --stream-url 2>/dev/null | grep -m1 "^http")
    [ -z "$LIVE_URL" ] && return 1

    echo "🔴 جاري البث (معالجة الصوت بشكل آمن)..."

    # بناء أوامر الإدخال ديناميكياً
    INPUT_ARGS=(-i "$LIVE_URL")
    AUDIO_FILTER=""
    BASE_INPUTS=1

    # إضافة الصوت الأول إذا كان موجوداً
    if [ -f "$WORKDIR/interval_audio_1.wav" ]; then
        INPUT_ARGS+=(-stream_loop -1 -i "$WORKDIR/interval_audio_1.wav")
        AUDIO_FILTER+="[0:a]aresample=44100,aformat=sample_fmts=fltp:channel_layouts=stereo[game];"
        AUDIO_FILTER+="[1:a]aresample=44100,aformat=sample_fmts=fltp:channel_layouts=stereo,volume=${CLIP1_VOLUME}[clip1];"
        AUDIO_FILTER+="[clip1]asplit=2[clip1_sc][clip1_mix];"
        AUDIO_FILTER+="[game][clip1_sc]sidechaincompress=threshold=0.04:ratio=8:attack=15:release=500[game_duck];"
        AUDIO_FILTER+="[game_duck][clip1_mix]amix=inputs=2:duration=first:dropout_transition=0:normalize=0[outa]"
        BASE_INPUTS=2
    else
        AUDIO_FILTER="[0:a]aresample=44100,aformat=sample_fmts=fltp:channel_layouts=stereo[outa]"
    fi

    # إضافة الصوت الثاني إذا كان موجوداً (يتم دمجه مع الفلتر الحالي)
    if [ -f "$WORKDIR/interval_audio_2.wav" ]; then
        INPUT_ARGS+=(-stream_loop -1 -i "$WORKDIR/interval_audio_2.wav")
        # هنا نضيف منطق دمج الصوت الثاني مع الفلتر الحالي (يتطلب إعادة بناء الفلتر)
        if [ $BASE_INPUTS -eq 2 ]; then
            # لدينا صوت أول وصوت ثاني
            AUDIO_FILTER="[0:a]aresample=44100,aformat=sample_fmts=fltp:channel_layouts=stereo[game];"
            AUDIO_FILTER+="[1:a]aresample=44100,aformat=sample_fmts=fltp:channel_layouts=stereo,volume=${CLIP1_VOLUME}[clip1];"
            AUDIO_FILTER+="[2:a]aresample=44100,aformat=sample_fmts=fltp:channel_layouts=stereo,volume=${CLIP2_VOLUME}[clip2];"
            AUDIO_FILTER+="[clip1]asplit=2[clip1_sc][clip1_mix];"
            AUDIO_FILTER+="[clip2]asplit=2[clip2_sc][clip2_mix];"
            AUDIO_FILTER+="[game][clip1_sc]sidechaincompress=threshold=0.04:ratio=8:attack=15:release=500[game_duck1];"
            AUDIO_FILTER+="[game_duck1][clip2_sc]sidechaincompress=threshold=0.04:ratio=8:attack=15:release=500[game_duck2];"
            AUDIO_FILTER+="[game_duck2][clip1_mix][clip2_mix]amix=inputs=3:duration=first:dropout_transition=0:normalize=0[outa]"
        else
            # لدينا صوت ثاني فقط (بدون صوت أول)
            AUDIO_FILTER="[0:a]aresample=44100,aformat=sample_fmts=fltp:channel_layouts=stereo[game];"
            AUDIO_FILTER+="[1:a]aresample=44100,aformat=sample_fmts=fltp:channel_layouts=stereo,volume=${CLIP2_VOLUME}[clip2];"
            AUDIO_FILTER+="[clip2]asplit=2[clip2_sc][clip2_mix];"
            AUDIO_FILTER+="[game][clip2_sc]sidechaincompress=threshold=0.04:ratio=8:attack=15:release=500[game_duck];"
            AUDIO_FILTER+="[game_duck][clip2_mix]amix=inputs=2:duration=first:dropout_transition=0:normalize=0[outa]"
        fi
        BASE_INPUTS=$((BASE_INPUTS + 1))
    fi

    # إضافة الخلفية والتراكب
    if [ -f "$WORKDIR/bg_custom.jpg" ]; then
        echo "🖼️ استخدام صورة الخلفية المخصصة..."
        INPUT_ARGS+=(-loop 1 -i "$WORKDIR/bg_custom.jpg")
        BG_INDEX=$BASE_INPUTS
        INPUT_ARGS+=(-i "$WORKDIR/overlay.png")
        OVERLAY_INDEX=$((BASE_INPUTS + 1))
        VIDEO_FILTER="[${BG_INDEX}:v]scale=1080:1080[bg];[0:v]scale=1080:-2[fg];[bg][fg]overlay=(W-w)/2:(H-h)/2[base];[base][${OVERLAY_INDEX}:v]overlay=0:0[outv]"
    else
        echo "🎨 استخدام الخلفية الكحلية الافتراضية..."
        INPUT_ARGS+=(-i "$WORKDIR/overlay.png")
        OVERLAY_INDEX=$BASE_INPUTS
        VIDEO_FILTER="[0:v]scale=1080:-2,pad=1080:1080:(ow-iw)/2:(oh-ih)/2:color=0x00021f[base];[base][${OVERLAY_INDEX}:v]overlay=0:0[outv]"
    fi

    ffmpeg -hide_banner -loglevel warning -stats -stats_period 60 -nostdin \
        -thread_queue_size 256 -fflags +genpts+discardcorrupt -err_detect +crccheck+bitstream+buffer \
        -reconnect 1 -reconnect_streamed 1 -reconnect_delay_max 5 \
        "${INPUT_ARGS[@]}" \
        -filter_complex "${VIDEO_FILTER};${AUDIO_FILTER}" \
        -map "[outv]" -map "[outa]" \
        -c:v libx264 -preset ultrafast -profile:v high -threads 2 \
        -b:v 5000k -maxrate 5000k -bufsize 10000k \
        -pix_fmt yuv420p -g 60 -r 30 \
        -c:a aac -b:a 160k -ar 44100 -ac 2 \
        -max_muxing_queue_size 512 -flvflags no_duration_filesize \
        -f flv "$RESTREAM_URL"
}

stream_standby() {
    echo "⏳ إرسال شاشة الانتظار..."
    ffmpeg -hide_banner -loglevel error -nostdin -re -stream_loop -1 -i "$WORKDIR/standby.ts" -c copy -f flv "$RESTREAM_URL"
}

# ── 8) الحلقة الرئيسية ──
echo "🚀 بدء المراقبة..."
while true; do
    stream_live
    EXIT_CODE=$?
    if [ $EXIT_CODE -ne 0 ]; then
        echo "⚠️ انقطع البث المباشر. تفعيل شاشة الانتظار..."
        stream_standby
    fi
    echo "⏳ إعادة الفحص بعد 5 ثوانٍ..."
    sleep 5
done
