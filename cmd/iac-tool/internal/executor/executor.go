package executor

import (
	"fmt"
	"os"
	"os/exec"
)

// A wrapper around os/exec.Command to execute external commands
func ExecuteCommand(name string, args ...string) error {
	cmd := exec.Command(name, args...)

	// Connect the command's stdout and stderr to the current process's streams.
	cmd.Stdout = os.Stdout
	cmd.Stderr = os.Stderr

	fmt.Printf(">>> Executing: %s %v\n", name, args)

	if err := cmd.Run(); err != nil {
		fmt.Fprintf(os.Stderr, "Error running command: %v\n", err)
		return err
	}

	return nil
}
