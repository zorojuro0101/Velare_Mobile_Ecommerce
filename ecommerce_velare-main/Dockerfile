# Use Python 3.11 slim image
FROM python:3.11-slim

# Set working directory
WORKDIR /app

# Set environment variables
ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1

# Install system dependencies
RUN apt-get update && apt-get install -y \
    gcc \
    && rm -rf /var/lib/apt/lists/*

# Copy requirements and install dependencies
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# Copy entire application
COPY . .

# Create upload directories. We must create EVERY folder the app writes to,
# including the ones that get auto-created at runtime (buyer_ids, reports,
# seller_ids, seller_permits) — otherwise the docker-compose volume mount
# overlays an empty host folder over the container path and the app's
# `file.save()` calls fail with FileNotFoundError.
RUN mkdir -p static/uploads/products \
             static/uploads/shop_logos \
             static/uploads/ids \
             static/uploads/profiles \
             static/uploads/rider_orcr \
             static/uploads/rider_dl \
             static/uploads/banners \
             static/uploads/buyer_ids \
             static/uploads/seller_ids \
             static/uploads/seller_permits \
             static/uploads/reports

# Copy and set permissions for entrypoint
COPY entrypoint.sh .
RUN chmod +x entrypoint.sh

# Expose port (Railway will override this)
EXPOSE 5000

# Use entrypoint script
CMD ["./entrypoint.sh"]
