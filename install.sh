#!/bin/bash

red='\033[0;31m'
green='\033[0;32m'
blue='\033[0;34m'
yellow='\033[0;33m'
plain='\033[0m'

cur_dir=$(pwd)

echo -e "${green}===========================================================${plain}"
echo -e "${green}开始执行3x-ui面板安装脚本${plain}"
echo -e "${green}===========================================================${plain}"

# check root
[[ $EUID -ne 0 ]] && echo -e "${red}致命错误: ${plain} 请使用root用户权限运行此脚本 \n " && exit 1
echo -e "${green}[步骤1/7] 权限检查通过，继续安装...${plain}"

echo -e "${green}[步骤2/7] 正在检测系统类型...${plain}"
# Check OS and set release variable
if [[ -f /etc/os-release ]]; then
    source /etc/os-release
    release=$ID
elif [[ -f /usr/lib/os-release ]]; then
    source /usr/lib/os-release
    release=$ID
else
    echo "无法检测系统类型，请联系作者！" >&2
    exit 1
fi
echo -e "${green}系统类型: ${plain}$release"

echo -e "${green}[步骤3/7] 正在检测CPU架构...${plain}"
arch() {
    case "$(uname -m)" in
    x86_64 | x64 | amd64) echo 'amd64' ;;
    i*86 | x86) echo '386' ;;
    armv8* | armv8 | arm64 | aarch64) echo 'arm64' ;;
    armv7* | armv7 | arm) echo 'armv7' ;;
    armv6* | armv6) echo 'armv6' ;;
    armv5* | armv5) echo 'armv5' ;;
    s390x) echo 's390x' ;;
    *) echo -e "${red}不支持的CPU架构! ${plain}" && rm -f install.sh && exit 1 ;;
    esac
}

echo -e "${green}CPU架构: ${plain}$(arch)"

echo -e "${green}[步骤4/7] 正在检测GLIBC版本...${plain}"
check_glibc_version() {
    glibc_version=$(ldd --version | head -n1 | awk '{print $NF}')
    
    required_version="2.32"
    if [[ "$(printf '%s\n' "$required_version" "$glibc_version" | sort -V | head -n1)" != "$required_version" ]]; then
        echo -e "${red}GLIBC 版本 $glibc_version 太旧! 需要: 2.32 或更高版本${plain}"
        echo "请升级您的操作系统以获取更高版本的 GLIBC。"
        exit 1
    fi
    echo -e "${green}GLIBC 版本: ${plain}$glibc_version (满足2.32+的要求)"
}
check_glibc_version

install_base() {
    echo -e "${green}[步骤5/7] 正在安装基础软件包...${plain}"
    case "${release}" in
    ubuntu | debian | armbian)
        echo -e "${yellow}检测到Debian系统，使用apt安装依赖...${plain}"
        apt-get update && apt-get install -y -q wget curl tar tzdata
        ;;
    centos | almalinux | rocky | ol)
        echo -e "${yellow}检测到CentOS系统，使用yum安装依赖...${plain}"
        yum -y update && yum install -y -q wget curl tar tzdata
        ;;
    fedora | amzn | virtuozzo)
        echo -e "${yellow}检测到Fedora系统，使用dnf安装依赖...${plain}"
        dnf -y update && dnf install -y -q wget curl tar tzdata
        ;;
    arch | manjaro | parch)
        echo -e "${yellow}检测到Arch系统，使用pacman安装依赖...${plain}"
        pacman -Syu && pacman -Syu --noconfirm wget curl tar tzdata
        ;;
    opensuse-tumbleweed)
        echo -e "${yellow}检测到OpenSUSE系统，使用zypper安装依赖...${plain}"
        zypper refresh && zypper -q install -y wget curl tar timezone
        ;;
    *)
        echo -e "${yellow}未能精确识别系统类型，使用通用方式安装依赖...${plain}"
        apt-get update && apt install -y -q wget curl tar tzdata
        ;;
    esac
    echo -e "${green}基础软件包安装完成${plain}"
}

gen_random_string() {
    local length="$1"
    local random_string=$(LC_ALL=C tr -dc 'a-zA-Z0-9' </dev/urandom | fold -w "$length" | head -n 1)
    echo "$random_string"
}

