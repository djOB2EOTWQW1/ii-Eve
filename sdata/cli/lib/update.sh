#!/usr/bin/env bash

# Command: eve update
echo -e "${BLUE}Updating Eve...${NC}"

export VERBOSE="${VERBOSE:-false}"

SETUP_FLAGS="--no-confirm --no-backup"
[[ "$VERBOSE" == "true" ]] && SETUP_FLAGS="$SETUP_FLAGS -v"

if [ -d "$BASE_DIR" ]; then
    cd "$BASE_DIR"
    if [[ "$VERBOSE" == "true" ]]; then
        git pull
    else
        git pull > /dev/null 2>&1
    fi
    
    echo -e "${GREEN}Eve repo updated successfully!${NC}"
    
    bash setup-ii-eve.sh $SETUP_FLAGS
else
    echo -e "${RED}Error: Cannot find install path.${NC}"
    exit 1
fi
