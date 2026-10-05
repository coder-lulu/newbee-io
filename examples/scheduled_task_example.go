package main

import (
	"context"
	"fmt"
	"log"
	"time"

	"google.golang.org/grpc"
	"google.golang.org/grpc/credentials/insecure"

	io "github.com/coder-lulu/newbee-io-rpc/types/io"
)

// 本示例演示如何使用 unified-io 服务创建和管理定时任务

func main() {
	fmt.Println("=== Scheduled Tasks 使用示例 ===\n")

	// 1. 连接到 unified-io RPC 服务
	conn, err := grpc.Dial("localhost:9102", grpc.WithTransportCredentials(insecure.NewCredentials()))
	if err != nil {
		log.Fatalf("连接失败: %v", err)
	}
	defer conn.Close()

	client := io.NewIoClient(conn)
	ctx := context.Background()

	// 示例1: 创建简单的定时任务
	fmt.Println("示例1: 创建一个5分钟后执行的定时任务")
	example1(ctx, client)

	fmt.Println("\n" + "=".repeat(50) + "\n")

	// 示例2: 批量创建定时任务
	fmt.Println("示例2: 为每天特定时间创建定时任务")
	example2(ctx, client)

	fmt.Println("\n" + "=".repeat(50) + "\n")

	// 示例3: 查询定时任务状态
	fmt.Println("示例3: 查询和监控定时任务")
	example3(ctx, client)
}

// 示例1: 创建简单的定时任务
func example1(ctx context.Context, client io.IoClient) {
	// 设置任务在5分钟后执行
	scheduledTime := time.Now().Add(5 * time.Minute)
	scheduledAtMs := scheduledTime.UnixMilli()

	taskName := "数据发现任务-示例1"
	taskType := "scheduled"
	inputSource := "vmware_vcenter"
	sourceConfig := `{
		"host": "vcenter.example.com",
		"username": "admin",
		"datacenter": "DC1"
	}`
	taskStatus := "pending"
	tenantId := uint64(1)

	req := &io.InputTaskInfo{
		TaskName:     &taskName,
		TaskType:     &taskType,
		ScheduledAt:  &scheduledAtMs,
		InputSource:  &inputSource,
		SourceConfig: &sourceConfig,
		TaskStatus:   &taskStatus,
		TenantId:     &tenantId,
	}

	resp, err := client.CreateInputTask(ctx, req)
	if err != nil {
		log.Printf("❌ 创建任务失败: %v", err)
		return
	}

	fmt.Printf("✅ 任务创建成功\n")
	fmt.Printf("   任务ID: %d\n", *resp.Id)
	fmt.Printf("   任务名称: %s\n", taskName)
	fmt.Printf("   执行时间: %s\n", scheduledTime.Format("2006-01-02 15:04:05"))
	fmt.Printf("   距离执行: %.0f 分钟\n", time.Until(scheduledTime).Minutes())
}

// 示例2: 批量创建定时任务（每天定时数据发现）
func example2(ctx context.Context, client io.IoClient) {
	// 定义数据源
	dataSources := []struct {
		name   string
		source string
		config string
	}{
		{
			name:   "VMware vCenter",
			source: "vmware_vcenter",
			config: `{"host": "vcenter1.example.com"}`,
		},
		{
			name:   "阿里云 ECS",
			source: "aliyun_ecs",
			config: `{"region": "cn-hangzhou"}`,
		},
		{
			name:   "AWS EC2",
			source: "aws_ec2",
			config: `{"region": "us-west-2"}`,
		},
	}

	// 为每个数据源创建凌晨3点的定时任务
	tomorrow := time.Now().AddDate(0, 0, 1)
	scheduledTime := time.Date(tomorrow.Year(), tomorrow.Month(), tomorrow.Day(), 3, 0, 0, 0, tomorrow.Location())

	fmt.Printf("创建批量定时任务，执行时间: %s\n\n", scheduledTime.Format("2006-01-02 15:04:05"))

	for i, ds := range dataSources {
		// 错开30分钟避免堆积
		taskTime := scheduledTime.Add(time.Duration(i*30) * time.Minute)
		taskTimeMs := taskTime.UnixMilli()

		taskName := fmt.Sprintf("每日数据发现-%s", ds.name)
		taskType := "scheduled"
		taskStatus := "pending"
		tenantId := uint64(1)

		req := &io.InputTaskInfo{
			TaskName:     &taskName,
			TaskType:     &taskType,
			ScheduledAt:  &taskTimeMs,
			InputSource:  &ds.source,
			SourceConfig: &ds.config,
			TaskStatus:   &taskStatus,
			TenantId:     &tenantId,
		}

		resp, err := client.CreateInputTask(ctx, req)
		if err != nil {
			log.Printf("❌ 创建任务失败 [%s]: %v", ds.name, err)
			continue
		}

		fmt.Printf("✅ [%d] %s\n", *resp.Id, ds.name)
		fmt.Printf("    执行时间: %s\n", taskTime.Format("15:04:05"))
		fmt.Printf("    数据源: %s\n\n", ds.source)
	}
}

