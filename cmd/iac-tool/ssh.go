package main

import (
	"fmt"
	"iac-kubeadm-deployment/cmd/iac-tool/internal/executor"
	"os"

	"github.com/spf13/cobra"
)

var sshCmd = &cobra.Command{
	Use:   "ssh",
	Short: "Manages SSH related tasks like key generation and verification.",
	Long:  `Groups all SSH-related functionalities, such as verifying SSH connectivity to the nodes.`,
}

var verifyCmd = &cobra.Command{
	Use:   "verify",
	Short: "Verifies SSH connectivity to all VM nodes.",
	Long:  `Executes 'utils_ssh.sh' to perform SSH access verification (strict) against all hosts defined in the SSH config file.`,

	Run: func(cmd *cobra.Command, args []string) {
		fmt.Println("# Executing Verify SSH workflow via Go CLI...")
		scriptPath := "./scripts/utils_ssh.sh"

		if _, err := os.Stat(scriptPath); os.IsNotExist(err) {
			fmt.Fprintf(os.Stderr, "Error: Script not found at %s\n", scriptPath)
			os.Exit(1)
		}

		// Execute the specific function within the shell script.
		// Common pattern for calling shell functions from a non-interactive shell.
		commandString := fmt.Sprintf("source %s && prompt_verify_ssh", scriptPath)
		err := executor.ExecuteCommand("bash", "-c", commandString)

		if err != nil {
			fmt.Fprintf(os.Stderr, "SSH verification script failed with error: %v\n", err)
			os.Exit(1)
		}

		fmt.Println("# Verify SSH workflow completed successfully.")
	},
}

func init() {
	rootCmd.AddCommand(sshCmd)
	sshCmd.AddCommand(verifyCmd)
}
