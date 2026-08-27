from fastapi import FastAPI, HTTPException
from pydantic import BaseModel, Field


app = FastAPI(
    title="Number Reverser",
    description="A simple API that reverses integers.",
    version="1.0.0",
)


class NumberRequest(BaseModel):
    number: int = Field(..., description="Integer to reverse")


class NumberResponse(BaseModel):
    original: int
    reversed: int


def reverse_number(number: int) -> int:
    sign = -1 if number < 0 else 1
    digits = str(abs(number))
    reversed_digits = digits[::-1]

    return sign * int(reversed_digits)


@app.get("/health")
def health():
    return {"status": "healthy"}


@app.post("/reverse", response_model=NumberResponse)
def reverse(request: NumberRequest):
    try:
        reversed_number = reverse_number(request.number)

        return {
            "original": request.number,
            "reversed": reversed_number,
        }

    except (ValueError, OverflowError) as exc:
        raise HTTPException(
            status_code=400,
            detail="Invalid number",
        ) from exc
