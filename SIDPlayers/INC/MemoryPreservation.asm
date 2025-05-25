//; =============================================================================
//; MemoryPreservation.asm - SID Memory State Management
//; Part of the SIDwinder visualization framework
//; 
//; This module handles preservation and restoration of memory locations that
//; are modified during SID playback. By backing up these locations before
//; playback and restoring them afterwards, we can safely analyze SID register
//; states without corrupting the music player's internal state.
//; =============================================================================

//; -----------------------------------------------------------------------------
//; Configuration
//; -----------------------------------------------------------------------------
//; These addresses are identified as being modified during SID playback.
//; The list should be defined in the SID-specific helper file (e.g., *-HelpfulData.asm)
//; before including this file.
//;
//; Expected variables:
//;   SIDModifiedMemory - List of addresses modified during playback
//;   SIDModifiedMemoryCount - Number of addresses in the list
//; -----------------------------------------------------------------------------

#importonce

//; -----------------------------------------------------------------------------
//; Data Storage
//; -----------------------------------------------------------------------------
//; Buffer to store the original values of modified memory locations
SIDMemoryBackup:
    .fill SIDModifiedMemoryCount, $00
ZPBackup:
    .fill 256, $00

//; -----------------------------------------------------------------------------
//; SwapZPMemory
//; Swaps the current state of all ZP locations that are used by the SID with
//; those used by the player (if any)
//; 
//; Registers: Corrupts A
//; -----------------------------------------------------------------------------
SwapZPMemory:
    .for (var i = 0; i < SIDModifiedMemoryCount; i++) {
        .if (SIDModifiedMemory.get(i) < $100)
        {
            lda SIDModifiedMemory.get(i)
            ldx ZPBackup + i
            sta ZPBackup + i
            stx SIDModifiedMemory.get(i)
        }
    }
    rts

//; -----------------------------------------------------------------------------
//; BackupSIDMemory
//; Saves the current state of all memory locations that will be modified
//; during SID playback. Call this before playing the SID.
//; 
//; Registers: Corrupts A
//; -----------------------------------------------------------------------------
BackupSIDMemory:
    .for (var i = 0; i < SIDModifiedMemoryCount; i++) {
        lda SIDModifiedMemory.get(i)
        sta SIDMemoryBackup + i
    }
    rts

//; -----------------------------------------------------------------------------
//; RestoreSIDMemory
//; Restores all memory locations to their state before SID playback.
//; Call this after playing the SID to restore the original state.
//; 
//; Registers: Corrupts A
//; -----------------------------------------------------------------------------
RestoreSIDMemory:
    .for (var i = 0; i < SIDModifiedMemoryCount; i++) {
        lda SIDMemoryBackup + i
        sta SIDModifiedMemory.get(i)
    }
    rts

//; -----------------------------------------------------------------------------
//; Usage Example:
//; -----------------------------------------------------------------------------
//; jsr BackupSIDMemory      ; Save current state
//; jsr SIDPlay              ; Play music (modifies memory)
//; jsr RestoreSIDMemory     ; Restore original state
//; 
//; This allows us to:
//; 1. Play the music normally (first call)
//; 2. Play it again with $01=$30 to read SID registers
//; 3. Restore the state so the next frame plays correctly
//; -----------------------------------------------------------------------------