# Use an official Python runtime as a parent image
FROM python:3.9-slim

# Set the working directory in the container
WORKDIR /app

# Copy the current directory contents into the container at /app
COPY . .

# Install any necessary dependencies
RUN pip install --no-cache-dir -r requirements.txt

#Copy
COPY . .

# Run generate_report.py when the container launches
CMD ["python", "/app/generate_report.py"]
