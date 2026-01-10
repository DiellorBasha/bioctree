# Contributing to Bioctree

Thank you for your interest in contributing to Bioctree! This document provides guidelines for contributions.

## How to Contribute

### Reporting Bugs

1. **Check existing issues** on GitHub
2. **Create detailed bug report** including:
   - MATLAB version
   - Bioctree version
   - Minimal reproducible example
   - Error messages
   - Expected vs. actual behavior

### Suggesting Features

1. **Open feature request** on GitHub Issues
2. **Describe use case** and why it's valuable
3. **Provide examples** if possible

### Contributing Code

1. **Fork the repository**
2. **Create feature branch**: `git checkout -b feature/my-feature`
3. **Make changes** following coding standards (below)
4. **Add tests** for new functionality
5. **Run tests**: Ensure all tests pass
6. **Commit**: Use clear commit messages
7. **Push**: `git push origin feature/my-feature`
8. **Create Pull Request** on GitHub

## Coding Standards

### MATLAB Code Style

```matlab
% Use clear variable names
num_vertices = size(V, 1);  % Good
n = size(V, 1);             % Avoid

% Add comments for complex logic
% Compute cotangent weights for Laplace-Beltrami operator
weights = compute_cotangent_weights(V, F);

% Use consistent indentation (4 spaces)
function result = myFunction(input)
    if condition
        result = processData(input);
    else
        result = defaultValue;
    end
end
```

### Class Structure

- Follow `+bct` package structure
- Inherit from `bct.Domain` for domain classes
- Use dependency injection (pass dependencies as arguments)
- Write docstrings for all public methods

### Documentation

- Update relevant `.md` files in `docs/`
- Add examples for new features
- Include mathematical notation using LaTeX (MathJax)
- Update API reference

### Testing

- Add tests in `tests/` directory
- Use `matlab.unittest` framework
- Test edge cases and error conditions
- Maintain test coverage > 80%

## Development Setup

```matlab
% Clone repository
git clone https://github.com/DiellorBasha/bioctree.git
cd bioctree

% Initialize
bioctree_start

% Run tests
runtests('tests/')
```

## Pull Request Process

1. **Update documentation** for any changed functionality
2. **Add tests** that cover your changes
3. **Ensure tests pass** before submitting
4. **Update CHANGELOG.md** with your changes
5. **Request review** from maintainers

## Code Review

All submissions require review. We use GitHub pull requests for this purpose.

**Reviewers check for**:
- Code quality and style
- Test coverage
- Documentation completeness
- Performance implications
- Backwards compatibility

## Questions?

- **GitHub Discussions**: Ask questions
- **Email**: diellor.basha@example.com
- **Issues**: Report problems

## License

By contributing, you agree that your contributions will be licensed under the MIT License.

---

Thank you for making Bioctree better! 🎉
