#!/bin/bash
set -e

APP_ROOT="/var/apps/chatmock-fnos"
COMPOSE_FILE="${APP_ROOT}/target/docker/docker-compose.yaml"
export TRIM_PKGVAR="${TRIM_PKGVAR:-${APP_ROOT}/var}"

mkdir -p "${TRIM_PKGVAR}/data"

echo "正在启动 ChatMock OAuth 登录流程……"
echo "请打开终端显示的授权网址，并输入设备代码。"
echo

docker compose \
  --project-name chatmock-fnos \
  --file "$COMPOSE_FILE" \
  run --rm chatmock-login

echo
echo "登录成功，正在重启 ChatMock API 服务……"
docker restart chatmock-fnos >/dev/null
echo "完成。API 地址：http://<飞牛IP>:8000/v1"
