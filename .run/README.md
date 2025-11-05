# IntelliJ IDEA / RustRover Run Configurations

This directory contains pre-configured run configurations for IntelliJ IDEA and RustRover IDEs.

## Available Configurations

### Service Configurations

- **Collector** - Run the collector service locally
- **Collector Debug** - Run collector with full debug settings
- **API** - Run the API service locally
- **CLI** - Run the CLI tool (with `--help` by default)

### Build Configurations

- **Build All** - Build all crates in the workspace
- **Build Release** - Build release version of all crates

### Test Configurations

- **All Tests** - Run all tests in the workspace
- **Collector Tests** - Run tests for the collector crate only

### Code Quality

- **Clippy** - Run Clippy linter with pedantic warnings

### Docker Configurations

- **Docker Compose Up** - Start all services with Docker Compose
- **Docker Compose Debug Up** - Start services in debug mode

## How to Use

### Automatic Detection

IntelliJ IDEA and RustRover will automatically detect these configurations when you open the project. They will appear in the run configuration dropdown in the top-right corner of the IDE.

### Manual Import

If configurations are not automatically detected:

1. Open **Run** → **Edit Configurations**
2. Click the **folder icon** (Import configurations from file)
3. Select configuration files from the `.run/` directory

### Running Configurations

**Method 1: Run Configuration Dropdown**
```
1. Click the dropdown in the top-right corner
2. Select the desired configuration
3. Click the Run (▶) or Debug (🐞) button
```

**Method 2: Run Menu**
```
1. Go to Run → Run...
2. Select configuration from the list
3. Press Enter
```

**Method 3: Keyboard Shortcuts**
```
Shift + F10  - Run selected configuration
Shift + F9   - Debug selected configuration
Ctrl + R     - Run (macOS)
Ctrl + D     - Debug (macOS)
```

## Configuration Details

### Environment Variables

All service configurations include essential environment variables:

```
RUST_LOG=debug
RUST_BACKTRACE=1
DATABASE_URL=postgresql://postgres:postgres@localhost:5432/llm_observatory
REDIS_URL=redis://:redis_password@localhost:6379/0
APP_HOST=0.0.0.0
ENVIRONMENT=development
```

### Debug Configurations

Debug configurations add:

```
RUST_BACKTRACE=full
DEBUG=true
```

### Prerequisites

Before running service configurations, ensure:

1. **Infrastructure is running:**
   ```bash
   docker-compose up -d
   ```

2. **Database is migrated:**
   ```bash
   cargo sqlx migrate run
   ```

3. **Dependencies are installed:**
   ```bash
   cargo build
   ```

## Customizing Configurations

### Editing Existing Configurations

1. **Open Run Configurations:**
   - Run → Edit Configurations
   - Or click dropdown → Edit Configurations

2. **Select configuration to edit**

3. **Modify settings:**
   - Command arguments
   - Environment variables
   - Working directory
   - Before launch tasks

4. **Click Apply and OK**

### Adding Custom Arguments

For CLI configuration:

1. Edit **CLI.run.xml** or modify in IDE
2. Change the command line:
   ```xml
   <option name="command" value="run --package llm-observatory-cli --bin llm-observatory-cli -- query list" />
   ```

### Creating New Configurations

**From Template:**
```
1. Run → Edit Configurations
2. Click "+" → Cargo Command
3. Fill in details:
   - Name: My Custom Config
   - Command: run --bin my-binary
   - Working directory: $PROJECT_DIR$
4. Set environment variables
5. Apply and OK
```

**From Existing Configuration:**
```
1. Right-click configuration in dropdown
2. Select "Copy Configuration"
3. Rename and modify as needed
```

## Debugging Features

### Setting Breakpoints

1. **Line Breakpoints:**
   - Click in the gutter (left margin)
   - Or press `Ctrl+F8` (Windows/Linux) or `Cmd+F8` (macOS)

2. **Conditional Breakpoints:**
   - Right-click on breakpoint
   - Select "Edit Breakpoint"
   - Add condition (e.g., `count > 10`)

3. **Exception Breakpoints:**
   - Run → View Breakpoints
   - Click "+" → Rust Exception Breakpoints
   - Configure panic conditions

### Debug Controls

```
F8         - Step Over
F7         - Step Into
Shift+F8   - Step Out
Alt+F9     - Run to Cursor
F9         - Resume Program
Ctrl+F2    - Stop
```

### Debug Windows

