FROM python:3.12-alpine

WORKDIR /app

# Create non-root user/group (Alpine syntax)
RUN addgroup -S appgroup && \
    adduser -S -G appgroup -h /app appuser

COPY app/requirements.txt .

RUN pip install --no-cache-dir -r requirements.txt

COPY app/ .

RUN chown -R appuser:appgroup /app

USER appuser

EXPOSE 8000

CMD ["uvicorn", "main:app", "--host", "0.0.0.0", "--port", "8000"]

