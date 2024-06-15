PROJECT_NAME := $(notdir $(CURDIR))
BINARY_NAME := $(PROJECT_NAME)

PROJECT_ROOT := $(CURDIR)
BACKEND_SOURCE_DIR := $(PROJECT_ROOT)/app
FRONTEND_SOURCE_DIR := $(PROJECT_ROOT)/web/tukan-navigator

BUILD_DIR := $(PROJECT_ROOT)/build
CURRENT_BUILD_DIR := $(BUILD_DIR)/$(BINARY_NAME)
DIST_DIR := $(CURRENT_BUILD_DIR)/dist

.PHONY: all
all: build build-web-install

.PHONY: build
build: | $(CURRENT_BUILD_DIR)
	@echo "Building backend..."
	@go build -o $(CURRENT_BUILD_DIR)/$(BINARY_NAME) $(BACKEND_SOURCE_DIR)

.PHONY: build-web
build-web: | $(CURRENT_BUILD_DIR)
	@echo "Building frontend..."
	@cd $(FRONTEND_SOURCE_DIR) && npm run build
	@mkdir -p $(DIST_DIR)
	@cp -r $(FRONTEND_SOURCE_DIR)/dist/* $(DIST_DIR)

.PHONY: build-web-install
build-web-install: | $(CURRENT_BUILD_DIR)
	@echo "Building frontend and installing dependencies..."
	@cd $(FRONTEND_SOURCE_DIR) && npm install && npm run build
	@mkdir -p $(DIST_DIR)
	@cp -r $(FRONTEND_SOURCE_DIR)/dist/* $(DIST_DIR)

$(CURRENT_BUILD_DIR):
	@mkdir -p $(CURRENT_BUILD_DIR)

.PHONY: clean
clean:
	@echo "Cleaning up..."
	@rm -rf $(BUILD_DIR)

.PHONY: help
help:
	@echo "Usage:"
	@echo "  make                      Build the Go backend and Vue.js frontend and install NPM dependencies"
	@echo "  make build                Build the Go backend"
	@echo "  make build-web            Build the Vue.js frontend without installing NPM dependencies"
	@echo "  make build-web-install    Build the Vue.js frontend and install NPM dependencies"
	@echo "  make clean                Clean up build files"
	@echo "  make help                 Show this help message"

.PHONY: build build-web build-web-install clean help
