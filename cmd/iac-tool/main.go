package main

import (
	"iac-kubeadm-deployment/cmd/iac-tool/internal/executor"
)

func main(){
	executor.ExecuteCommand("bash", "-c", "echo 'Hello from Go Executor!'")
}