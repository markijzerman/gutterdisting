# Project Structure Overview

This document explains the complete folder structure and relationships for the Guttersynth → Disting NT port project.

---

## Complete Directory Tree

```
/Users/markijzerman/Dropbox/DISTING/guttersynth_on_disting/
│
├── guttersynth_disting_port/              ← NEW PROJECT FOLDER (you are here)
│   │
│   ├── README.md                          ← Main project documentation
│   ├── PROJECT_STRUCTURE.md               ← This file
│   ├── .gitignore                         ← Git ignore patterns
│   │
│   ├── src/                               ← Faust DSP source code
│   │   ├── guttersynth.dsp                ← Main (for Disting NT)
│   │   └── guttersynth_test.dsp           ← Test (for Faust IDE)
│   │
│   ├── build/                             ← Build system
│   │   ├── Makefile                       ← Build automation
│   │   └── guttersynth.o                  ← Build output (after make)
│   │
│   ├── docs/                              ← Documentation
│   │   ├── IMPLEMENTATION.md              ← Detailed implementation specs
│   │   ├── BUILD_GUTTERSYNTH.md           ← Build instructions
│   │   └── IMPLEMENTATION_SUMMARY.md      ← Quick reference
│   │
│   └── tests/                             ← Test files (future)
│       └── (test recordings, presets)
│
├── guttersynthesis-master/                ← ORIGINAL IMPLEMENTATION
│   ├── gutterOsc.java                     ← Reference: Core algorithm
│   ├── filters.txt                        ← Reference: Filter presets
│   ├── Gutter Synth.maxpat                ← Reference: Full patch
│   └── ...
│
├── distingNT_API-main/                    ← DISTING NT API
│   ├── include/distingnt/                 ← API headers
│   │   └── api.h                          ← Core API definitions
│   ├── examples/                          ← Example C++ plugins
│   │   ├── gain.cpp
│   │   ├── monosynth.cpp
│   │   ├── fourteen.cpp                   ← Currently open
│   │   └── ...
│   ├── faust/                             ← Faust integration
│   │   ├── faust2distingnt                ← Build script
│   │   ├── nt_arch.cpp                    ← Faust architecture wrapper
│   │   └── examples/                      ← Faust examples
│   │       ├── guttersynth.dsp            ← Symlinked/copied from project
│   │       ├── guttersynth_test.dsp       ← Symlinked/copied from project
│   │       ├── guttersynth_README.md      ← Symlinked/copied from project
│   │       ├── BUILD_GUTTERSYNTH.md       ← Symlinked/copied from project
│   │       ├── Makefile.guttersynth       ← Symlinked/copied from project
│   │       ├── sawtooth.dsp               ← Reference example
│   │       └── moog_vcf.dsp               ← Reference example
│   └── ...
│
└── IMPLEMENTATION_SUMMARY.md              ← Top-level summary (for reference)
```

---

## Folder Purposes

### `guttersynth_disting_port/` ← **MAIN PROJECT FOLDER**

**Purpose:** Central location for all Guttersynth port development

**Contents:**
- Source code (`.dsp` files)
- Build system (Makefile)
- Documentation
- Build outputs (`.o` file)
- Tests (future)

**Why separate?**
- Keeps project organized
- Doesn't pollute the API or original repos
- Easy to version control independently
- Clear separation of original vs port

### `guttersynthesis-master/` ← **REFERENCE**

**Purpose:** Original Max/MSP implementation by Tom Mudd

**Key files for reference:**
- `gutterOsc.java` - Core Duffing + filter algorithm
- `filters.txt` - Filter bank presets
- `Gutter Synth.maxpat` - Full Max patch

**Usage:** Read-only reference for understanding the algorithm

### `distingNT_API-main/` ← **TARGET PLATFORM**

**Purpose:** Disting NT plugin API and build tools

**Key components:**
- Headers: Plugin API definitions
- Examples: Reference implementations
- Faust: Build tools and architecture

**Integration:** The build system references this directory

---

## File Relationships

### Source Code Synchronization

The `.dsp` files exist in two locations:

**Primary location** (for development):
```
guttersynth_disting_port/src/
├── guttersynth.dsp
└── guttersynth_test.dsp
```

**Secondary location** (for API integration):
```
distingNT_API-main/faust/examples/
├── guttersynth.dsp
└── guttersynth_test.dsp
```

**Sync strategy:**
- Edit in `guttersynth_disting_port/src/`
- Copy to `distingNT_API-main/faust/examples/` when stable
- Or use symlinks (if your OS supports them)

### Build Dependencies

```
Makefile (in build/)
    ↓
    references: src/guttersynth.dsp
    ↓
    calls: distingNT_API-main/faust/faust2distingnt
    ↓
    uses: distingNT_API-main/faust/nt_arch.cpp
    ↓
    includes: distingNT_API-main/include/distingnt/api.h
    ↓
    produces: build/guttersynth.o
```

