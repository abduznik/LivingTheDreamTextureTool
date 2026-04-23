# Universal Texture Toolkit (UTT)

Universal Texture Toolkit is a professional graphics utility designed for hardware-accelerated bit-manipulation and processing of textures for Tegra-compatible hardware architectures.

## Core Engineering Challenges

### 1. Manual Texture Swizzling
One of the primary challenges addressed by UTT is the conversion between linear and block-linear (swizzled) memory layouts. The toolkit implements custom swizzling logic to handle the Tegra-specific block-linear layout, ensuring high-performance access and compatibility with hardware requirements.

### 2. Bit-Level Texture Encoding
UTT supports manual bit-level encoding and decoding for compressed texture formats:
- **BC1 (DXT1):** Optimized for low-memory footprint color textures.
- **BC3 (DXT5):** Used for textures requiring high-quality alpha channels.

The encoding process involves direct manipulation of block-based data structures to achieve optimal compression while maintaining visual fidelity.

### 3. Zstandard (Zstd) Integration
The toolkit manages assets compressed with the Zstandard algorithm. It provides high-performance decompression and compression pipelines to handle `.zs` wrapped texture files, balancing speed and compression ratio.

### 4. Advanced State Management with Riverpod
UTT utilizes **Riverpod** for robust, reactive state management. The architecture is designed to handle asynchronous file operations, directory scanning, and complex image processing pipelines while maintaining a clean, predictable UI state.

## Key Features
- **Generic Directory Processing:** Decoupled from specific emulator structures; works with any resource directory.
- **Setup Gate:** A streamlined initialization flow for professional workflows.
- **Hardware-Aware Layout Detection:** Automatically identifies layout parameters based on file size and header data.
- **Integrated Backup System:** Automatic timestamped backups for all modified assets.

## Technical Stack
- **Framework:** Flutter (Desktop)
- **Language:** Dart
- **State Management:** Riverpod (AsyncNotifier)
- **Graphics Logic:** Custom Swizzle & BC-Codec implementations
- **Compression:** Zstandard
