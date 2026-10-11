#!/bin/sh
# 检查并自动安装 python3
if ! command -v python3 >/dev/null 2>&1; then
    echo "正在安装 Python3..."
    apk update && apk add python3
fi

# 下载最新 manager.py 并运行
echo "正在启动 WebSSH 管理面板..."
curl -sSL https://raw.githubusercontent.com/lixianus/ssh-lianjie/main/manager.py -o manager.py
python3 manager.py