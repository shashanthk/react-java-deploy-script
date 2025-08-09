# Use a standard Ubuntu LTS image as the base
FROM ubuntu:22.04

# Avoid interactive prompts during package installation
ARG DEBIAN_FRONTEND=noninteractive

# Install dependencies required by the script and for general use
RUN apt update && apt install -y \
    zip \
    unzip \
    sudo \
    vim \
    && rm -rf /var/lib/apt/lists/*

# Create the 'ubuntu' user and the directory structure the script expects
RUN useradd -ms /bin/bash ubuntu && \
    useradd -r -s /sbin/nologin tomcat && \
    mkdir -p /var/www/code/project-one && \
    mkdir -p /var/www/code/project-two && \
    mkdir -p /var/www/code/project-three && \
    mkdir -p /opt/tomcat/latest/webapps

# Set the correct ownership for the directories
RUN chown -R ubuntu:ubuntu /home/ubuntu && chown -R tomcat:tomcat /opt/tomcat

# Copy the script and the fake application files into the container
COPY deploy.sh /home/ubuntu/deploy.sh
COPY fake-apps /home/ubuntu/fake-apps/

# Make the deployment script executable
RUN chmod +x /home/ubuntu/deploy.sh

# Switch to the non-root 'ubuntu' user to run the script
WORKDIR /home/ubuntu

# Start a bash shell when the container runs
CMD ["/bin/bash"]