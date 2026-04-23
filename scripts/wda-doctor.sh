#!/usr/bin/env bash
# wda-doctor.sh — 后台 tunnel 健康监控（防长会话 RSD 腐化）
#
# #IJDUAJ — go-ios userspace tunnel 长时间运行后 RSD 可能断连，
# 但进程仍存活。wda-start.sh (v0.59.1+) 的启动探活只覆盖启动时，
# 本脚本覆盖运行中途：每 INTERVAL 秒探活一次，失败则重启 tunnel。
#
# Usage:
#   wda-doctor.sh --udid XXXX [--interval 45] [--port 8100]   # 前台运行
#   wda-doctor.sh --udid XXXX &                               # 后台守护
#   wda-doctor.sh --stop --udid XXXX                          # 停止对应设备的 doctor
#   wda-doctor.sh --status                                    # 列出所有运行中的 doctor
#
# 多设备安全:
#   - 每 UDID 一个 doctor 实例，PID 文件 /tmp/wda-doctor-<UDID>.pid
#   - 重启 tunnel 通过全局锁 /tmp/wda-doctor.lock 串行化，避免惊群
#   - tunnel 是 per-machine 而非 per-device，重启会影响所有设备的 session

set -uo pipefail

# ------- Args -------
UDID=""
INTERVAL=45
WDA_PORT=8100
STOP_MODE=false
STATUS_MODE=false

while [[ $# -gt 0 ]]; do
    case "$1" in
        --udid) UDID="$2"; shift 2 ;;
        --interval) INTERVAL="$2"; shift 2 ;;
        --port) WDA_PORT="$2"; shift 2 ;;
        --stop) STOP_MODE=true; shift ;;
        --status) STATUS_MODE=true; shift ;;
        -h|--help)
            sed -n '2,16p' "$0" | sed 's/^# \?//'
            exit 0
            ;;
        *) echo "Unknown arg: $1" >&2; exit 1 ;;
    esac
done

# ------- Status mode -------
if $STATUS_MODE; then
    found=0
    for pidfile in /tmp/wda-doctor-*.pid; do
        [[ -f "$pidfile" ]] || continue
        pid=$(cat "$pidfile" 2>/dev/null || echo "")
        udid=$(basename "$pidfile" .pid | sed 's/^wda-doctor-//')
        if [[ -n "$pid" ]] && kill -0 "$pid" 2>/dev/null; then
            echo "RUNNING  udid=$udid  pid=$pid  log=/tmp/wda-doctor-$udid.log"
            found=$((found + 1))
        else
            echo "STALE    udid=$udid  (pid file 存在但进程已退出)"
            rm -f "$pidfile"
        fi
    done
    [[ $found -eq 0 ]] && echo "无运行中的 wda-doctor 实例"
    exit 0
fi

# ------- Stop mode -------
if $STOP_MODE; then
    if [[ -z "$UDID" ]]; then
        echo "--stop 需要 --udid" >&2
        exit 1
    fi
    PIDFILE="/tmp/wda-doctor-${UDID}.pid"
    if [[ -f "$PIDFILE" ]]; then
        pid=$(cat "$PIDFILE")
        if kill -0 "$pid" 2>/dev/null; then
            kill -TERM "$pid" 2>/dev/null || true
            echo "已停止 doctor (udid=$UDID, pid=$pid)"
        else
            echo "doctor 进程已退出 (udid=$UDID)"
        fi
        rm -f "$PIDFILE"
    else
        echo "未找到对应 doctor 实例 (udid=$UDID)"
    fi
    exit 0
fi

# ------- Run mode -------
if [[ -z "$UDID" ]]; then
    echo "--udid 必填" >&2
    exit 1
fi

PIDFILE="/tmp/wda-doctor-${UDID}.pid"
LOGFILE="/tmp/wda-doctor-${UDID}.log"
# mkdir-based lock works on macOS (no flock); staleness checked before takeover
LOCKDIR="/tmp/wda-doctor.lock.d"
LOCK_STALE_SEC=60

