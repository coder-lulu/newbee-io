#!/bin/bash

# Phase 1 交付验证脚本
# 用途: 验证所有交付物是否完整

set -e

echo "╔══════════════════════════════════════════════════════════════╗"
echo "║                                                              ║"
echo "║     Phase 1: Scheduled Tasks - 交付验证                      ║"
echo "║                                                              ║"
echo "╚══════════════════════════════════════════════════════════════╝"
echo ""

BASE_DIR="/opt/code/newbee/unified-io"
cd "$BASE_DIR"

# 颜色定义
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# 计数器
TOTAL=0
PASSED=0
FAILED=0

check_file() {
    TOTAL=$((TOTAL + 1))
    if [ -f "$1" ]; then
        echo -e "${GREEN}✅${NC} $2"
        PASSED=$((PASSED + 1))
    else
        echo -e "${RED}❌${NC} $2 (文件不存在: $1)"
        FAILED=$((FAILED + 1))
    fi
}

check_dir() {
    TOTAL=$((TOTAL + 1))
    if [ -d "$1" ]; then
        echo -e "${GREEN}✅${NC} $2"
        PASSED=$((PASSED + 1))
    else
        echo -e "${RED}❌${NC} $2 (目录不存在: $1)"
        FAILED=$((FAILED + 1))
    fi
}

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "1️⃣  检查核心代码文件"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

check_file "rpc/internal/worker/task_worker.go" "TaskWorker核心实现"
check_file "rpc/internal/logic/inputtask/create_input_task_logic.go" "参数验证逻辑"
check_file "rpc/ent/schema/input_task.go" "Schema定义"

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "2️⃣  检查测试文件"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

check_file "rpc/internal/worker/task_worker_test.go" "单元测试套件"
check_file "rpc/internal/worker/integration_test.go" "集成测试套件"

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "3️⃣  检查文档文件"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

check_file "docs/SCHEDULED_TASKS.md" "功能完整文档"
check_file "docs/DEPLOYMENT_GUIDE.md" "部署运维指南"
check_file "docs/SCHEDULED_TASKS_INTEGRATION_TEST.md" "集成测试计划"
check_file "docs/INTEGRATION_TEST_RESULTS.md" "测试结果报告"
check_file "docs/PHASE1_COMPLETION_CHECKLIST.md" "完成检查清单"
check_file "docs/PHASE1_SUCCESS_REPORT.md" "成功交付报告"
check_file "docs/PHASE1_FINAL_SUMMARY.md" "项目总结"

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "4️⃣  检查示例和索引"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

check_file "examples/scheduled_task_example.go" "客户端示例代码"
check_file "examples/README.md" "示例使用说明"
check_file "SCHEDULED_TASKS_INDEX.md" "文档索引"

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "5️⃣  代码编译检查"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

cd rpc
if go build -v . > /dev/null 2>&1; then
    echo -e "${GREEN}✅${NC} 代码编译成功"
    PASSED=$((PASSED + 1))
else
    echo -e "${RED}❌${NC} 代码编译失败"
    FAILED=$((FAILED + 1))
fi
TOTAL=$((TOTAL + 1))

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "📊 验证总结"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

echo ""
echo "总计: $TOTAL 项"
echo -e "通过: ${GREEN}$PASSED${NC} 项"

if [ $FAILED -gt 0 ]; then
    echo -e "失败: ${RED}$FAILED${NC} 项"
    echo ""
    echo -e "${RED}❌ 交付验证失败！请检查缺失的文件。${NC}"
    exit 1
else
    echo "失败: 0 项"
    echo ""
    echo -e "${GREEN}✅ 所有交付物验证通过！${NC}"
    echo ""
    echo "  Phase 1: Scheduled Tasks"
    echo "  状态: ✅ 交付完成"
    echo "  版本: v1.0"
    echo "  日期: $(date '+%Y-%m-%d')"
    echo ""
fi

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
