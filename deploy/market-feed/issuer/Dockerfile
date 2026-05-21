FROM python:3.12-slim

WORKDIR /app

ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1

COPY app.py /app/app.py

EXPOSE 8090

CMD ["python", "/app/app.py"]
