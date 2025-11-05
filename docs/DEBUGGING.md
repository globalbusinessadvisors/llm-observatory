# Debugging Guide for LLM Observatory

This comprehensive guide covers debugging techniques, tools, and workflows for the LLM Observatory project.

## Table of Contents

- [Quick Start](#quick-start)
- [IDE Setup](#ide-setup)
  - [Visual Studio Code](#visual-studio-code)
  - [IntelliJ IDEA / RustRover](#intellij-idea--rustrover)
  - [Neovim / Terminal](#neovim--terminal)
- [Debugging Strategies](#debugging-strategies)
  - [Local Debugging](#local-debugging)
  - [Container Debugging](#container-debugging)
  - [Remote Debugging](#remote-debugging)
- [Common Debugging Scenarios](#common-debugging-scenarios)
- [Performance Profiling](#performance-profiling)
- [Troubleshooting](#troubleshooting)
- [Tools Reference](#tools-reference)

---

## Quick Start

### Prerequisites

1. **Install debugging tools:**
   ```bash
   # Install LLDB (recommended for Rust)
   # macOS (comes with Xcode Command Line Tools)
   xcode-select --install

   # Ubuntu/Debian
   sudo apt-get install lldb

   # Arch Linux
   sudo pacman -S lldb
   ```

2. **Install VSCode extensions:**
   ```bash
   code --install-extension rust-lang.rust-analyzer
   code --install-extension vadimcn.vscode-lldb
   code --install-extension ms-azuretools.vscode-docker
   ```

3. **Build with debug symbols:**
   ```bash
   cargo build --workspace
   # Or use the release-with-debug profile
   cargo build --profile=release-with-debug
   ```

### Quick Debug Session

1. **Start infrastructure:**
   ```bash
   docker-compose up -d
   ```

2. **Open VSCode and press `F5`** or:
   - Press `Ctrl+Shift+D` (View: Debug)
   - Select "Debug Collector (Standalone)"
   - Press `F5` or click "Start Debugging"

3. **Set breakpoints** by clicking in the gutter next to line numbers

4. **Use debug controls:**
   - `F5` - Continue
   - `F10` - Step Over
   - `F11` - Step Into
   - `Shift+F11` - Step Out
   - `Ctrl+Shift+F5` - Restart
   - `Shift+F5` - Stop

---

## IDE Setup

### Visual Studio Code

#### Debug Configurations

We provide multiple debug configurations in `.vscode/launch.json`:

1. **Standalone Service Debugging**
   - `Debug Collector (Standalone)` - Debug collector with local infrastructure
   - `Debug API (Standalone)` - Debug API server with local infrastructure
   - `Debug CLI` - Debug command-line interface

2. **Test Debugging**
   - `Debug Unit Tests (Current Crate)` - Debug specific unit tests
   - `Debug All Tests (Workspace)` - Debug all tests in workspace
   - `Debug Integration Tests` - Debug integration tests with Docker

3. **Container Debugging**
   - `Attach to Collector Container` - Attach to running container
   - `Remote Debug (Docker)` - Remote debugging via LLDB server

4. **Specialized Debugging**
   - `Debug Benchmarks` - Debug performance benchmarks
   - `Debug Example` - Debug example code

#### Setting Breakpoints

**Line Breakpoints:**
```
1. Click in the gutter (left of line numbers)
2. Or press F9 on the desired line
3. Red dot indicates active breakpoint
```

**Conditional Breakpoints:**
```
1. Right-click in gutter
2. Select "Add Conditional Breakpoint"
3. Enter condition, e.g., `user_id == 42`
```

**Logpoints:**
```
1. Right-click in gutter
2. Select "Add Logpoint"
3. Enter message, e.g., `User {user_id} processed`
```

**Function Breakpoints:**
```
1. In Debug view, click "+" under BREAKPOINTS
2. Enter function name, e.g., `process_request`
```

#### Inspecting Variables

**Watch Expressions:**
```
1. In Debug view, expand WATCH section
2. Click "+" to add expression
3. Enter variable name or expression
```

**Debug Console:**
```
1. Press Ctrl+Shift+Y to open Debug Console
2. Evaluate expressions:
   - `p variable_name` - Print variable
   - `p/x 42` - Print in hexadecimal
   - `fr v` - Show frame variables
```

**Variable Hover:**
```
1. Hover over variable in editor
2. View value and type information
3. Expand structures to see fields
```

#### Tasks

Use tasks from `.vscode/tasks.json`:

**Build Tasks:**
- `Ctrl+Shift+B` - Run default build task
- `Ctrl+P` → `task cargo-build-all` - Build all crates
- `Ctrl+P` → `task cargo-build-collector` - Build collector only

**Test Tasks:**
- `Ctrl+P` → `task cargo-test-all` - Run all tests
- `Ctrl+P` → `task cargo-test-integration` - Run integration tests

**Docker Tasks:**
- `Ctrl+P` → `task docker-compose-up` - Start services
- `Ctrl+P` → `task docker-compose-debug-up` - Start debug services
- `Ctrl+P` → `task docker-compose-logs` - View logs

**Combined Tasks:**
- `Ctrl+P` → `task dev-setup` - Complete development setup
- `Ctrl+P` → `task ci-check` - Run CI checks locally

### IntelliJ IDEA / RustRover

#### Setup

1. **Install Rust plugin:**
   - File → Settings → Plugins
   - Search for "Rust"
   - Install and restart

2. **Import run configurations:**
   ```bash
   # Configurations are in .run/ directory
   # RustRover will auto-detect them
   ```

3. **Configure debugger:**
   - Settings → Build, Execution, Deployment → Debugger
   - Select LLDB as default debugger

#### Run Configurations

See `.run/` directory for pre-configured run configurations:

- `Collector.run.xml` - Run collector service
- `API.run.xml` - Run API service
- `Tests.run.xml` - Run all tests
- `Collector Debug.run.xml` - Debug collector with LLDB

#### Debugging Features

**Start Debug Session:**
```
1. Select run configuration from dropdown
2. Click debug icon (bug) or press Shift+F9
3. Set breakpoints by clicking in gutter
```

**Advanced Breakpoints:**
```
1. Right-click breakpoint
2. Configure:
   - Condition: Only break if condition is true
   - Log: Print message without stopping
   - Pass count: Break after N hits
```

**Evaluate Expression:**
```
1. During debug, select expression
2. Press Alt+F8 or right-click → Evaluate
3. View result and modify variables
```

**Frame Navigation:**
```
1. View call stack in Frames panel
2. Click frame to jump to that context
3. View local variables for each frame
```

### Neovim / Terminal

#### Using LLDB Directly

**Start debugging:**
```bash
# Build with debug symbols
cargo build --bin llm-observatory-collector

# Start LLDB
lldb target/debug/llm-observatory-collector

# Set breakpoints
(lldb) b main.rs:42
(lldb) b process_request

# Run
(lldb) run

# When stopped:
(lldb) bt              # Backtrace
(lldb) fr v            # Frame variables
(lldb) p variable      # Print variable
(lldb) c               # Continue
(lldb) n               # Next line
(lldb) s               # Step into
```

#### Debugging with rust-lldb

```bash
# Use rust-lldb wrapper for better Rust support
rust-lldb target/debug/llm-observatory-collector

# Or with arguments
rust-lldb -- target/debug/llm-observatory-collector --config config.toml
```

#### Using GDB (Alternative)

```bash
# Build and run with GDB
rust-gdb target/debug/llm-observatory-collector

# GDB commands (similar to LLDB)
(gdb) break main.rs:42
(gdb) run
(gdb) backtrace
(gdb) print variable
(gdb) continue
(gdb) next
(gdb) step
```

#### Neovim Integration

**Using nvim-dap:**

```lua
-- Install nvim-dap and nvim-dap-ui
-- Add to your init.lua:

local dap = require('dap')
dap.adapters.lldb = {
  type = 'executable',
  command = '/usr/bin/lldb-vscode',
  name = 'lldb'
}

dap.configurations.rust = {
  {
    name = 'Launch',
    type = 'lldb',
    request = 'launch',
    program = function()
      return vim.fn.input('Path to executable: ', vim.fn.getcwd() .. '/target/debug/', 'file')
    end,
    cwd = '${workspaceFolder}',
    stopOnEntry = false,
    args = {},
  },
}

-- Keybindings
vim.keymap.set('n', '<F5>', require('dap').continue)
vim.keymap.set('n', '<F10>', require('dap').step_over)
vim.keymap.set('n', '<F11>', require('dap').step_into)
vim.keymap.set('n', '<F12>', require('dap').step_out)
vim.keymap.set('n', '<Leader>b', require('dap').toggle_breakpoint)
```

---

## Debugging Strategies

### Local Debugging

**When to use:**
- Developing new features
- Testing specific code paths
- Quick iteration cycles

**Setup:**
```bash
# 1. Start infrastructure
docker-compose up -d timescaledb redis

# 2. Set environment variables
cp .env.example .env
# Edit .env with local database URLs

# 3. Run migrations
cargo sqlx migrate run

# 4. Start debugging in IDE (F5 in VSCode)
```

**Advantages:**
- Fast compilation
- Direct breakpoint debugging
- Full IDE integration
- Easy variable inspection

**Disadvantages:**
- May not match production environment
- Platform-specific issues may not surface

### Container Debugging

**When to use:**
- Debugging deployment issues
- Testing production-like environment
- Investigating platform-specific bugs

**Method 1: Attach to Running Container**

```bash
# 1. Start services in debug mode
docker-compose -f docker-compose.yml -f docker-compose.debug.yml up --build

# 2. Find the process ID
docker exec llm-observatory-collector-debug ps aux

# 3. In VSCode:
#    - Select "Attach to Collector Container"
#    - Choose the process from the list
```

**Method 2: Remote Debugging with LLDB Server**

```bash
# 1. Start container with lldb-server
docker-compose -f docker-compose.debug.yml up collector

# 2. The service will listen on port 2345

# 3. In VSCode:
#    - Select "Remote Debug (Docker)"
#    - Debugger will connect to localhost:2345
```

**Method 3: Debug Container Shell**

```bash
# Start debug tools container
docker-compose --profile debug-tools up -d debug-tools

# Enter the container
docker exec -it llm-observatory-debug-tools bash

# Build and debug
cd /workspace
cargo build
rust-lldb target/debug/llm-observatory-collector
```

### Remote Debugging

**When to use:**
- Debugging in staging/production
- Investigating issues that only occur in specific environments

**Setup Remote LLDB Server:**

```bash
# On remote host
lldb-server platform --listen "*:2345" --server

# On local machine in VSCode:
# Use "Remote Debug (Docker)" configuration
# Update the connection string in launch.json if needed
```

**Security Considerations:**
- Only enable remote debugging in non-production environments
- Use SSH tunneling for secure connections:
  ```bash
  ssh -L 2345:localhost:2345 user@remote-host
  ```
- Disable remote debugging after troubleshooting

---

## Common Debugging Scenarios

### Scenario 1: Service Crashes on Startup

**Symptoms:**
- Service exits immediately
- Error messages in logs
- No response on health check

**Debug Steps:**

1. **Check logs:**
   ```bash
   docker-compose logs collector
   ```

2. **Enable backtrace:**
   ```bash
   RUST_BACKTRACE=full cargo run --bin llm-observatory-collector
   ```

3. **Debug initialization:**
   - Set breakpoint in `main()` function
   - Step through initialization code
   - Check configuration loading
   - Verify database connection

4. **Common issues:**
   - Missing environment variables
   - Database not ready
   - Port already in use
   - Invalid configuration

### Scenario 2: Request Hangs

**Symptoms:**
- Request never completes
- No response or timeout
- High CPU usage

**Debug Steps:**

1. **Attach debugger and pause:**
   ```bash
   # In LLDB
   (lldb) process attach --pid <PID>
   (lldb) process interrupt
   (lldb) bt all  # Backtrace all threads
   ```

2. **Check async runtime:**
   ```bash
   # Enable tokio-console
   RUSTFLAGS="--cfg tokio_unstable" cargo build
   tokio-console
   ```

3. **Identify blocking code:**
   - Look for synchronous operations in async context
   - Check for missing `.await`
   - Verify timeout configurations

4. **Use conditional breakpoint:**
   ```rust
   // Set breakpoint with condition
   // Condition: request_id == "<stuck_request_id>"
   ```

### Scenario 3: Memory Leak

**Symptoms:**
- Memory usage grows continuously
- Container OOM killed
- Performance degradation

**Debug Steps:**

1. **Enable memory profiling:**
   ```bash
   # Using valgrind
   valgrind --leak-check=full --show-leak-kinds=all \
     target/debug/llm-observatory-collector
   ```

2. **Use heap profiler:**
   ```bash
   # Install heaptrack
   heaptrack target/debug/llm-observatory-collector
   heaptrack_gui heaptrack.collector.*.gz
   ```

3. **Check for:**
   - Unclosed database connections
   - Retained HTTP client references
   - Growing caches without eviction
   - Circular references in Arc/Rc

4. **Monitor allocations:**
   ```rust
   // Add to code
   #[global_allocator]
   static GLOBAL: jemallocator::Jemalloc = jemallocator::Jemalloc;
   ```

### Scenario 4: Database Query Issues

**Symptoms:**
- Slow queries
- Query failures
- Connection pool exhausted

**Debug Steps:**

1. **Enable query logging:**
   ```bash
   # In .env
   DB_QUERY_LOGGING=true
   RUST_LOG=sqlx=debug
   ```

2. **Check query execution:**
   - Set breakpoint before query
   - Inspect SQL string
   - Verify parameters
   - Check connection pool stats

3. **Analyze with database logs:**
   ```bash
   # Enable PostgreSQL logging
   docker-compose -f docker-compose.debug.yml up
   # Check logs
   docker-compose logs timescaledb | grep STATEMENT
   ```

4. **Use pgAdmin:**
   ```bash
   docker-compose --profile admin up pgadmin
   # Open http://localhost:5050
   # Analyze query plans and execution
   ```

### Scenario 5: Race Conditions

**Symptoms:**
- Intermittent failures
- Data corruption
- Non-deterministic behavior

**Debug Steps:**

1. **Add logging:**
   ```rust
   tracing::debug!("Thread {:?}: Starting operation", thread::current().id());
   ```

2. **Use thread sanitizer:**
   ```bash
   RUSTFLAGS="-Z sanitizer=thread" cargo +nightly run
   ```

3. **Conditional breakpoints on shared state:**
   - Break when counter reaches specific value
   - Break when flag changes unexpectedly

4. **Reproduce with controlled concurrency:**
   ```rust
   #[tokio::test(flavor = "multi_thread", worker_threads = 2)]
   async fn test_concurrent_access() {
       // Simplified test case
   }
   ```

### Scenario 6: Performance Bottleneck

**Symptoms:**
- High latency
- Low throughput
- CPU/IO bottleneck

**Debug Steps:**

1. **Profile with flamegraph:**
   ```bash
   cargo install flamegraph
   cargo flamegraph --bin llm-observatory-collector
   ```

2. **Use async profiling:**
   ```bash
   # Enable tokio-console
   docker-compose --profile tokio-console up tokio-console
   # Open in browser
   ```

3. **Set breakpoints strategically:**
   - Before expensive operations
   - Inside hot loops
   - At async boundaries

4. **Measure specific sections:**
   ```rust
   let start = Instant::now();
   expensive_operation().await;
   tracing::info!("Operation took {:?}", start.elapsed());
   ```

---

## Performance Profiling

### CPU Profiling

**Using perf (Linux):**

```bash
# Record performance data
perf record --call-graph dwarf \
  target/release/llm-observatory-collector

# Analyze results
perf report

# Generate flamegraph
perf script | stackcollapse-perf.pl | flamegraph.pl > flame.svg
```

**Using cargo-flamegraph:**

```bash
cargo install flamegraph
cargo flamegraph --bin llm-observatory-collector

# Opens flamegraph in browser
# Red regions indicate hot code paths
```

### Memory Profiling

**Using heaptrack:**

```bash
# Install heaptrack
sudo apt-get install heaptrack heaptrack-gui

# Profile application
heaptrack target/release/llm-observatory-collector

# Analyze results
heaptrack_gui heaptrack.collector.*.gz
```

**Using valgrind:**

```bash
valgrind --tool=massif --massif-out-file=massif.out \
  target/debug/llm-observatory-collector

# Visualize
ms_print massif.out
```

### Async Runtime Profiling

**Using tokio-console:**

```bash
# 1. Enable tokio unstable features
export RUSTFLAGS="--cfg tokio_unstable"

# 2. Rebuild with console subscriber
cargo build --features tokio-console

# 3. Start application
target/debug/llm-observatory-collector

# 4. In another terminal, start console
tokio-console

# Features:
# - Task list with state
# - Task details and history
# - Async call graph
# - Resource usage
```

### Database Profiling

**Query Performance:**

```sql
-- Enable timing
\timing on

-- Explain query
EXPLAIN ANALYZE
SELECT * FROM traces WHERE service_name = 'collector';

-- Check slow queries
SELECT * FROM pg_stat_statements
ORDER BY mean_exec_time DESC
LIMIT 10;
```

**Connection Pool Monitoring:**

```rust
// In code
let pool_status = pool.status();
tracing::info!(
    "Pool - size: {}, idle: {}, waiting: {}",
    pool_status.size,
    pool_status.idle,
    pool_status.waiting
);
```

---

## Troubleshooting

### Debugger Won't Connect

**Problem:** VSCode shows "Could not start debugger"

**Solutions:**

1. **Check LLDB installation:**
   ```bash
   lldb --version
   ```

2. **Verify CodeLLDB extension:**
   ```bash
   code --list-extensions | grep vadimcn.vscode-lldb
   ```

3. **Check binary exists:**
   ```bash
   ls -l target/debug/llm-observatory-collector
   ```

4. **Rebuild with debug symbols:**
   ```bash
   cargo clean
   cargo build
   ```

### Breakpoints Not Hit

**Problem:** Breakpoint shows as grayed out or not triggering

**Solutions:**

1. **Verify file is being compiled:**
   ```bash
   cargo build -v | grep your_file.rs
   ```

2. **Check optimization level:**
   ```toml
   # In Cargo.toml [profile.dev]
   opt-level = 0  # No optimization
   debug = true   # Full debug info
   ```

3. **Disable inlining:**
   ```rust
   #[inline(never)]
   fn your_function() {
       // Function won't be inlined
   }
   ```

4. **Rebuild and restart debugger**

### Variables Show "Optimized Out"

**Problem:** Cannot inspect variable values

**Solutions:**

1. **Use debug profile:**
   ```bash
   cargo build --profile=dev
   ```

2. **Or use release-with-debug:**
   ```bash
   cargo build --profile=release-with-debug
   ```

3. **Disable optimizations for specific crate:**
   ```toml
   [profile.release.package.your-crate]
   opt-level = 0
   ```

### Container Debugging Issues

**Problem:** Cannot attach to container process

**Solutions:**

1. **Enable ptrace capability:**
   ```yaml
   # In docker-compose.debug.yml
   cap_add:
     - SYS_PTRACE
   security_opt:
     - seccomp:unconfined
   ```

2. **Check process is running:**
   ```bash
   docker exec llm-observatory-collector-debug ps aux
   ```

3. **Verify debug port is exposed:**
   ```bash
   docker ps | grep collector-debug
   ```

4. **Check firewall rules:**
   ```bash
   sudo iptables -L | grep 2345
   ```

### Source Maps Not Working

**Problem:** Debugger shows assembly instead of source

**Solutions:**

1. **Mount source code in container:**
   ```yaml
   volumes:
     - ./crates:/usr/src/app/crates:ro
   ```

2. **Configure source map in launch.json:**
   ```json
   "sourceMap": {
     "/usr/src/app": "${workspaceFolder}"
   }
   ```

3. **Verify paths match:**
   ```bash
   # In container
   docker exec llm-observatory-collector-debug pwd
   ```

---

## Tools Reference

### Essential Tools

| Tool | Purpose | Installation |
|------|---------|--------------|
| LLDB | Primary Rust debugger | `apt-get install lldb` |
| rust-lldb | Rust-aware LLDB wrapper | Comes with Rust toolchain |
| GDB | Alternative debugger | `apt-get install gdb` |
| rust-gdb | Rust-aware GDB wrapper | Comes with Rust toolchain |
| valgrind | Memory debugging | `apt-get install valgrind` |
| heaptrack | Heap profiler | `apt-get install heaptrack` |
| perf | CPU profiler (Linux) | `apt-get install linux-tools-common` |
| flamegraph | Visualization tool | `cargo install flamegraph` |
| tokio-console | Async runtime inspector | `cargo install tokio-console` |

### VSCode Extensions

```bash
# Essential extensions
code --install-extension rust-lang.rust-analyzer
code --install-extension vadimcn.vscode-lldb
code --install-extension ms-azuretools.vscode-docker

# Helpful extensions
code --install-extension serayuzgur.crates
code --install-extension tamasfe.even-better-toml
code --install-extension usernamehw.errorlens
```

### Cargo Tools

```bash
# Development tools
cargo install cargo-watch    # Auto-rebuild on changes
cargo install cargo-expand   # Expand macros
cargo install cargo-tree     # Dependency tree
cargo install cargo-audit    # Security vulnerabilities
cargo install cargo-outdated # Outdated dependencies

# Performance tools
cargo install flamegraph
cargo install cargo-bloat    # Binary size analysis
cargo install tokio-console

# Test tools
cargo install cargo-nextest  # Better test runner
cargo install cargo-tarpaulin # Code coverage
```

### Debug Environment Variables

```bash
# Logging
RUST_LOG=debug              # Enable debug logging
RUST_LOG=trace              # Enable trace logging
RUST_LOG=module=debug       # Log specific module

# Backtraces
RUST_BACKTRACE=1           # Enable backtraces
RUST_BACKTRACE=full        # Full backtraces with line numbers

# Tokio
TOKIO_CONSOLE=1            # Enable tokio-console
RUSTFLAGS="--cfg tokio_unstable"  # Required for tokio-console

# Memory
RUST_MIN_STACK=8388608     # Set minimum stack size

# Compiler
RUSTC_BOOTSTRAP=1          # Enable nightly features on stable
```

---

## Additional Resources

### Documentation

- [Rust Debugging in VSCode](https://code.visualstudio.com/docs/languages/rust)
- [LLDB Tutorial](https://lldb.llvm.org/use/tutorial.html)
- [Tokio Console](https://github.com/tokio-rs/console)
- [Rust Performance Book](https://nnethercote.github.io/perf-book/)

### Community

- [Rust Users Forum](https://users.rust-lang.org/)
- [Rust Discord](https://discord.gg/rust-lang)
- [Stack Overflow - Rust Tag](https://stackoverflow.com/questions/tagged/rust)

### Project-Specific

- See `CONTRIBUTING.md` for development workflow
- See `README.md` for project overview
- Join our Discord for support: [Link TBD]

---

## Contributing

Found an issue with this guide or have suggestions? Please open an issue or PR at:
https://github.com/llm-observatory/llm-observatory/issues

---

**Last Updated:** 2025-11-05
**Maintainers:** LLM Observatory Team