# 防止重复启动
if [[ -f "$PIDFILE" ]]; then
    old_pid=$(cat "$PIDFILE" 2>/dev/null || echo "")
    if [[ -n "$old_pid" ]] && kill -0 "$old_pid" 2>/dev/null; then
        echo "doctor 已在运行 (udid=$UDID, pid=$old_pid)"
        exit 0
    fi
    rm -f "$PIDFILE"
fi

echo $$ > "$PIDFILE"

cleanup() {
    # 只释放本进程持有的锁（owner pid 匹配才删）
    if [[ -f "$LOCKDIR/owner" ]]; then
        local owner_pid
        owner_pid=$(awk '{print $1}' "$LOCKDIR/owner" 2>/dev/null || echo "")
        if [[ "$owner_pid" == "$$" ]]; then
            rmdir "$LOCKDIR" 2>/dev/null || rm -rf "$LOCKDIR" 2>/dev/null || true
        fi
    fi
    rm -f "$PIDFILE"
    log_event "INFO" "doctor 退出"
    exit 0
}
trap cleanup INT TERM EXIT

log_event() {
    local level="$1"; shift
    local ts
    ts=$(date '+%Y-%m-%d %H:%M:%S')
    echo "[$ts] [$level] [udid=${UDID:0:8}..] $*" >> "$LOGFILE"
}

notify_mac() {
    # 仅 Mac 桌面通知，静默失败
    local title="$1"
    local msg="$2"
    command -v osascript >/dev/null 2>&1 || return 0
    osascript -e "display notification \"$msg\" with title \"$title\"" 2>/dev/null || true
}

# RSD 探活：用 ios tunnel ls 列出 tunnel daemon 注册的 RSD 地址，
# 输出 JSON 必须含本 UDID 才算健康。
#   - healthy: <1s 返回 exit 0，JSON 含 UDID
#   - frozen / RSD 断连: 5s 后 exit 1（go-ios 内部 context deadline）
# 为什么不用 ios info：ios info 部分字段走 lockdown 不需要 RSD，
# 即使 tunnel 腐化也可能返回成功，无法检测。
# 为什么不加外部 timeout：ios tunnel ls 自带 5s 超时，够用；
# bash 的 "$(cmd &)" 模式因 $() 会等所有后代进程而无效（已踩坑）。
probe_rsd() {
    local out
    out=$(ios tunnel ls 2>&1)
    [[ $? -ne 0 ]] && return 1
    printf '%s' "$out" | python3 -c "
import sys, json, re
txt = sys.stdin.read()
m = re.search(r'\[.*\]', txt, re.DOTALL)
if not m: sys.exit(1)
try:
    arr = json.loads(m.group(0))
except Exception:
    sys.exit(1)
udids = [x.get('udid', '') for x in arr if isinstance(x, dict)]
sys.exit(0 if '$UDID' in udids else 1)
" 2>/dev/null
}

# 获取 mkdir 锁（atomic on POSIX，兼容 macOS）
# 成功返回 0，超时返回 1。若锁目录 stale（> LOCK_STALE_SEC）则接管。
acquire_lock() {
    local timeout_sec="${1:-30}"
    local waited=0
    local stale_cleared=false
    while ! mkdir "$LOCKDIR" 2>/dev/null; do
        # 检查锁是否 stale
        if [[ -d "$LOCKDIR" ]]; then
            local lock_age
            # stat -f %m on macOS, stat -c %Y on Linux — 两个都试
            lock_age=$(($(date +%s) - $(stat -f %m "$LOCKDIR" 2>/dev/null || stat -c %Y "$LOCKDIR" 2>/dev/null || echo $(date +%s))))
            if [[ $lock_age -gt $LOCK_STALE_SEC ]]; then
                # 防止重复日志刷屏：stale 只清理一次
                if ! $stale_cleared; then
                    log_event "WARN" "检测到 stale 锁（${lock_age}s），接管"
                    stale_cleared=true
                fi
                # 锁目录里有 owner 文件——必须 rm -rf 而非 rmdir
                rm -rf "$LOCKDIR" 2>/dev/null || true
                continue
            fi
        fi
        if [[ $waited -ge $timeout_sec ]]; then
            return 1
        fi
        sleep 1
        waited=$((waited + 1))
    done
    # 记录持锁者信息供 stale 排查
    echo "$$ $(date +%s)" > "$LOCKDIR/owner" 2>/dev/null || true
    return 0
}

