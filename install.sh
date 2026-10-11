#!/bin/sh

GREEN="\033[32m"
RED="\033[31m"
YELLOW="\033[33m"
CYAN="\033[36m"
NC="\033[0m"

CONFIG_FILE="/etc/webssh_config.env"

# 1. 检查 root 权限
if [ "$(id -u)" -ne 0 ]; then
  echo -e "${RED}错误：请使用 root 权限运行此脚本！${NC}"
  exit 1
fi

# 显示主菜单
show_menu() {
    clear
    echo -e "${CYAN}============================================${NC}"
    echo -e "${CYAN}   轻量多架构 WebSSH & 隧道一键管理面板      ${NC}"
    echo -e "${CYAN}============================================${NC}"
    echo -e "${GREEN} 1. 一键安装 / 更新 WebSSH 服务${NC}"
    echo -e "${GREEN} 2. 查看服务器 IP、端口、域名及隧道 Token${NC}"
    echo -e "${GREEN} 3. 配置 / 修改网页访问账号密码${NC}"
    echo -e "${GREEN} 4. 彻底卸载 WebSSH 及清理所有文件${NC}"
    echo -e "${RED} 0. 退出脚本${NC}"
    echo -e "${CYAN}============================================${NC}"
    printf "请选择操作 [0-4]: "
    read choice < /dev/tty
}

# 1. 安装逻辑
install_webssh() {
    echo -e "${GREEN}正在检测系统架构...${NC}"
    ARCH=$(uname -m)
    if [ "$ARCH" = "x86_64" ]; then
        GOTTY_ARCH="linux_amd64"
        CF_ARCH="amd64"
    elif [ "$ARCH" = "aarch64" ] || [ "$ARCH" = "arm64" ]; then
        GOTTY_ARCH="linux_arm64"
        CF_ARCH="arm64"
    else
        echo -e "${RED}暂不支持的架构: $ARCH${NC}"
        return
    fi

    printf "请输入 WebSSH 运行端口 [默认 12345]: "
    read PORT < /dev/tty
    PORT=${PORT:-12345}

    printf "请输入 Cloudflare Tunnel 域名 (如 ssh.example.com): "
    read DOMAIN < /dev/tty

    printf "请输入 Cloudflare Tunnel Token: "
    read CF_TOKEN < /dev/tty

    if [ -z "$CF_TOKEN" ] || [ -z "$DOMAIN" ]; then
        echo -e "${RED}错误：域名和 Token 不能为空！${NC}"
        printf "按回车键继续..."
        read -r _ < /dev/tty
        return
    fi

    echo "PORT=$PORT" > "$CONFIG_FILE"
    echo "DOMAIN=$DOMAIN" >> "$CONFIG_FILE"
    echo "CF_TOKEN=$CF_TOKEN" >> "$CONFIG_FILE"

    echo -e "${GREEN}正在下载 Gotty 核心组件...${NC}"
    VERSION="v1.5.0"
    wget -O gotty.tar.gz "https://github.com/sorenisanerd/gotty/releases/download/${VERSION}/gotty_${VERSION}_${GOTTY_ARCH}.tar.gz" || \
    curl -sSL -o gotty.tar.gz "https://github.com/sorenisanerd/gotty/releases/download/${VERSION}/gotty_${VERSION}_${GOTTY_ARCH}.tar.gz"

    tar -zxvf gotty.tar.gz
    chmod +x gotty
    mv gotty /usr/local/bin/
    rm -f gotty.tar.gz LICENSE README.md

    echo -e "${GREEN}正在配置 Cloudflare Tunnel...${NC}"
    if [ ! -f /usr/local/bin/cloudflared ]; then
        wget -O /usr/local/bin/cloudflared "https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-${CF_ARCH}" || \
        curl -sSL -o /usr/local/bin/cloudflared "https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-${CF_ARCH}"
        chmod +x /usr/local/bin/cloudflared
    fi

    pkill -f gotty 2>/dev/null
    pkill -f cloudflared 2>/dev/null

    nohup gotty --port "$PORT" --address 127.0.0.1 -w --permit-arguments /bin/sh > /var/log/webssh.log 2>&1 &
    nohup cloudflared tunnel run --token "$CF_TOKEN" > /var/log/cloudflared.log 2>&1 &

    echo -e "${GREEN}============================================${NC}"
    echo -e "${GREEN}  安装成功并已拉起服务！${NC}"
    echo -e "${GREEN}  外网访问地址: https://$DOMAIN${NC}"
    echo -e "${GREEN}============================================${NC}"
    printf "按回车键继续..."
    read -r _ < /dev/tty
}

