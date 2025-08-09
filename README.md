### Simple shell script to deploy a ReactJS build and a Java WAR file

#### How to test the script locally

#### 1) Create fake zip files

```bash
# Create a directory for our fake app sources
mkdir -p fake-apps/build

# Create fake content for the apps
echo "Hello from Project One" > fake-apps/build/index.html

# Create the zip file (the script expects a 'build' directory inside)
cd fake-apps && zip -r ../app-one.zip build
cd ..

# Repeat the same steps for project 2 and 3 as needed

# Create a fake WAR file
touch my-webapp.war

# Move all artifacts into the fake-apps directory for organization
mv app-*.zip my-webapp.war fake-apps/
```

#### 2) Build the image

```bash
docker build -t deploy-test-env .
```

#### 3) Run the container

```bash
docker run -it --rm --name my-test-container deploy-test-env
```

#### 4) Copy artifacts into the container’s temp directory

```bash
cp fake-apps/* /tmp/
```

#### 5) Run the script

```bash
./deploy.sh
```

#### 6) Verify the results

```bash
# Check the deployed content
ls -l /var/www/code/project-one
# You should see 'index.html'

# Check for the backup file
ls -l /var/www/code/
# You should see a file like 'project-one_YYYYMMDD_HHMMSS.zip'
```

#### 7) Check WAR file deployment

```bash
ls -l /opt/tomcat/latest/webapps
# You should see 'my-webapp.war'
```

#### 8) (Optional) Run `deploy.sh` from anywhere via a symlink

```bash
sudo ln -s /home/ubuntu/deploy.sh /usr/local/bin/deploy
```

> Note: This creates a symbolic link (shortcut) to the actual script instead of copying it. Future changes to the source script are picked up automatically.
