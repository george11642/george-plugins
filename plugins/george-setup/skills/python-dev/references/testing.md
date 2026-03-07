# Python Testing Patterns

## Test Structure (AAA Pattern)

```python
def test_user_creation():
    # Arrange
    user_data = {"name": "Alice", "email": "alice@example.com"}
    # Act
    user = create_user(user_data)
    # Assert
    assert user.name == "Alice"
```

## Fixtures

```python
@pytest.fixture
def db() -> Generator[Database, None, None]:
    database = Database("sqlite:///:memory:")
    database.connect()
    yield database
    database.disconnect()

@pytest.fixture(scope="session")
def app_config():
    return {"database_url": "postgresql://localhost/test", "debug": True}

# Parametrized fixture - test runs once per param
@pytest.fixture(params=["sqlite", "postgresql", "mysql"])
def db_backend(request):
    return request.param
```

## Parametrize

```python
@pytest.mark.parametrize("email,expected", [
    ("user@example.com", True),
    ("invalid.email", False),
    pytest.param("", False, id="empty-string"),
])
def test_email_validation(email, expected):
    assert is_valid_email(email) == expected
```

## Mocking

```python
# Context manager style
with patch("requests.get", return_value=mock_response) as mock_get:
    result = client.get_user(1)
    mock_get.assert_called_once_with("https://api.example.com/users/1")

# Decorator style
@patch("requests.post")
def test_create_user(mock_post):
    mock_post.return_value.json.return_value = {"id": 2}
    mock_post.return_value.raise_for_status.return_value = None
    result = client.create_user(data)
    mock_post.assert_called_once()
```

## Exception Testing

```python
def test_division_by_zero():
    with pytest.raises(ZeroDivisionError, match="Division by zero"):
        divide(5, 0)

def test_exception_info():
    with pytest.raises(ValueError) as exc_info:
        int("not a number")
    assert "invalid literal" in str(exc_info.value)
```

## Async Tests

```python
@pytest.mark.asyncio
async def test_fetch_data():
    result = await fetch_data("https://api.example.com")
    assert result["url"] == "https://api.example.com"

@pytest.mark.asyncio
async def test_concurrent():
    results = await asyncio.gather(*[fetch(url) for url in urls])
    assert len(results) == 3
```

## Monkeypatch

```python
def test_custom_env(monkeypatch):
    monkeypatch.setenv("DATABASE_URL", "postgresql://localhost/test")
    assert get_database_url() == "postgresql://localhost/test"

def test_attribute(monkeypatch):
    monkeypatch.setattr(config, "api_key", "test-key")
    assert config.get_api_key() == "test-key"
```

## Temp Files

```python
def test_file_ops(tmp_path):
    test_file = tmp_path / "test.txt"
    test_file.write_text("Hello")
    assert test_file.read_text() == "Hello"
```

## Markers

```python
@pytest.mark.slow
@pytest.mark.integration
@pytest.mark.skip(reason="Not implemented")
@pytest.mark.skipif(os.name == "nt", reason="Unix only")
@pytest.mark.xfail(reason="Known bug #123")
# Run: pytest -m slow / pytest -m "not slow"
```

## Property-Based Testing

```python
from hypothesis import given, strategies as st

@given(st.text())
def test_reverse_twice(s):
    assert reverse(reverse(s)) == s

@given(st.lists(st.integers()))
def test_sorted_properties(lst):
    sorted_lst = sorted(lst)
    assert len(sorted_lst) == len(lst)
    assert all(sorted_lst[i] <= sorted_lst[i+1] for i in range(len(sorted_lst)-1))
```

## Configuration (pyproject.toml)

```toml
[tool.pytest.ini_options]
testpaths = ["tests"]
addopts = ["-v", "--cov=myapp", "--cov-report=term-missing"]
markers = ["slow: slow tests", "integration: integration tests"]

[tool.coverage.run]
source = ["myapp"]
omit = ["*/tests/*", "*/migrations/*"]
```

## Test Organization

```
tests/
  conftest.py           # Shared fixtures
  test_unit/
    test_models.py
  test_integration/
    test_api.py
  test_e2e/
    test_workflows.py
```

## Best Practices

1. One assertion concept per test (multiple asserts OK if testing same behavior)
2. Descriptive names: `test_login_fails_with_invalid_password`
3. Keep tests independent - no shared mutable state
4. Use fixtures for setup/teardown, not setUp/tearDown methods
5. Mock at boundaries (external APIs, databases, file system)
6. Parametrize to cover edge cases without code duplication
7. Use `conftest.py` for shared fixtures across test modules
8. Measure coverage but prioritize meaningful tests over percentage