# 2. 查看状态
check_status() {
    if [ ! -f "$CONFIG_FILE" ]; then
        echo -e "${RED}未检测到安装配置，请先执行安装！${NC}"
        printf "按回车键继续..."
        read -r _ < /dev/tty
        return
    fi
    . "$CONFIG_FILE"
    
    PUB_IP=$(curl -s https://api.ipify.org || echo "获取失败")

    echo -e "${CYAN}================ 信息面板 ================${NC}"
    echo -e "服务器公网 IP : ${YELLOW}$PUB_IP${NC}"
    echo -e "本地监听端口  : ${YELLOW}$PORT${NC}"
    echo -e "绑定域名      : ${YELLOW}$DOMAIN${NC}"
    echo -e "隧道 Token    : ${YELLOW}$CF_TOKEN${NC}"
    echo -e "${CYAN}==========================================${NC}"
    
    if pgrep -f gotty > /dev/null; then
        echo -e "WebSSH 状态   : ${GREEN}运行中 (Running)${NC}"
    else
        echo -e "WebSSH 状态   : ${RED}未运行${NC}"
    fi

    if pgrep -f cloudflared > /dev/null; then
        echo -e "Tunnel 状态   : ${GREEN}运行中 (Running)${NC}"
    else
        echo -e "Tunnel 状态   : ${RED}未运行${NC}"
    fi
    echo -e "${CYAN}==========================================${NC}"
    printf "按回车键继续..."
    read -r _ < /dev/tty
}

# 3. 设置账号密码
set_credentials() {
    if [ ! -f "$CONFIG_FILE" ]; then
        echo -e "${RED}请先完成安装！${NC}"
        printf "按回车键继续..."
        read -r _ < /dev/tty
        return
    fi
    . "$CONFIG_FILE"

    printf "请输入网页登录用户名: "
    read USER_NAME < /dev/tty
    printf "请输入网页登录密码: "
    read USER_PASS < /dev/tty

    pkill -f gotty 2>/dev/null
    nohup gotty --port "$PORT" --address 127.0.0.1 -w --credential "${USER_NAME}:${USER_PASS}" --permit-arguments /bin/sh > /var/log/webssh.log 2>&1 &

    echo -e "${GREEN}账号密码设置成功并已重启服务！${NC}"
    echo -e "登录账号: ${YELLOW}$USER_NAME${NC}"
    echo -e "登录密码: ${YELLOW}$USER_PASS${NC}"
    printf "按回车键继续..."
    read -r _ < /dev/tty
}

# 4. 彻底卸载
uninstall_all() {
    printf "确定要彻底卸载 WebSSH、Cloudflare 隧道及所有残留文件吗？(y/n): "
    read confirm < /dev/tty
    if [ "$confirm" = "y" ] || [ "$confirm" = "Y" ]; then
        pkill -f gotty 2>/dev/null
        pkill -f cloudflared 2>/dev/null
        rm -f /usr/local/bin/gotty
        rm -f /usr/local/bin/cloudflared
        rm -f "$CONFIG_FILE"
        rm -f /var/log/webssh.log /var/log/cloudflared.log
        echo -e "${GREEN}已彻底清理所有文件和后台进程！${NC}"
    else
        echo -e "${YELLOW}取消卸载。${NC}"
    fi
    printf "按回车键继续..."
    read -r _ < /dev/tty
}

# 主循环
while true; do
    show_menu
    case "$choice" in
        1) install_webssh ;;
        2) check_status ;;
        3) set_credentials ;;
        4) uninstall_all ;;
        0) exit 0 ;;
        *) echo -e "${RED}无效输入，请重新选择！${NC}" ;;
    esac
done