release_lock() {
    rmdir "$LOCKDIR" 2>/dev/null || rm -rf "$LOCKDIR" 2>/dev/null || true
}

# 重启 tunnel + forward（持全局锁，避免多 doctor 同时重启）
restart_tunnel() {
    log_event "WARN" "RSD 探活失败，尝试获取锁重启 tunnel"
    if ! acquire_lock 30; then
        log_event "ERROR" "获取锁超时（30s），跳过本次重启"
        return 1
    fi

    # 持锁后再探活一次——可能其他 doctor 已恢复
    if probe_rsd; then
        log_event "INFO" "持锁后 RSD 已恢复（由其他 doctor 处理），跳过重启"
        release_lock
        return 0
    fi

    # 用 SIGKILL（-9）而非默认 SIGTERM——腐化 tunnel 可能卡在系统调用或
    # STOP 状态，TERM 信号可能被吞或排队不处理。KILL 保证立即结束。
    pkill -KILL -f "ios tunnel start" 2>/dev/null || true
    pkill -KILL -f "ios forward" 2>/dev/null || true
    sleep 2
    ios tunnel start --userspace &>/dev/null &
    local tunnel_pid=$!

    # 轮询 RSD 就绪，最多 30s（probe_rsd 本身最多 5s/次，所以 ~6 次尝试）
    local recovered=false
    for _ in $(seq 1 30); do
        sleep 1
        if probe_rsd; then
            log_event "INFO" "tunnel 重启成功 (tunnel_pid=$tunnel_pid)"
            ios forward "$WDA_PORT" "$WDA_PORT" --udid="$UDID" &>/dev/null &
            notify_mac "WDA Doctor" "tunnel 已自动恢复 (udid=${UDID:0:8}..)"
            recovered=true
            break
        fi
    done

    release_lock

    if $recovered; then
        return 0
    fi
    log_event "ERROR" "tunnel 重启后 RSD 仍不可达（30s 超时）"
    notify_mac "WDA Doctor" "tunnel 恢复失败，请手动检查 (udid=${UDID:0:8}..)"
    return 1
}

# ------- Main loop -------
log_event "INFO" "doctor 启动，interval=${INTERVAL}s, port=${WDA_PORT}"

consecutive_failures=0
while true; do
    # 如果完全没有 tunnel 进程，退出（用户显式清理了，doctor 不应擅自拉起）
    if ! pgrep -f "ios tunnel" >/dev/null 2>&1; then
        log_event "INFO" "无 ios tunnel 进程，doctor 退出"
        exit 0
    fi

    if probe_rsd; then
        if [[ $consecutive_failures -gt 0 ]]; then
            log_event "INFO" "RSD 恢复健康（此前失败 $consecutive_failures 次）"
            consecutive_failures=0
        fi
    else
        consecutive_failures=$((consecutive_failures + 1))
        log_event "WARN" "RSD 探活失败 ($consecutive_failures 次)"
        # 连续 2 次失败才重启，避免瞬时网络抖动误触发
        if [[ $consecutive_failures -ge 2 ]]; then
            if restart_tunnel; then
                consecutive_failures=0
            fi
        fi
    fi

    sleep "$INTERVAL"
done
