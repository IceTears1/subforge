FROM python:3.11-alpine

WORKDIR /app

# Copy requirements
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# Copy application files
COPY . .

# Build arguments for version info
ARG VERSION=1.0.0
ARG COMMIT=unknown

# Create version and commit files
RUN echo "${VERSION}" > /app/VERSION && \
    echo "${COMMIT}" > /app/COMMIT

EXPOSE 3002

CMD ["python", "app.py"]
