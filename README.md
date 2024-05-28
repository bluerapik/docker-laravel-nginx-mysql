## Docker for Laravel + Nginx + MySQL

Run **Laravel** project in **docker (v26.1.3)** with **mysql:latest (v8.4)** and **nginx:alpine (v1.25.5)**. You can use the script **laravel.sh** to build and run docker automatically or follow the **steps manually**.

## 1. Script laravel.sh.

    $ ./laravel.sh

    Usage: ./laravel.sh [OPTION]
        -h:  Print this help
        -n:  Project name. New or existing

    Example: ./laravel.sh -h
             ./laravel.sh -n example

### The script does the following

- #### 1. Run Docker Composer image.

  - Create new project.
  - Update dependencies for existing project.

- #### 2. Configure enviroment for MySQL.

  - Add enviroment variables for MySQL in the new project.
  - If the project exists, examine the **.env** file for **DB_CONNECTION=mysql**. If it exists then modify **DB_HOST** and **DB_PORT**. Otherwise, add the contents of the .env file.

- #### 3. Copy Docker files.

  - **docker/mysql**: Contains the **init script** to create database and user, and the **database** folder for persistence of MySQL data
  - **nginx**: Contains the basic configuration of the application for Nginx.
  - **Dockerfile**: Dockerfile file for creating the docker image of the Laravel application.

- #### 3. Run docker-compose.yml.

  - Download **mysql:latest** Docker image and name container as **laravel-mysql**
  - Download **nginx:alpine** Docker image and name container as **nginx-mysql**
  - Build Laravel app Docker image and name container **laravel-app**

- #### 4. Artisan CLI.

  - If the project is new, run **php artisan migrate**
  - If the project exists, run **php artisan:key** and **php artisan migrate**

- #### 5. Print the auto generated MySQL root password.
- #### 6. Clean Docker build files.

### Application in browser

- #### localhost:8000

## 2. Manual steps.

Assume the project name as **example**.

- #### 1. Create new project with Docker Composer.

        $ docker run --rm --interactive --tty --volume "$PWD:/app" --user $(id -u):$(id -g) composer create-project laravel/laravel example

  - #### For existing project, go to step 2.

- #### 2. Modify .env file.

        $ cat .env >> example/.env

  - Or copy the following to the example/.env file. Feel free to change **DB_DATABASE**, **DB_USERNAME** and **DB_PASSWORD**.

        DB_CONNECTION=mysql
        DB_HOST=laravel-mysql
        DB_PORT=3306
        DB_DATABASE=laravel
        DB_USERNAME=lavarel
        DB_PASSWORD=lavarel

- #### 3. Copy the docker folder inside the project.

        $ cp -r docker-compose.yml docker example/

  - Feel free to change **docker/mysql/init.sql** content.
  - Feel free to change **php:8.2-fpm** in **Dockerfile** to another version of PHP Docker for an existing project..

- #### 4. Run docker-compose.yml.

        $ docker compose -f example/docker-compose.yml up -d

- #### 5. Run PHP Composer for existing project.

        $ docker compose -f example/docker-compose.yml exec app rm -rf vendor composer.lock
        $ docker compose -f example/docker-compose.yml exec app composer install

- #### 6. Run artisan CLI for migrate.

        $ docker compose -f example/docker-compose.yml exec app php artisan migrate

- #### 7. Run artisan CLI to generate a new project key if needed.

        $ docker compose -f example/docker-compose.yml exec app php artisan key:generate

- #### 8. Print auto generated MySQL root password.

        $ docker logs laravel-mysql 2>&1 | grep 'GENERATED ROOT PASSWORD'

- #### 9. Clean Docker build files.

        $ docker buildx prune -f

- #### 10. Application in browser.

  - #### localhost:8000