- **Variables** - View local variables and fields
- **Watches** - Add expressions to watch
- **Frames** - View call stack
- **Console** - View program output
- **Threads** - View and switch between threads

### Evaluate Expression

During debugging:
```
1. Select expression in code
2. Press Alt+F8
3. View result or modify variables
```

## Docker Integration

### Docker Compose Configurations

The Docker configurations use the IDE's Docker integration:

**Requirements:**
- Docker plugin enabled
- Docker daemon running
- Docker configured in IDE settings

**Features:**
- Start/stop services from IDE
- View logs in IDE console
- Attach to running containers
- Debug containerized applications

### Attaching to Container

1. Start containers with debug configuration
2. Run → Attach to Process
3. Filter by container name
4. Select process to attach

## Troubleshooting

### Configuration Not Found Error

**Problem:** "Configuration not found" when running

**Solution:**
```
1. File → Invalidate Caches → Invalidate and Restart
2. Ensure Cargo.toml is correct
3. Rebuild project (Ctrl+F9)
```

### Debugger Not Attaching

**Problem:** Debugger fails to start

**Solution:**
```
1. Check LLDB is installed: `lldb --version`
2. Verify debugger in settings:
   Settings → Build, Execution, Deployment → Debugger
3. Ensure binary is built with debug symbols
4. Try GDB as alternative debugger
```

### Environment Variables Not Loading

**Problem:** Configuration can't find database/redis

**Solution:**
```
1. Check Docker containers are running:
   docker-compose ps
2. Verify connection strings in configuration
3. Add .env file to project root
4. Check IDE's environment variable loading
```

### Binary Not Found

**Problem:** "Binary not found" error

**Solution:**
```
1. Build the project: cargo build
2. Verify binary exists: ls target/debug/
3. Check Cargo.toml has correct binary definitions
4. Run cargo clean && cargo build
```

## IDE-Specific Notes

### RustRover

RustRover has enhanced Rust support:
- Better code completion
- Integrated Cargo commands
- Native debugging integration
- Rust-specific refactorings

All configurations work out-of-the-box with RustRover.

### IntelliJ IDEA

IntelliJ IDEA requires the Rust plugin:
```
1. Settings → Plugins
2. Search "Rust"
3. Install "Rust" plugin
4. Restart IDE
```

### CLion

CLion can also use these configurations with the Rust plugin installed.

## Advanced Usage

### Compound Configurations

Create configurations that run multiple tasks:

```xml
<component name="ProjectRunConfigurationManager">
  <configuration name="Full Stack" type="CompoundRunConfigurationType">
    <toRun name="Docker Compose Up" type="docker-deploy" />
    <toRun name="Collector" type="CargoCommandRunConfiguration" />
    <toRun name="API" type="CargoCommandRunConfiguration" />
    <method v="2" />
  </configuration>
</component>
```

### Before Launch Tasks

Add tasks to run before main configuration:

```xml
<method v="2">
  <option name="CARGO.BUILD_TASK_PROVIDER" enabled="true" />
  <option name="RunConfigurationTask" enabled="true"
          run_configuration_name="Docker Compose Up" />
</method>
```

### Shared Configurations

Configurations in `.run/` are shared via Git. To create personal configurations:

1. Run → Edit Configurations
2. Create new configuration
3. Uncheck "Store as project file"
4. Configuration saved in `.idea/workspace.xml` (gitignored)

## Best Practices

1. **Start with infrastructure:**
   - Always run "Docker Compose Up" before services

2. **Use specific test configurations:**
   - Test individual crates instead of whole workspace for faster feedback

3. **Leverage debug configurations:**
   - Use debug configurations for development
   - Use release configurations for performance testing

4. **Customize for your workflow:**
   - Copy and modify configurations for specific use cases
   - Use compound configurations for common workflows

5. **Keep configurations up-to-date:**
   - Update when adding new services
   - Document custom configurations
   - Share useful configurations with team

## Additional Resources

- [IntelliJ IDEA Documentation](https://www.jetbrains.com/help/idea/)
- [RustRover Documentation](https://www.jetbrains.com/help/rust/)
- [Rust Plugin Guide](https://plugins.jetbrains.com/plugin/8182-rust)
- [Project DEBUGGING.md](../docs/DEBUGGING.md) - Comprehensive debugging guide

## Contributing

When adding new services or features:

1. Create corresponding run configuration
2. Place in `.run/` directory
3. Update this README
4. Test configuration works for fresh clone
5. Commit configuration to repository

---

**Last Updated:** 2025-11-05
