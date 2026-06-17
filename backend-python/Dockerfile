FROM python:3.11-alpine

WORKDIR /app

# Copy requirements
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# Copy application files
COPY . .

# Create version file
RUN echo "1.0.0" > /app/VERSION

EXPOSE 8081

CMD ["python", "app.py"]
