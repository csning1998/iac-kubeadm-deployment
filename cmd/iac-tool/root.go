package main

import (
	"fmt"
	"os"

	"github.com/spf13/cobra"
)

// rootCmd represents the base command when called without any subcommands
var rootCmd = &cobra.Command{
	Use:   "iac-tool",
	Short: "A Go-based CLI to manage the IaC lifecycle for the Kubernetes cluster.",
	Long: `This application is the Go replacement for the original entry.sh script,
providing a more robust and maintainable way to manage the IaC lifecycle.`,

// Uncomment the following line if BARE app has an action associated with it
	// Run: func(cmd *cobra.Command, args []string) { },
}

// Execute adds all child commands to the root command and sets flags appropriately, which is called by main.main().
func Execute() {
	if err := rootCmd.Execute(); err != nil {
		fmt.Fprintln(os.Stderr, err)
		os.Exit(1)
	}
}