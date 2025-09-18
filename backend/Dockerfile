FROM python:3.11-slim
WORKDIR /app
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt
# ARG PLANGENIE_CORS_ORIGINS=http://localhost:64358,http://localhost:51587
# ARG PLANGENIE_CORS_REGEX=^https?://localhost(:[0-9]+)?$
# ENV PLANGENIE_CORS_ORIGINS=${PLANGENIE_CORS_ORIGINS}
# ENV PLANGENIE_CORS_REGEX=${PLANGENIE_CORS_REGEX}
COPY . .
ENV PYTHONUNBUFFERED=1
CMD ["uvicorn", "main:app", "--host", "0.0.0.0", "--port", "8080"]
