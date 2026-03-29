#!/usr/bin/env bash

# Command: eve remove-cli
BIN_PATH="/usr/local/bin/eve"

echo -e "${RED}• Removing Eve CLI from the system (requires sudo)...${NC}"

if [ -L "$BIN_PATH" ]; then
    sudo rm "$BIN_PATH"
    echo -e "${GREEN}✓ Eve CLI has been successfully removed from $BIN_PATH.${NC}"
    echo -e "${BLUE}The repository at $BASE_DIR remains intact.${NC}"
else
    echo -e "${YELLOW}Eve CLI (/usr/local/bin/eve) not found.${NC}"
fi
