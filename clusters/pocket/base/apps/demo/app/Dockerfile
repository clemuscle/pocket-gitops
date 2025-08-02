FROM python:3.12-slim
WORKDIR /code
COPY app/ ./app
RUN pip install fastapi uvicorn
CMD ["uvicorn", "app.main:app", "--host", "0.0.0.0", "--port", "8000"]
