package executor

import (
	"fmt"
	"os"
	"os/exec"
	"strings"
)

// A wrapper around os/exec.Command to execute external commands
func ExecuteCommand(name string, args ...string) error {
	cmd := exec.Command(name, args...)

	// Connect the command's stdout and stderr to the current process's streams.
	cmd.Stdout = os.Stdout
	cmd.Stderr = os.Stderr

	fmt.Fprintf(os.Stderr, ">>> Executing: %s %s\n", name, strings.Join(args, " "))

	if err := cmd.Run(); err != nil {
		return fmt.Errorf("failed to execute command: %w", err)
	}

	return nil
}
