FROM python:3.11-slim

WORKDIR /app

COPY . /app

EXPOSE 8081

CMD ["python", "-m", "http.server", "8081", "--directory", "/app/web"]
