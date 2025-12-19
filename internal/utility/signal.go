package utility

import (
	"fmt"
	"os"
	"os/exec"
	"os/signal"
	"sync"
	"syscall"
)

// SignalCallback is called when a signal is received
type SignalCallback func()

// SignalHandler handles graceful shutdown on interrupt signals
type SignalHandler struct {
	mu             sync.Mutex
	interrupted    bool
	currentCmd     *exec.Cmd
	sigChan        chan os.Signal
	onFirstSignal  SignalCallback
	onSecondSignal SignalCallback
}

// NewSignalHandler creates a new signal handler for Ctrl-C and SIGTERM
// onFirstSignal is called on the first interrupt (optional)
// onSecondSignal is called on the second interrupt before force quit (optional)
func NewSignalHandler(onFirstSignal, onSecondSignal SignalCallback) *SignalHandler {
	sh := &SignalHandler{
		sigChan:        make(chan os.Signal, 1),
		onFirstSignal:  onFirstSignal,
		onSecondSignal: onSecondSignal,
	}

	signal.Notify(sh.sigChan, os.Interrupt, syscall.SIGTERM)

	go sh.handleSignals()

	return sh
}

// handleSignals processes incoming signals
func (sh *SignalHandler) handleSignals() {
	sig := <-sh.sigChan
	sh.mu.Lock()
	sh.interrupted = true
	currentCmd := sh.currentCmd
	sh.mu.Unlock()

	if sig == nil {
		return
	}
	fmt.Println("\n\n⚠️  Interrupt received (Ctrl-C). Stopping current process...")
	fmt.Printf("%v\n", sig)
	fmt.Println("⏳ Waiting for current operation to finish. Press Ctrl-C again to force quit.")
	 

	// Execute first signal callback
	if sh.onFirstSignal != nil {
		sh.onFirstSignal()
	}

	// Try to gracefully stop current process
	if currentCmd != nil && currentCmd.Process != nil {
		//only fire the Interrupt if the previous signal stemmed from ctrl-c
		if sig == os.Interrupt {
			currentCmd.Process.Signal(os.Interrupt)
		} else {
			return
		}
		
	}

	// Wait for second signal to force quit
	sig = <-sh.sigChan
	sh.mu.Lock()
	currentCmd = sh.currentCmd
	sh.mu.Unlock()

	//print recieved signal 
	fmt.Printf("\n\n⚠️  Second interrupt received (%v). Force quitting...\n", sig)
	fmt.Println("\n❌ Force quit!")

	// Execute second signal callback
	if sh.onSecondSignal != nil {
		sh.onSecondSignal()
	}

	if currentCmd != nil && currentCmd.Process != nil {
		currentCmd.Process.Kill()
	}
	os.Exit(130)
}

// SetCurrentCommand sets the currently running command for signal propagation
func (sh *SignalHandler) SetCurrentCommand(cmd *exec.Cmd) {
	sh.mu.Lock()
	defer sh.mu.Unlock()
	sh.currentCmd = cmd
}

// ClearCurrentCommand clears the current command reference
func (sh *SignalHandler) ClearCurrentCommand() {
	sh.mu.Lock()
	defer sh.mu.Unlock()
	sh.currentCmd = nil
}

// IsInterrupted returns true if an interrupt signal was received
func (sh *SignalHandler) IsInterrupted() bool {
	sh.mu.Lock()
	defer sh.mu.Unlock()
	return sh.interrupted
}

// Stop stops listening for signals
func (sh *SignalHandler) Stop() {
	signal.Stop(sh.sigChan)
	close(sh.sigChan)
}
