FROM python:3.11-alpine

WORKDIR /app

# Copy requirements
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# Copy application files
COPY . .

# Version will be provided via build argument or copied from source
ARG VERSION=unknown
ARG COMMIT=unknown

# Create VERSION and COMMIT files
RUN echo "${VERSION}" > /app/VERSION && \
    echo "${COMMIT}" > /app/COMMIT

EXPOSE 3002

CMD ["python", "app.py"]
