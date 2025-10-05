#!/usr/bin/env bash
set -euo pipefail

# 部署脚本：处理引导程序安装问题
# 使用方法: ./scripts/deploy-with-bootloader.sh

echo "🚀 开始部署 homelab_thunk..."

# 检查是否在正确的目录
if [ ! -f "flake.nix" ]; then
    echo "❌ 错误：请在 nix-homelab 目录下运行此脚本"
    exit 1
fi

# 检查目标机器是否可达
echo "🔍 检查目标机器连接..."
if ! ssh -o ConnectTimeout=10 root@homelab_thunk "echo '连接成功'"; then
    echo "❌ 无法连接到 homelab_thunk，请检查网络和 SSH 配置"
    exit 1
fi

echo "✅ 目标机器连接正常"

# 在目标机器上检查引导程序状态
echo "🔍 检查引导程序状态..."
BOOTLOADER_STATUS=$(ssh root@homelab_thunk "
    if [ -f /boot/EFI/systemd/systemd-bootx64.efi ]; then
        echo 'installed'
    else
        echo 'not_installed'
    fi
")

if [ "$BOOTLOADER_STATUS" = "not_installed" ]; then
    echo "⚠️  检测到 systemd-boot 未安装，正在安装..."
    
    # 在目标机器上安装引导程序
    ssh root@homelab_thunk "
        echo '正在安装 systemd-boot...'
        nixos-rebuild switch --install-bootloader
    "
    
    if [ $? -eq 0 ]; then
        echo "✅ systemd-boot 安装成功"
    else
        echo "❌ systemd-boot 安装失败"
        exit 1
    fi
else
    echo "✅ systemd-boot 已安装"
fi

# 执行正常部署
echo "🚀 开始 deploy-rs 部署..."
nix run github:serokell/deploy-rs -- -s .#homelab_thunk

echo "✅ 部署完成！"
