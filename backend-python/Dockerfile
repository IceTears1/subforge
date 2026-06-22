FROM python:3.11-alpine

WORKDIR /app

# Copy requirements
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# Copy application files
COPY . .

# Use VERSION file from source code (already exists in repo)
# If not exists, create with default
RUN if [ ! -f /app/VERSION ]; then echo "1.0.0" > /app/VERSION; fi && \
    if [ ! -f /app/COMMIT ]; then echo "unknown" > /app/COMMIT; fi

EXPOSE 3002

CMD ["python", "app.py"]