// 示例3: 查询定时任务状态
func example3(ctx context.Context, client io.IoClient) {
	// 创建测试任务
	scheduledTime := time.Now().Add(2 * time.Minute)
	scheduledAtMs := scheduledTime.UnixMilli()

	taskName := "状态监控测试任务"
	taskType := "scheduled"
	inputSource := "test_source"
	sourceConfig := `{"test": true}`
	taskStatus := "pending"
	tenantId := uint64(1)

	req := &io.InputTaskInfo{
		TaskName:     &taskName,
		TaskType:     &taskType,
		ScheduledAt:  &scheduledAtMs,
		InputSource:  &inputSource,
		SourceConfig: &sourceConfig,
		TaskStatus:   &taskStatus,
		TenantId:     &tenantId,
	}

	createResp, err := client.CreateInputTask(ctx, req)
	if err != nil {
		log.Printf("❌ 创建任务失败: %v", err)
		return
	}

	taskId := *createResp.Id
	fmt.Printf("✅ 创建测试任务 ID=%d\n\n", taskId)

	// 轮询查询任务状态
	fmt.Println("开始监控任务状态...")
	fmt.Println("(按 Ctrl+C 退出)\n")

	ticker := time.NewTicker(10 * time.Second)
	defer ticker.Stop()

	startTime := time.Now()
	for i := 0; i < 15; i++ { // 最多查询15次（2.5分钟）
		<-ticker.C

		// 查询任务状态
		getReq := &io.IDReq{Id: taskId}
		task, err := client.GetInputTaskById(ctx, getReq)
		if err != nil {
			log.Printf("❌ 查询任务失败: %v", err)
			continue
		}

		elapsed := time.Since(startTime)
		status := *task.TaskStatus

		// 打印状态
		fmt.Printf("[%02.0fs] 任务状态: %s", elapsed.Seconds(), status)

		switch status {
		case "pending":
			remainingTime := scheduledTime.Sub(time.Now())
			if remainingTime > 0 {
				fmt.Printf(" (距离执行还有 %.0f 秒)", remainingTime.Seconds())
			} else {
				fmt.Printf(" (已到期，等待 TaskWorker 处理)")
			}

		case "processing":
			if task.StartedAt != nil {
				startedAt := time.UnixMilli(*task.StartedAt)
				processingDuration := time.Since(startedAt)
				fmt.Printf(" (已执行 %.1f 秒)", processingDuration.Seconds())
			}

		case "completed":
			if task.CompletedAt != nil && task.StartedAt != nil {
				completedAt := time.UnixMilli(*task.CompletedAt)
				startedAt := time.UnixMilli(*task.StartedAt)
				duration := completedAt.Sub(startedAt)

				// 计算执行延迟
				delay := startedAt.Sub(scheduledTime)

				fmt.Printf("\n\n✅ 任务执行完成！")
				fmt.Printf("\n   计划时间: %s", scheduledTime.Format("15:04:05"))
				fmt.Printf("\n   实际开始: %s", startedAt.Format("15:04:05"))
				fmt.Printf("\n   完成时间: %s", completedAt.Format("15:04:05"))
				fmt.Printf("\n   执行延迟: %.1f 秒", delay.Seconds())
				fmt.Printf("\n   执行耗时: %.1f 秒\n", duration.Seconds())
			}
			return

		case "failed":
			fmt.Printf("\n\n❌ 任务执行失败")
			if task.ErrorMessage != nil {
				fmt.Printf("\n   错误信息: %s\n", *task.ErrorMessage)
			}
			return
		}

		fmt.Println()
	}

	fmt.Println("\n⚠️  监控超时，但任务仍在后台运行")
}

// 辅助函数
func repeat(s string, count int) string {
	result := ""
	for i := 0; i < count; i++ {
		result += s
	}
	return result
}
