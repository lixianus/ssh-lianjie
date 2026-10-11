import os
import subprocess
import sys

CONFIG_FILE = "/etc/webssh_config.env"

def clear_screen():
    os.system('clear' if os.name == 'posix' else 'cls')

def show_menu():
    while True:
        clear_screen()
        print("============================================")
        print("   轻量多架构 WebSSH & 隧道 Python 管理面板   ")
        print("============================================")
        print(" 1. 一键安装 / 更新 WebSSH 服务")
        print(" 2. 查看服务器状态及配置信息")
        print(" 3. 配置 / 修改网页访问账号密码")
        print(" 4. 彻底卸载 WebSSH 及清理所有文件")
        print(" 0. 退出")
        print("============================================")
        
        choice = input("请选择操作 [0-4]: ").strip()
        
        if choice == '1':
            install_service()
        elif choice == '2':
            check_status()
        elif choice == '3':
            set_credentials()
        elif choice == '4':
            uninstall_all()
        elif choice == '0':
            print("再见！")
            sys.exit(0)
        else:
            input("无效输入，请按回车键重试...")

def install_service():
    clear_screen()
    print("--- 1. 安装与配置 ---")
    arch = os.uname().machine
    if arch == 'x86_64':
        gotty_arch, cf_arch = "linux_amd64", "amd64"
    elif arch in ['aarch64', 'arm64']:
        gotty_arch, cf_arch = "linux_arm64", "arm64"
    else:
        print(f"不支持的架构: {arch}")
        input("按回车继续...")
        return

    port = input("请输入 WebSSH 运行端口 [默认 12345]: ").strip()
    port = port if port else "12345"
    
    domain = input("请输入 Cloudflare Tunnel 域名 (如 ssh.example.com): ").strip()
    cf_token = input("请输入 Cloudflare Tunnel Token: ").strip()

    if not domain or not cf_token:
        print("错误：域名和 Token 不能为空！")
        input("按回车继续...")
        return

    with open(CONFIG_FILE, "w") as f:
        f.write(f"PORT={port}\nDOMAIN={domain}\nCF_TOKEN={cf_token}\n")

    print("正在下载 Gotty 组件...")
    version = "v1.5.0"
    url = f"https://github.com/sorenisanerd/gotty/releases/download/{version}/gotty_{version}_{gotty_arch}.tar.gz"
    os.system(f"wget -O gotty.tar.gz {url} || curl -sSL -o gotty.tar.gz {url}")
    os.system("tar -zxvf gotty.tar.gz && chmod +x gotty && mv gotty /usr/local/bin/ && rm -f gotty.tar.gz LICENSE README.md")

    print("正在配置 Cloudflare Tunnel...")
    if not os.path.exists("/usr/local/bin/cloudflared"):
        cf_url = f"https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-{cf_arch}"
        os.system(f"wget -O /usr/local/bin/cloudflared {cf_url} || curl -sSL -o /usr/local/bin/cloudflared {cf_url}")
        os.system("chmod +x /usr/local/bin/cloudflared")

    os.system("pkill -f gotty 2>/dev/null")
    os.system("pkill -f cloudflared 2>/dev/null")

    os.system(f"nohup gotty --port {port} --address 127.0.0.1 -w --permit-arguments /bin/sh > /var/log/webssh.log 2>&1 &")
    os.system(f"nohup cloudflared tunnel run --token {cf_token} > /var/log/cloudflared.log 2>&1 &")

    print("\n========================================")
    print("  安装成功，服务已在后台运行！")
    print(f"  访问地址: https://{domain}")
    print("========================================")
    input("按回车键返回主菜单...")

def check_status():
    clear_screen()
    if not os.path.exists(CONFIG_FILE):
        print("未检测到配置文件，请先执行安装！")
        input("按回车继续...")
        return
    
    config = {}
    with open(CONFIG_FILE, "r") as f:
        for line in f:
            if "=" in line:
                k, v = line.strip().split("=", 1)
                config[k] = v

    print("================ 信息面板 ================")
    print(f"监听端口  : {config.get('PORT')}")
    print(f"绑定域名  : {config.get('DOMAIN')}")
    print(f"隧道 Token: {config.get('CF_TOKEN')}")
    print("----------------------------------------")
    
    gotty_running = subprocess.run("pgrep -f gotty", shell=True, stdout=subprocess.PIPE).returncode == 0
    cf_running = subprocess.run("pgrep -f cloudflared", shell=True, stdout=subprocess.PIPE).returncode == 0
    
    print(f"WebSSH 状态: {'运行中' if gotty_running else '未运行'}")
    print(f"Tunnel 状态: {'运行中' if cf_running else '未运行'}")
    print("==========================================")
    input("按回车键返回主菜单...")

def set_credentials():
    clear_screen()
    if not os.path.exists(CONFIG_FILE):
        print("请先完成安装！")
        input("按回车继续...")
        return
    
    config = {}
    with open(CONFIG_FILE, "r") as f:
        for line in f:
            if "=" in line:
                k, v = line.strip().split("=", 1)
                config[k] = v

    user = input("请输入网页登录用户名: ").strip()
    pwd = input("请输入网页登录密码: ").strip()

    os.system("pkill -f gotty 2>/dev/null")
    cmd = f"nohup gotty --port {config.get('PORT')} --address 127.0.0.1 -w --credential '{user}:{pwd}' --permit-arguments /bin/sh > /var/log/webssh.log 2>&1 &"
    os.system(cmd)
    print("\n账号密码设置成功，服务已重启！")
    input("按回车键返回主菜单...")

def uninstall_all():
    clear_screen()
    confirm = input("确定要彻底卸载并删除所有文件吗？(y/n): ").strip().lower()
    if confirm == 'y':
        os.system("pkill -f gotty 2>/dev/null")
        os.system("pkill -f cloudflared 2>/dev/null")
        os.system("rm -f /usr/local/bin/gotty /usr/local/bin/cloudflared " + CONFIG_FILE + " /var/log/webssh.log /var/log/cloudflared.log")
        print("已彻底清理完毕！")
    else:
        print("取消卸载。")
    input("按回车键返回主菜单...")

if __name__ == '__main__':
    if os.geteuid() != 0:
        print("错误：请使用 root 权限运行此脚本！")
        sys.exit(1)
    show_menu()
