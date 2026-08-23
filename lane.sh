#!/usr/bin/env bash
#
# lane.sh — สร้าง/ลบ "เลน" สำหรับให้ agent หลายตัวทำงานขนานกันบน repo เดียว
#
# หนึ่งเลน = git worktree ของตัวเอง + สาขาของตัวเอง + (ถ้าตั้งค่าไว้) ฐานข้อมูลของตัวเอง
# เจ้าของห้องเป็นคนรวมงานทีละเลนเอง · เลนไม่ merge และไม่ push
#
# ตั้งค่าด้วย environment variable (มีค่าปริยายทั้งหมด ยกเว้น LANE_REPO):
#   LANE_REPO          ราก repo (ต้องตั้ง)
#   LANE_DIR           ที่วาง worktree              ปริยาย $LANE_REPO/.worktrees
#   LANE_SETUP         คำสั่งติดตั้ง                 ปริยาย "pnpm install --frozen-lockfile"
#   LANE_ENV_FILES     ไฟล์ env ที่ต้องก๊อปเข้าเลน (คั่นด้วยช่องว่าง · path สัมพัทธ์กับ repo)
#   LANE_DB_KIND       postgres | none              ปริยาย none
#   LANE_DB_CONTAINER  ชื่อ container ของ postgres
#   LANE_DB_USER       ผู้ใช้ postgres               ปริยาย postgres
#   LANE_DB_BASE       ชื่อฐานตั้งต้นที่จะถูกแทนในไฟล์ env  เช่น myapp_dev
#   LANE_DB_DEPLOY     คำสั่งลงสคีมาให้ฐานของเลน    เช่น "pnpm --filter api db:deploy"
#   LANE_POST          คำสั่งท้ายสุด (build shared package ฯลฯ)
#
# ใช้:
#   lane.sh up   <ชื่อเลน> <สาขาฐาน>   -> พิมพ์ path ของ worktree
#   lane.sh down <ชื่อเลน>
#   lane.sh list
#
set -euo pipefail

REPO="${LANE_REPO:?ต้องตั้ง LANE_REPO ให้ชี้ไปที่รากของ repo}"
DIR="${LANE_DIR:-$REPO/.worktrees}"
SETUP="${LANE_SETUP:-pnpm install --frozen-lockfile}"
DB_KIND="${LANE_DB_KIND:-none}"
DB_USER="${LANE_DB_USER:-postgres}"

CMD="${1:?up|down|list}"
LANE="${2:-}"
BASE="${3:-}"
WT="$DIR/$LANE"
DB="$(echo "lane_${LANE}" | tr '-' '_')"

db() {
  docker exec "${LANE_DB_CONTAINER:?ต้องตั้ง LANE_DB_CONTAINER}" \
    psql -U "$DB_USER" -d postgres "$@" >/dev/null 2>&1
}

case "$CMD" in
  up)
    [ -n "$BASE" ] || { echo "ต้องบอกสาขาฐาน: lane.sh up <ชื่อเลน> <สาขาฐาน>" >&2; exit 1; }
    mkdir -p "$DIR"
    git -C "$REPO" worktree add -b "wt/$LANE" "$WT" "$BASE" >/dev/null

    # ไฟล์ env ไม่ได้อยู่ใน git — worktree ใหม่จึงไม่มี ต้องก๊อปเข้าไปเอง
    # ถ้าเลนมีฐานของตัวเอง ให้แทนชื่อฐานในไฟล์ไปด้วยในจังหวะเดียวกัน
    for f in ${LANE_ENV_FILES:-}; do
      [ -f "$REPO/$f" ] || continue
      mkdir -p "$(dirname "$WT/$f")"
      if [ "$DB_KIND" = postgres ] && [ -n "${LANE_DB_BASE:-}" ]; then
        sed "s#/${LANE_DB_BASE}#/${DB}#g" "$REPO/$f" > "$WT/$f"
      else
        cp "$REPO/$f" "$WT/$f"
      fi
    done

    if [ "$DB_KIND" = postgres ]; then
      db -c "DROP DATABASE IF EXISTS $DB"
      db -c "CREATE DATABASE $DB OWNER $DB_USER"
    fi

    (cd "$WT" && eval "$SETUP" >/dev/null 2>&1)
    [ -n "${LANE_POST:-}" ] && (cd "$WT" && eval "$LANE_POST" >/dev/null 2>&1)
    [ -n "${LANE_DB_DEPLOY:-}" ] && (cd "$WT" && eval "$LANE_DB_DEPLOY" >/dev/null 2>&1)
    echo "$WT"
    ;;

  down)
    git -C "$REPO" worktree remove --force "$WT" 2>/dev/null || rm -rf "$WT"
    git -C "$REPO" worktree prune
    git -C "$REPO" branch -D "wt/$LANE" 2>/dev/null || true
    if [ "$DB_KIND" = postgres ]; then
      # ตัดการเชื่อมต่อที่ค้างก่อน ไม่งั้น DROP DATABASE ล้มเงียบแล้วฐานขยะสะสมข้ามรอบ
      db -c "SELECT pg_terminate_backend(pid) FROM pg_stat_activity WHERE datname='$DB'"
      db -c "DROP DATABASE IF EXISTS $DB"
    fi
    ;;

  list) git -C "$REPO" worktree list ;;
  *) echo "ใช้: lane.sh up|down|list" >&2; exit 1 ;;
esac
