# Contributing to Klime Elixir SDK

Thank you for your interest in contributing to the Klime Elixir SDK!

## Important: Repository Structure

This repository is a **read-only mirror** of our internal monorepo. We develop and maintain the SDK internally, then mirror releases to this public repository.

### What This Means for Contributors

- **Pull requests are welcome** and will be reviewed by our team
- If accepted, we'll **manually port your changes** to our internal monorepo
- Your changes will appear in this repository with the **next release**
- You'll be credited as a co-author in the commit

## How to Contribute

### Reporting Bugs

1. Check if the bug has already been reported in [Issues](../../issues)
2. If not, create a new issue with:
   - A clear, descriptive title
   - Steps to reproduce the bug
   - Expected vs actual behavior
   - Your environment (Elixir version, OTP version, OS, etc.)
   - Any relevant code snippets or error messages

### Suggesting Features

1. Check if the feature has already been suggested in [Issues](../../issues)
2. Create a new issue describing:
   - The problem you're trying to solve
   - Your proposed solution
   - Any alternatives you've considered

### Submitting Code Changes

1. Fork this repository
2. Create a feature branch (`git checkout -b feat/amazing-feature`)
3. Make your changes
4. Write or update tests as needed
5. Ensure all tests pass (`mix test`)
6. Run the formatter (`mix format`)
7. Commit using [Conventional Commits](https://www.conventionalcommits.org/):
   ```
   feat: add new tracking method
   fix: handle edge case in batch processing
   docs: update README examples
   ```
8. Push to your fork and open a Pull Request

### Pull Request Guidelines

- Provide a clear description of what the PR does
- Reference any related issues
- Include tests for new functionality
- Update documentation if needed
- Keep PRs focused - one feature or fix per PR

## Development Setup

```bash
# Clone your fork
git clone https://github.com/YOUR_USERNAME/klime-elixir.git
cd klime-elixir

# Install dependencies
mix deps.get

# Run tests
mix test

# Run formatter
mix format

# Generate docs (optional)
mix docs
```

## Project Structure

```
klime-elixir/
├── lib/
│   ├── klime.ex              # Main entry point / public API
│   └── klime/
│       ├── client.ex         # GenServer client implementation
│       ├── event.ex          # Event struct and serialization
│       ├── event_context.ex  # Context and library info
│       ├── batch_response.ex # Response parsing
│       └── config.ex         # Default configuration
├── test/
│   ├── klime/
│   │   ├── client_test.exs   # Integration tests
│   │   └── event_test.exs    # Unit tests
│   └── test_helper.exs
├── mix.exs                   # Project configuration
└── README.md
```

## Code Style

- We follow standard Elixir conventions
- Use `mix format` to format your code
- Add `@moduledoc` and `@doc` documentation for public APIs
- Use typespecs (`@type`, `@spec`) for public functions
- Keep functions small and focused

## Running Tests

```bash
# Run all tests
mix test

# Run specific test file
mix test test/klime/client_test.exs

# Run with coverage
mix test --cover
```

## Questions?

If you have questions about contributing, feel free to open an issue and we'll be happy to help!

## License

By contributing, you agree that your contributions will be licensed under the MIT License.