### Documentation Flow

```
README.md (project root)
    ↓ references
    ├── docs/IMPLEMENTATION.md (detailed specs)
    ├── docs/BUILD_GUTTERSYNTH.md (build guide)
    └── docs/IMPLEMENTATION_SUMMARY.md (quick ref)
```

---

## Workflow Paths

### Development Workflow

```
1. EDIT:     guttersynth_disting_port/src/guttersynth_test.dsp
2. TEST:     https://faustide.grame.fr/ (Faust IDE)
3. SYNC:     Copy changes to guttersynth.dsp (keep metadata)
4. BUILD:    cd guttersynth_disting_port/build/ && make
5. OUTPUT:   guttersynth_disting_port/build/guttersynth.o
6. DEPLOY:   Copy .o to Disting NT SD card
7. TEST:     On actual hardware
8. DOCUMENT: Update docs/ with findings
```

### Reference Lookup

```
QUESTION: "How does the Duffing oscillator work?"
    ↓
    READ: guttersynthesis-master/gutterOsc.java
    ↓
    LINES: 226-231 (core equation)

QUESTION: "How do Disting plugins handle parameters?"
    ↓
    READ: distingNT_API-main/examples/gain.cpp
    ↓
    OR: distingNT_API-main/include/distingnt/api.h
```

---

## Path Configuration

### Build System Paths

The Makefile uses relative paths from `guttersynth_disting_port/build/`:

```makefile
NT_API_PATH ?= ../../distingNT_API-main     # Up 2, into API
SRC_DIR = ../src                            # Up 1, into src
DSP_FILE = $(SRC_DIR)/guttersynth.dsp       # Combine
```

This assumes the directory structure:
```
parent/
├── guttersynth_disting_port/build/  ← You are here
└── distingNT_API-main/              ← Relative: ../../distingNT_API-main
```

### Environment Variables

```bash
# Required for build
export FAUSTARCH=/path/to/faust/architecture

# Optional (uses default if not set)
export NT_API_PATH=/Users/markijzerman/Dropbox/DISTING/guttersynth_on_disting/distingNT_API-main
```

---

## Navigation Guide

### Working on DSP code?
→ `cd guttersynth_disting_port/src/`

### Building the plugin?
→ `cd guttersynth_disting_port/build/`

### Reading documentation?
→ `cd guttersynth_disting_port/docs/`

### Checking the original algorithm?
→ `cd ../guttersynthesis-master/`

### Looking at API examples?
→ `cd ../distingNT_API-main/examples/`

### Understanding Faust integration?
→ `cd ../distingNT_API-main/faust/`

---

## Version Control

### Recommended Git Structure

If using Git, the main project folder can be a repository:

```bash
cd guttersynth_disting_port/
git init
git add .
git commit -m "Initial Guttersynth for Disting NT v0.1"
```

The `.gitignore` is already configured to exclude:
- Build outputs (`.o`, `.cpp`)
- Temp files
- OS files
- Editor configs

### Excluding External Dependencies

Do NOT commit the parent directories:
- `guttersynthesis-master/` - External repository
- `distingNT_API-main/` - External repository

These should be documented as dependencies.

---

## Quick Command Reference

### From project root (`guttersynth_disting_port/`)

```bash
# Build for Disting NT
cd build && make

# Check DSP syntax
cd build && make check

# Build test application
cd build && make test

# Clean build artifacts
cd build && make clean

# View help
cd build && make help

# Edit main DSP
nano src/guttersynth.dsp

# Edit test DSP
nano src/guttersynth_test.dsp

# Read documentation
cat docs/IMPLEMENTATION.md
cat docs/BUILD_GUTTERSYNTH.md
cat docs/IMPLEMENTATION_SUMMARY.md
```

---

## File Sizes (Approximate)

```
guttersynth.dsp           ~5 KB    (154 lines)
guttersynth_test.dsp      ~5 KB    (147 lines)
guttersynth.o             ~20 KB   (compiled ARM object)
README.md                 ~15 KB
IMPLEMENTATION.md         ~25 KB
BUILD_GUTTERSYNTH.md      ~8 KB
IMPLEMENTATION_SUMMARY.md ~12 KB
```

---

## Backup Strategy

**Important files to backup:**
1. `src/*.dsp` - Source code
2. `docs/*.md` - Documentation
3. `build/Makefile` - Build configuration
4. `build/guttersynth.o` - Working binary (if tested)

**Backup command:**
```bash
tar -czf guttersynth_backup_$(date +%Y%m%d).tar.gz guttersynth_disting_port/
```

---

**Last Updated:** 2025-12-16
**Project:** Guttersynth for Disting NT v0.1