config_after_install() {
    echo -e "${green}[步骤6/7] 正在配置面板设置...${plain}"
    echo -e "${yellow}正在获取当前配置信息...${plain}"
    local existing_username=$(/usr/local/x-ui/x-ui setting -show true | grep -Eo 'username: .+' | awk '{print $2}')
    local existing_password=$(/usr/local/x-ui/x-ui setting -show true | grep -Eo 'password: .+' | awk '{print $2}')
    local existing_webBasePath=$(/usr/local/x-ui/x-ui setting -show true | grep -Eo 'webBasePath: .+' | awk '{print $2}')
    local existing_port=$(/usr/local/x-ui/x-ui setting -show true | grep -Eo 'port: .+' | awk '{print $2}')
    echo -e "${yellow}正在获取服务器IP地址...${plain}"
    local server_ip=$(curl -s https://api.ipify.org)

    if [[ ${#existing_webBasePath} -lt 4 ]]; then
        if [[ "$existing_username" == "admin" && "$existing_password" == "admin" ]]; then
            echo -e "${yellow}检测到默认配置，正在生成安全的随机配置...${plain}"
            local config_webBasePath=$(gen_random_string 15)
            local config_username=$(gen_random_string 10)
            local config_password=$(gen_random_string 10)

            read -rp "是否要自定义面板端口设置？(如果不需要，将使用随机端口) [y/n]: " config_confirm
            if [[ "${config_confirm}" == "y" || "${config_confirm}" == "Y" ]]; then
                read -rp "请设置面板端口: " config_port
                echo -e "${yellow}您的面板端口是: ${config_port}${plain}"
            else
                local config_port=$(shuf -i 1024-62000 -n 1)
                echo -e "${yellow}已生成随机端口: ${config_port}${plain}"
            fi

            echo -e "${yellow}正在应用新的配置...${plain}"
            /usr/local/x-ui/x-ui setting -username "${config_username}" -password "${config_password}" -port "${config_port}" -webBasePath "${config_webBasePath}"
            echo -e "这是一个全新安装，为了安全考虑，已生成随机登录信息:"
            echo -e "###############################################"
            echo -e "${green}用户名: ${config_username}${plain}"
            echo -e "${green}密码: ${config_password}${plain}"
            echo -e "${green}端口: ${config_port}${plain}"
            echo -e "${green}网页路径: ${config_webBasePath}${plain}"
            echo -e "${green}面板访问地址: http://${server_ip}:${config_port}/${config_webBasePath}${plain}"
            echo -e "###############################################"
            echo -e "${yellow}如果您忘记了登录信息，可以输入 'x-ui settings' 查看${plain}"
        else
            echo -e "${yellow}网页路径缺失或太短。正在生成新的...${plain}"
            local config_webBasePath=$(gen_random_string 15)
            /usr/local/x-ui/x-ui setting -webBasePath "${config_webBasePath}"
            echo -e "${green}新的网页路径: ${config_webBasePath}${plain}"
            echo -e "${green}面板访问地址: http://${server_ip}:${existing_port}/${config_webBasePath}${plain}"
            echo -e "${yellow}请保存好以上信息，以便后续登录面板${plain}"
        fi
    else
        if [[ "$existing_username" == "admin" && "$existing_password" == "admin" ]]; then
            echo -e "${yellow}检测到默认凭据。需要安全更新...${plain}"
            local config_username=$(gen_random_string 10)
            local config_password=$(gen_random_string 10)

            echo -e "${yellow}正在更新登录凭据...${plain}"
            /usr/local/x-ui/x-ui setting -username "${config_username}" -password "${config_password}"
            echo -e "已生成新的随机登录凭据:"
            echo -e "###############################################"
            echo -e "${green}用户名: ${config_username}${plain}"
            echo -e "${green}密码: ${config_password}${plain}"
            echo -e "${green}面板访问地址: http://${server_ip}:${existing_port}/${existing_webBasePath}${plain}"
            echo -e "###############################################"
            echo -e "${yellow}如果您忘记了登录信息，可以输入 'x-ui settings' 查看${plain}"
        else
            echo -e "${green}用户名、密码和网页路径已正确设置。${plain}"
            echo -e "${green}面板访问地址: http://${server_ip}:${existing_port}/${existing_webBasePath}${plain}"
        fi
    fi

    echo -e "${yellow}正在迁移数据...${plain}"
    /usr/local/x-ui/x-ui migrate
    echo -e "${green}面板配置完成${plain}"
}

install_x-ui() {
    echo -e "${green}[步骤7/7] 开始安装3x-ui面板...${plain}"
    cd /usr/local/

    if [ $# == 0 ]; then
        echo -e "${green}正在获取最新版本...${plain}"
        tag_version=$(curl -Ls "https://api.github.com/repos/MHSanaei/3x-ui/releases/latest" | grep '"tag_name":' | sed -E 's/.*"([^"]+)".*/\1/')
        if [[ ! -n "$tag_version" ]]; then
            echo -e "${red}获取x-ui版本失败，可能是由于GitHub API限制，请稍后再试${plain}"
            exit 1
        fi
        echo -e "${green}获取到x-ui最新版本: ${tag_version}，开始安装...${plain}"
        echo -e "${green}正在下载安装包...${plain}"
        wget -N -O /usr/local/x-ui-linux-$(arch).tar.gz https://github.com/MHSanaei/3x-ui/releases/download/${tag_version}/x-ui-linux-$(arch).tar.gz
        if [[ $? -ne 0 ]]; then
            echo -e "${red}下载x-ui失败，请确保您的服务器可以访问GitHub${plain}"
            exit 1
        fi
    else
        tag_version=$1
        tag_version_numeric=${tag_version#v}
        min_version="2.3.5"

        if [[ "$(printf '%s\n' "$min_version" "$tag_version_numeric" | sort -V | head -n1)" != "$min_version" ]]; then
            echo -e "${red}请使用更新的版本 (至少v2.3.5)。退出安装。${plain}"
            exit 1
        fi

        url="https://github.com/MHSanaei/3x-ui/releases/download/${tag_version}/x-ui-linux-$(arch).tar.gz"
        echo -e "${green}开始安装x-ui $1${plain}"
        echo -e "${green}正在下载安装包...${plain}"
        wget -N -O /usr/local/x-ui-linux-$(arch).tar.gz ${url}
        if [[ $? -ne 0 ]]; then
            echo -e "${red}下载x-ui $1失败，请检查版本是否存在${plain}"
            exit 1
        fi
    fi

    if [[ -e /usr/local/x-ui/ ]]; then
        echo -e "${green}检测到旧版本，正在卸载...${plain}"
        systemctl stop x-ui
        rm /usr/local/x-ui/ -rf
    fi

    echo -e "${green}正在解压安装包...${plain}"
    tar zxvf x-ui-linux-$(arch).tar.gz
    rm x-ui-linux-$(arch).tar.gz -f
    cd x-ui
    chmod +x x-ui

    # Check the system's architecture and rename the file accordingly
    if [[ $(arch) == "armv5" || $(arch) == "armv6" || $(arch) == "armv7" ]]; then
        mv bin/xray-linux-$(arch) bin/xray-linux-arm
        chmod +x bin/xray-linux-arm
    fi

    echo -e "${green}正在设置权限...${plain}"
    chmod +x x-ui bin/xray-linux-$(arch)
    cp -f x-ui.service /etc/systemd/system/
    echo -e "${green}正在下载控制脚本...${plain}"
    wget -O /usr/bin/x-ui https://raw.githubusercontent.com/MHSanaei/3x-ui/main/x-ui.sh
    chmod +x /usr/local/x-ui/x-ui.sh
    chmod +x /usr/bin/x-ui
    echo -e "${green}正在配置面板...${plain}"
    config_after_install

    echo -e "${green}正在启动服务...${plain}"
    systemctl daemon-reload
    systemctl enable x-ui
    systemctl start x-ui
    echo -e "${green}===========================================================${plain}"
    echo -e "${green}x-ui ${tag_version}${plain} 安装完成，面板已启动运行..."
    echo -e "${green}===========================================================${plain}"
    echo -e ""
    echo -e "┌───────────────────────────────────────────────────────┐
│  ${blue}x-ui 控制菜单使用说明:${plain}                           │
│                                                       │
│  ${blue}x-ui${plain}              - 管理脚本                       │
│  ${blue}x-ui start${plain}        - 启动面板                       │
│  ${blue}x-ui stop${plain}         - 停止面板                       │
│  ${blue}x-ui restart${plain}      - 重启面板                       │
│  ${blue}x-ui status${plain}       - 查看面板状态                   │
│  ${blue}x-ui settings${plain}     - 查看面板设置                   │
│  ${blue}x-ui enable${plain}       - 设置开机自启                   │
│  ${blue}x-ui disable${plain}      - 取消开机自启                   │
│  ${blue}x-ui log${plain}          - 查看面板日志                   │
│  ${blue}x-ui banlog${plain}       - 查看封禁日志                   │
│  ${blue}x-ui update${plain}       - 更新面板                       │
│  ${blue}x-ui legacy${plain}       - 安装旧版本                     │
│  ${blue}x-ui install${plain}      - 安装面板                       │
│  ${blue}x-ui uninstall${plain}    - 卸载面板                       │
└───────────────────────────────────────────────────────┘"
}

echo -e "${green}Running...${plain}"
install_base
install_x-ui $1
