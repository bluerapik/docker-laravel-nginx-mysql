#!/bin/bash

# Colors
BLUE='\033[1;34m'
GREEN='\033[1;32m'
RED='\033[1;31m'
YELLOW='\033[1;33m'
NC='\033[0m'

docker info > /dev/null 2>&1

# Ensure that Docker is running.
if [ $? -ne 0 ]; then
		printf "\n%b%s%b\n\n" "$RED" "Docker is not running." "$NC"
    exit 1
fi

# Script Usage
usage() { 
	printf "Usage: $0 [OPTION]\n"
	printf "     -h:  Print this help\n"
	printf "     -n:  Project name. New or existing\n"
	printf "Example: ./laravel.sh -h\n"
	printf "\t ./laravel.sh -n example\n"
	exit 1; 
}

# Default project name
name="laravel"

while getopts "n:h" OPT; do
  case "${OPT}" in
    n)
      name=${OPTARG}
      ;;
    h)
      usage
      ;;			
  esac
done
shift $((OPTIND-1))

if [ -z "${name}" ]; then
    usage
fi

# Setting .env
env_config() {
	printf "\n%b%s%b\n" "$YELLOW" "Check if .env exists in the Project." "$NC"
	if [ -f "$name/.env" ] && [ $(grep -E '([[:blank:]]*\<DB_CONNECTION\>[[:blank:]]*=[[:blank:]]*\<mysql\>).*' "$name/.env") ]; then
		sed -i -E "s/^([[:blank:]]*DB_HOST[[:blank:]]*=[[:blank:]]*).*/\1laravel-mysql/" "$name/.env"
	else
		printf $YELLOW'\n%s\n'$NC "Copy .env file to project."
		cat .env >> "$name/".env
	fi
	
	sed -i -E "s/^([[:blank:]]*DB_PORT[[:blank:]]*=[[:blank:]]*).*/\13306/" "$name/.env"
	sed -i -E "s/^([[:blank:]]*DB_DATABASE[[:blank:]]*=[[:blank:]]*).*/\1$name/" "$name/.env"
	sed -i -E "s/^([[:blank:]]*DB_USERNAME[[:blank:]]*=[[:blank:]]*).*/\1$name/" "$name/.env"
	sed -i -E "s/^([[:blank:]]*DB_PASSWORD[[:blank:]]*=[[:blank:]]*).*/\1$name/" "$name/.env"
}

# Setting Docker files
docker_config() {
	printf "\n%b%s%b\n" "$YELLOW" "Copy docker files to project." "$NC"
	cp -r docker-compose.yml docker "$name/"
	
	
	printf "\n%b%s%b\n" "$YELLOW" "Modify default init.sql." "$NC"	
	sed -i -E "s/laravel/$name/g" "$name/docker/mysql/init.sql"

	printf "\n%b%s%b\n" "$YELLOW" "PHP image version in Dockerfile." "$NC"	
	if [ -f "$name/composer.json" ] ; then
		value=$(sed -nr '/\"php\"/{s/.*"php": "([^"]+)".*/\1/;p;}' "$name/composer.json")
		version=${value: -3:3}

		# Manually set the PHP version different from composer.json for the docker image.
		# version="7.4"
		
		printf "\n%b%s%b%s%b\n" "$YELLOW" "PHP Version in composer.json is: " "$RED" "$version" "$NC" 
		sed -i -E "s/^([[:blank:]]*FROM php\:).*/\1$version-fpm/" "$name/docker/Dockerfile"
	fi
}

# Execute docker-compose.yml.
docker_compose() {
	printf "\n%b%s%b\n" "$YELLOW" "Run docker compose." "$NC"	
	docker compose -f "$name/docker-compose.yml" up -d
}

# Check MySQL container status
mysql_status() {
	if [ "$(docker ps -aq -f status=running -f name=laravel-mysql)" ]; then
		if (! [ "$(docker exec laravel-mysql mysql --user="$name" --password="$name" -e "status")" ]) &> /dev/null; then
			printf "%b%s%b\n" "$BLUE" "Waiting for database connection." "$NC"
			return 1
		else 
			printf "%b%s%b\n" "$GREEN" "MySQL is Up and Ready!." "$NC"
			return 0
		fi
	else 
		printf "%b%s%b\n" "$RED" "MySQL container is Down! Exit." "$NC"
		exit 1
	fi		

}

# PHP Composer
composer_install() {
	printf "\n%b%s%b\n" "$YELLOW" "Delete vendor folder and composer.lock file for fresh dependency." "$NC"	
	docker compose -f "$name/docker-compose.yml" exec app rm -rf vendor composer.lock
	
	printf "\n%b%s%b\n\n" "$YELLOW" "Run composer install." "$NC"	
  docker compose -f "$name/docker-compose.yml" exec app composer install
}

# Migrate Database
artisan_migrate() {
	until mysql_status; do
		sleep 2
	done

	printf "\n%b%s%b\n" "$YELLOW" "Run aristan migrate." "$NC"
	docker compose -f "$name/docker-compose.yml" exec app php artisan migrate
}

# Generate Key
artisan_key() {
	printf "\n%b%s%b\n" "$YELLOW" "Run aristan key:generate." "$NC"	  
  docker compose -f "$name/docker-compose.yml" exec app php artisan key:generate
}

# Setting all for new project
new_project() { 
	printf "\n%b%s%b%s%b\n\n" "$YELLOW" "Create new Laravel project with the name: " "$RED" "$name" "$NC"	
	docker run --rm --interactive --tty --volume "$PWD:/app" --user $(id -u):$(id -g) composer create-project laravel/laravel "$name"
	env_config
	docker_config
	docker_compose
	artisan_migrate
}

# Setting all for existing project
update_project() {
	printf "\n%b%s%b%s%b%s%b\n" "$YELLOW" "Directory " "$RED" "$name" "$YELLOW" " exist. Updating." "$NC"	
	env_config
	docker_config
	docker_compose
	composer_install
	artisan_key
	artisan_migrate
}

if [ ! -d "$name" ]; then
	new_project	
else
	update_project
fi

# Print auto generated MySQL root password
printf "\n%b%s%b\n" "$YELLOW" "Auto Generated MySQL Root password." "$NC"
printf "%s\n" "------------------------------------------------"
password=$(docker logs laravel-mysql 2>/dev/null | sed -n -e 's/^.*PASSWORD: //p')

printf "%bROOT PASSWORD: %b %s %b \n" "$YELLOW" "$RED" "$password" "$NC"
printf "%s\n" "------------------------------------------------"

# Clean Docker build files
printf "\n%b%s%b\n" "$YELLOW" "Clean all Docker build files." "$NC"
docker buildx prune -f

