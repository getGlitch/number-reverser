from fastapi.testclient import TestClient

from app.main import app, reverse_number

client = TestClient(app)


def test_reverse_positive_number():
    assert reverse_number(12345) == 54321


def test_reverse_negative_number():
    assert reverse_number(-12345) == -54321


def test_reverse_number_with_trailing_zeros():
    assert reverse_number(1200) == 21


def test_reverse_zero():
    assert reverse_number(0) == 0


def test_reverse_single_digit():
    assert reverse_number(7) == 7


def test_reverse_large_integer():
    large_number = 123456789012345678901234567890
    expected = 98765432109876543210987654321

    assert reverse_number(large_number) == expected


def test_health_endpoint():
    response = client.get("/health")

    assert response.status_code == 200
    assert response.json() == {"status": "Tera Bhai Healthy Hai"}


def test_reverse_endpoint():
    response = client.post(
        "/reverse",
        json={"number": 12345},
    )

    assert response.status_code == 200
    assert response.json() == {
        "original": 12345,
        "reversed": 54321,
    }


def test_reverse_negative_number_endpoint():
    response = client.post(
        "/reverse",
        json={"number": -12345},
    )

    assert response.status_code == 200
    assert response.json() == {
        "original": -12345,
        "reversed": -54321,
    }


def test_reverse_number_with_trailing_zeros_endpoint():
    response = client.post(
        "/reverse",
        json={"number": 1200},
    )

    assert response.status_code == 200
    assert response.json() == {
        "original": 1200,
        "reversed": 21,
    }


def test_non_numeric_input():
    response = client.post(
        "/reverse",
        json={"number": "hello"},
    )

    assert response.status_code == 422
