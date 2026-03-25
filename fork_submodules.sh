#!/bin/bash
# 批量fork Nuclei-Software 子模块仓库

USER="cryindance"
TOKEN="$GITHUB_TOKEN"

if [ -z "$TOKEN" ]; then
    echo "错误: 未找到 GITHUB_TOKEN 环境变量"
    echo "请先设置: export GITHUB_TOKEN=你的token"
    exit 1
fi

REPOS=(
    "Nuclei-Software/buildroot"
    "Nuclei-Software/linux"
    "Nuclei-Software/opensbi"
    "Nuclei-Software/u-boot"
    "Nuclei-Software/freeloader"
    "Nuclei-Software/optee_os"
    "Nuclei-Software/optee_client"
    "Nuclei-Software/optee_test"
    "Nuclei-Software/optee_examples"
    "Nuclei-Software/optee_benchmark"
)

echo "开始fork以下仓库到 $USER..."
echo ""

for repo in "${REPOS[@]}"; do
    repo_name=$(basename $repo)
    echo -n "Forking $repo_name ... "
    
    response=$(curl -s -w "\n%{http_code}" \
        -X POST \
        -H "Authorization: token $TOKEN" \
        -H "Accept: application/vnd.github.v3+json" \
        "https://api.github.com/repos/$repo/forks" 2>/dev/null)
    
    http_code=$(echo "$response" | tail -n1)
    
    case $http_code in
        202)
            echo "✅ 成功"
            ;;
        403)
            echo "❌ 403 - Token权限不足或API限流"
            ;;
        404)
            echo "❌ 404 - 仓库不存在"
            ;;
        422)
            echo "⚠️  已存在"
            ;;
        *)
            echo "❌ HTTP $http_code"
            ;;
    esac
    
    sleep 1
done

echo ""
echo "完成！访问 https://github.com/$USER 查看"
